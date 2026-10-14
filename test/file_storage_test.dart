import 'dart:io';

import 'package:conclock/storage/storage_io.dart';
import 'package:conclock/store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('conclock'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('a second app instance adopts the other one\'s saves', () async {
    final file = File('${dir.path}/conclock.json');
    final a = AppStore(storage: FileStorage(file: file));
    final b = AppStore(storage: FileStorage(file: file));
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
}
