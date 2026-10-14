@TestOn('browser')
library;

import 'dart:async';
import 'dart:js_interop';

import 'package:conclock/storage/storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;

void main() {
  test('moves localStorage data over, then holds far more than 5 MB', () async {
    web.window.localStorage.setItem('conclock.data', '{"legacy":true}');
    final s = createStorage();
    expect(await s.read(), '{"legacy":true}');
    expect(web.window.localStorage.getItem('conclock.data'), isNull);

    final big = 'x' * (20 * 1000 * 1000); // 20 MB
    await s.write(big);
    expect((await createStorage().read())!.length, big.length);

    await s.keepCopy('pre-import', null);
    await s.write('{"small":1}');
    expect(await createStorage().read(), '{"small":1}');
  });

  test('other tabs hear about saves', () async {
    final other = createStorage();
    final heard = <String>[];
    other.watch(heard.add);
    await createStorage().write('{"from":"tab 1"}');
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(heard, ['{"from":"tab 1"}']);
  });

  test('keeps only the newest few side copies', () async {
    final s = createStorage();
    await s.write('{"current":1}');
    for (var i = 0; i < 5; i++) {
      await s.keepCopy('unsaved', 'copy $i');
      await Future<void>.delayed(const Duration(milliseconds: 3));
    }
    final db = await _openDb();
    final keys = await _keys(db);
    expect(keys.where((k) => k.startsWith('data.unsaved-')), hasLength(3));
    expect(keys, contains('data'));
  });
}

Future<web.IDBDatabase> _openDb() {
  final c = Completer<web.IDBDatabase>();
  final req = web.window.indexedDB.open('conclock', 1);
  req.onsuccess = ((web.Event _) => c.complete(
    req.result as web.IDBDatabase,
  )).toJS;
  return c.future;
}

Future<List<String>> _keys(web.IDBDatabase db) {
  final c = Completer<List<String>>();
  final req = db
      .transaction('kv'.toJS, 'readonly')
      .objectStore('kv')
      .getAllKeys();
  req.onsuccess = ((web.Event _) => c.complete([
    for (final k in (req.result as JSArray<JSString>).toDart) k.toDart,
  ])).toJS;
  return c.future;
}
