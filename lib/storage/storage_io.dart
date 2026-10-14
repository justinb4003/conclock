import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'storage_base.dart';

DataStorage createStorage() => FileStorage();

const _dataName = 'conclock.json';

/// Stores data as `conclock.json` in the platform's app-support directory,
/// or in a folder the user picked (e.g. a synced one), recorded in
/// `location.json` there. Writes go to a temp file first and are renamed
/// into place, so a crash mid-write never leaves a half-written file.
class FileStorage extends DataStorage {
  /// [supportDir] overrides the app-support directory (tests).
  FileStorage({Directory? supportDir}) : _supportDir = supportDir;

  Directory? _supportDir;
  File? _file;
  String? _warning;

  /// What we last read or wrote, so watching ignores our own writes.
  String? _last;

  void Function(String data)? _onChange;
  StreamSubscription<FileSystemEvent>? _watching;

  Future<Directory> _support() async {
    final dir = _supportDir ??= await getApplicationSupportDirectory();
    await dir.create(recursive: true);
    return dir;
  }

  File _pointer(Directory support) =>
      File(_join(support.path, 'location.json'));

  static String _join(String dir, String name) =>
      '$dir${Platform.pathSeparator}$name';

  Future<File> _getFile() async {
    if (_file != null) return _file!;
    final support = await _support();
    String? chosen;
    try {
      final pointer = _pointer(support);
      if (await pointer.exists()) {
        chosen =
            (jsonDecode(await pointer.readAsString()) as Map)['dataDir']
                as String?;
      }
    } catch (_) {}
    if (chosen != null && !await Directory(chosen).exists()) {
      _warning =
          'Your data folder ($chosen) wasn’t found, so ConClock is using '
          'its default location. Pick the folder again under Clients → '
          'Data location once it’s back.';
      chosen = null;
    }
    return _file = File(_join(chosen ?? support.path, _dataName));
  }

  @override
  String get location => _file?.path ?? '';

  @override
  String? get warning => _warning;

  @override
  bool get canRelocate =>
      Platform.isLinux || Platform.isWindows || Platform.isMacOS;

  @override
  String? get folder {
    final dir = _file?.parent.path;
    return dir == null || dir == _supportDir?.path ? null : dir;
  }

  @override
  Future<bool> hasDataAt(String dir) => File(_join(dir, _dataName)).exists();

  @override
  Future<void> relocate(String? dir) async {
    final support = await _support();
    final pointer = _pointer(support);
    if (dir == null) {
      if (await pointer.exists()) await pointer.delete();
    } else {
      await pointer.writeAsString(jsonEncode({'dataDir': dir}), flush: true);
    }
    _file = File(_join(dir ?? support.path, _dataName));
    _warning = null;
    _last = null;
    _rewatch();
  }

  @override
  Future<String?> read() async {
    final f = await _getFile();
    if (!await f.exists()) return null;
    return _last = await f.readAsString();
  }

  @override
  Future<void> write(String data) async {
    final f = await _getFile();
    _last = data;
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(data, flush: true);
    await tmp.rename(f.path);
  }

  /// Another copy of the app (or a sync tool) saved the file: hand over its
  /// contents.
  @override
  void watch(void Function(String data) onChange) {
    _onChange = onChange;
    _rewatch();
  }

  void _rewatch() {
    _watching?.cancel();
    final f = _file;
    final onChange = _onChange;
    if (f == null || onChange == null || !FileSystemEntity.isWatchSupported) {
      return;
    }
    Timer? settle;
    _watching = f.parent.watch().listen((event) {
      final hit =
          event.path == f.path ||
          (event is FileSystemMoveEvent && event.destination == f.path);
      if (!hit) return;
      // Let the writer finish (temp file + rename) before reading.
      settle?.cancel();
      settle = Timer(const Duration(milliseconds: 200), () async {
        try {
          final data = await f.readAsString();
          if (data == _last) return;
          _last = data;
          onChange(data);
        } catch (_) {
          // Mid-replace; the next event will pick it up.
        }
      });
    }, onError: (_) {});
  }

  @override
  Future<void> keepCopy(String tag, String? data) async {
    final f = await _getFile();
    final copy = File(
      '${f.path}.$tag-${DateTime.now().millisecondsSinceEpoch}',
    );
    if (data != null) {
      await copy.writeAsString(data, flush: true);
    } else if (await f.exists()) {
      await f.copy(copy.path);
    }
  }
}
