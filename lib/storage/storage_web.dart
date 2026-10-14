import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'storage_base.dart';

DataStorage createStorage() => _LocalStorage();

/// Stores data in the browser's localStorage.
class _LocalStorage extends DataStorage {
  static const _key = 'conclock.data';

  @override
  String get location => 'Browser local storage';

  @override
  Future<String?> read() async => web.window.localStorage.getItem(_key);

  @override
  Future<void> write(String data) async =>
      web.window.localStorage.setItem(_key, data);

  @override
  void watch(void Function(String data) onChange) {
    // Fires in every other tab of this origin when one tab writes.
    web.window.addEventListener(
      'storage',
      (web.StorageEvent e) {
        final v = e.newValue;
        if (e.key == _key && v != null) onChange(v);
      }.toJS,
    );
  }

  @override
  Future<void> backupCorrupt() async {
    final v = web.window.localStorage.getItem(_key);
    if (v != null) web.window.localStorage.setItem('$_key.corrupt', v);
  }
}
