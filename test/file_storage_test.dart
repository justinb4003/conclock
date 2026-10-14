import 'dart:io';

import 'package:conclock/storage/storage_base.dart';
import 'package:conclock/storage/storage_io.dart';
import 'package:conclock/store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('conclock'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('a second app instance adopts the other one\'s saves', () async {
    final a = AppStore(storage: FileStorage(supportDir: dir));
    final b = AppStore(storage: FileStorage(supportDir: dir));
    await a.load();
    await b.load();

    a.addClient('Saved by A');
    await a.flush();
    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(b.clients.single.name, 'Saved by A');

    // A doesn't re-adopt its own write (same objects kept).
    final client = a.clients.single;
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(identical(a.clients.single, client), isTrue);
    a.dispose();
    b.dispose();
  });

  group('data folder', () {
    late Directory synced;
    setUp(() => synced = Directory('${dir.path}/synced')..createSync());

    test('move here, then reopen from there', () async {
      final store = AppStore(storage: FileStorage(supportDir: dir));
      await store.load();
      store.addClient('Acme');
      await store.moveDataTo(synced.path, useExisting: false);
      expect(File('${synced.path}/conclock.json').existsSync(), isTrue);
      expect(store.dataInDefaultFolder, isFalse);

      final reopened = AppStore(storage: FileStorage(supportDir: dir));
      await reopened.load();
      expect(reopened.storageLocation, startsWith(synced.path));
      expect(reopened.clients.single.name, 'Acme');
      store.dispose();
      reopened.dispose();
    });

    test('use the data already there; ours is kept as a copy', () async {
      final other = AppStore(
        storage: FileStorage(supportDir: Directory('${dir.path}/other')),
      );
      await other.load();
      other.addClient('From laptop');
      await other.moveDataTo(synced.path, useExisting: false);

      final store = AppStore(storage: FileStorage(supportDir: dir));
      await store.load();
      store.addClient('From desktop');
      await store.flush();
      expect(await store.hasDataIn(synced.path), isTrue);
      await store.moveDataTo(synced.path, useExisting: true);
      expect(store.clients.single.name, 'From laptop');
      expect(
        dir.listSync().any((f) => f.path.contains('before-switch')),
        isTrue,
      );
      other.dispose();
      store.dispose();
    });

    test('unreadable data there: stays put', () async {
      File('${synced.path}/conclock.json').writeAsStringSync('{broken');
      final store = AppStore(storage: FileStorage(supportDir: dir));
      await store.load();
      store.addClient('Keep');
      await expectLater(
        store.moveDataTo(synced.path, useExisting: true),
        throwsA(anything),
      );
      expect(store.dataInDefaultFolder, isTrue);
      expect(store.clients.single.name, 'Keep');
      store.dispose();
    });

    test('a missing chosen folder falls back with a warning', () async {
      final store = AppStore(storage: FileStorage(supportDir: dir));
      await store.load();
      await store.moveDataTo(synced.path, useExisting: false);
      store.dispose();
      synced.deleteSync(recursive: true);

      final reopened = AppStore(storage: FileStorage(supportDir: dir));
      await reopened.load();
      expect(reopened.dataInDefaultFolder, isTrue);
      expect(reopened.loadError, contains('wasn’t found'));
      reopened.dispose();
    });
  });

  test('keeps only the newest few side copies per kind', () async {
    final storage = FileStorage(supportDir: dir);
    await storage.write('{}');
    for (var i = 0; i < 5; i++) {
      await storage.keepCopy('pre-import', 'copy $i');
      await Future<void>.delayed(const Duration(milliseconds: 3));
    }
    await storage.keepCopy('corrupt', 'other kind');
    final copies = dir.listSync().whereType<File>().map((f) => f.path);
    final imports = copies.where((p) => p.contains('.pre-import-')).toList();
    expect(imports, hasLength(keepCopies));
    final kept = {for (final p in imports) File(p).readAsStringSync()};
    expect(kept, {'copy 2', 'copy 3', 'copy 4'});
    expect(copies.where((p) => p.contains('.corrupt-')), hasLength(1));
  });
}
