import 'package:conclock/models.dart';
import 'package:conclock/screens/tracker_screen.dart';
import 'package:conclock/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'store_test.dart' show MemoryStorage;

void main() {
  late AppStore store;
  late Client acme;
  final day = DateTime.now().subtract(const Duration(days: 1));

  void add(String note, int hour, {Client? c}) => store.addEntry(
    Entry(
      id: newId(),
      clientId: (c ?? acme).id,
      start: DateTime(day.year, day.month, day.day, hour),
      end: DateTime(day.year, day.month, day.day, hour + 1),
      note: note,
    ),
  );

  setUp(() {
    store = AppStore(storage: MemoryStorage());
    acme = store.addClient('Acme');
  });

  test('rename, merge into an existing task, and undo', () {
    final globex = store.addClient('Globex');
    add('Sprint planing', 9);
    add('Sprint planing', 10);
    add('Sprint planning', 11);
    add('Sprint planing', 12, c: globex); // other client: untouched

    final (:count, :undo) = store.renameTask(
      acme.id,
      'Sprint planing',
      'Sprint planning',
    );
    expect(count, 2);
    expect(store.hasTask(acme.id, 'Sprint planing'), isFalse);
    expect(store.hasTask(globex.id, 'Sprint planing'), isTrue);
    expect(store.recentTasks(DateTime.now())[acme.id], ['Sprint planning']);

    undo();
    expect(store.entries.where((e) => e.note == 'Sprint planing').length, 3);
  });

  test('naming unnamed entries can be limited to some entries', () {
    add('', 9);
    add('', 10);
    final first = store.entries.last;
    store.renameTask(acme.id, '', 'Email', only: [first]);
    expect(store.entries.map((e) => e.note).toList()..sort(), ['', 'Email']);
  });

  testWidgets('long-press a task on Track to rename it', (tester) async {
    add('Sprint planing', 9);
    await tester.pumpWidget(
      StoreScope(
        store: store,
        child: const MaterialApp(home: TrackerScreen()),
      ),
    );
    await tester.longPress(find.text('Sprint planing'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename task…'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Sprint planning');
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();

    expect(find.text('Sprint planning'), findsOneWidget);
    expect(find.text('Renamed 1 entry'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5)); // let the snackbar go
  });
}
