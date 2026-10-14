import 'package:web/web.dart' as web;

import 'storage_base.dart';

DataStorage createStorage() => _LocalStorage();

/// Stores data in the browser's localStorage.
class _LocalStorage implements DataStorage {
  static const _key = 'conclock.data';

  @override
  String get location => 'Browser local storage';

  @override
  Future<String?> read() async => web.window.localStorage.getItem(_key);

  @override
  Future<void> write(String data) async =>
      web.window.localStorage.setItem(_key, data);

  @override
  Future<void> backupCorrupt() async {
    final v = web.window.localStorage.getItem(_key);
    if (v != null) web.window.localStorage.setItem('$_key.corrupt', v);
  }
}
