import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'storage_base.dart';

DataStorage createStorage() => _IndexedDbStorage();

/// Stores data in the browser's IndexedDB, which (unlike localStorage's
/// ~5 MB) can hold years of entries. Data saved by older versions in
/// localStorage moves over on first load.
class _IndexedDbStorage extends DataStorage {
  static const _db = 'conclock';
  static const _store = 'kv';
  static const _key = 'data';
  static const _legacyKey = 'conclock.data'; // localStorage, before IndexedDB

  /// Tells other tabs of this origin about saves.
  final _channel = web.BroadcastChannel('conclock');

  Future<web.IDBDatabase>? _opening;

  @override
  String get location => 'Browser storage (IndexedDB)';

  Future<web.IDBDatabase> _open() => _opening ??= () {
    // Ask the browser not to clear it when space runs low.
    web.window.navigator.storage.persist().toDart.ignore();
    final req = web.window.indexedDB.open(_db, 1);
    req.onupgradeneeded = ((web.Event _) {
      (req.result as web.IDBDatabase).createObjectStore(_store);
    }).toJS;
    return _done(req).then((r) => r as web.IDBDatabase);
  }();

  static Future<JSAny?> _done(web.IDBRequest req) {
    final c = Completer<JSAny?>();
    req.onsuccess = ((web.Event _) => c.complete(req.result)).toJS;
    req.onerror = ((web.Event _) => c.completeError(_message(req.error))).toJS;
    return c.future;
  }

  static String _message(web.DOMException? e) =>
      e == null ? 'IndexedDB error' : '${e.name}: ${e.message}';

  Future<String?> _get(String key) async {
    final db = await _open();
    final store = db.transaction(_store.toJS, 'readonly').objectStore(_store);
    final v = await _done(store.get(key.toJS));
    return v.isA<JSString>() ? (v as JSString).toDart : null;
  }

  /// Resolves once the write is committed (or fails, e.g. quota exceeded).
  Future<void> _put(String key, String value) async {
    final db = await _open();
    final tx = db.transaction(_store.toJS, 'readwrite');
    final c = Completer<void>();
    tx.oncomplete = ((web.Event _) => c.complete()).toJS;
    tx.onerror = ((web.Event _) {
      if (!c.isCompleted) c.completeError(_message(tx.error));
    }).toJS;
    tx.onabort = ((web.Event _) {
      if (!c.isCompleted) c.completeError(_message(tx.error));
    }).toJS;
    tx.objectStore(_store).put(value.toJS, key.toJS);
    return c.future;
  }

  @override
  Future<String?> read() async {
    final data = await _get(_key);
    if (data != null) return data;
    final legacy = web.window.localStorage.getItem(_legacyKey);
    if (legacy != null) {
      await _put(_key, legacy);
      web.window.localStorage.removeItem(_legacyKey);
    }
    return legacy;
  }

  @override
  Future<void> write(String data) async {
    await _put(_key, data);
    _channel.postMessage(data.toJS);
  }

  @override
  void watch(void Function(String data) onChange) {
    _channel.onmessage = ((web.MessageEvent e) {
      final v = e.data;
      if (v.isA<JSString>()) onChange((v as JSString).toDart);
    }).toJS;
  }

  @override
  Future<void> keepCopy(String tag, String? data) async {
    final v = data ?? await _get(_key);
    if (v == null) return;
    // Timestamped like the desktop's files, so copies don't overwrite each
    // other; only the newest few are kept, since each is a full copy.
    await _put('$_key.$tag-${DateTime.now().millisecondsSinceEpoch}', v);
    await _prune('$_key.$tag-');
  }

  /// Deletes all but the newest [keepCopies] keys starting with [prefix].
  Future<void> _prune(String prefix) async {
    final db = await _open();
    final store = db.transaction(_store.toJS, 'readwrite').objectStore(_store);
    final keys = ((await _done(store.getAllKeys())) as JSArray<JSAny?>).toDart
        .map((k) => k.isA<JSString>() ? (k as JSString).toDart : '')
        .where((k) => k.startsWith(prefix))
        .toList();
    for (final k in oldCopies(keys)) {
      store.delete(k.toJS);
    }
  }
}
