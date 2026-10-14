import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'storage_base.dart';

DataStorage createStorage() => _FileStorage();

/// Stores data as `conclock.json` in the platform's app-support directory.
/// Writes go to a temp file first and are renamed into place, so a crash
/// mid-write never leaves a half-written file.
class _FileStorage implements DataStorage {
  File? _file;

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
    return f.readAsString();
  }

  @override
  Future<void> write(String data) async {
    final f = await _getFile();
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(data, flush: true);
    await tmp.rename(f.path);
  }

  @override
  Future<void> backupCorrupt() async {
    final f = await _getFile();
    if (await f.exists()) {
      await f.copy(
        '${f.path}.corrupt-${DateTime.now().millisecondsSinceEpoch}',
      );
    }
  }
}
