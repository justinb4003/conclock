import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'storage_base.dart';

DataStorage createStorage() => FileStorage();

/// Stores data as `conclock.json` in the platform's app-support directory
/// (or [file], for tests). Writes go to a temp file first and are renamed
/// into place, so a crash mid-write never leaves a half-written file.
class FileStorage extends DataStorage {
  FileStorage({File? file}) : _file = file;

  File? _file;

  /// What we last read or wrote, so watching ignores our own writes.
  String? _last;

  Future<File> _getFile() async {
    if (_file != null) return _file!;
    final dir = await getApplicationSupportDirectory();
    await dir.create(recursive: true);
    return _file = File('${dir.path}${Platform.pathSeparator}conclock.json');
  }

  @override
  String get location => _file?.path ?? '';

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

  /// Another copy of the app saved the same file: hand over its contents.
  @override
  void watch(void Function(String data) onChange) {
    final f = _file;
    if (f == null || !FileSystemEntity.isWatchSupported) return;
    Timer? settle;
    f.parent.watch().listen((event) {
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
