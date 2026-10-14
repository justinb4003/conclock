import 'package:conclock/main.dart';
import 'package:conclock/store.dart';
import 'package:flutter_test/flutter_test.dart';

import 'store_test.dart' show MemoryStorage;

void main() {
  late DateTime t;
  late AppStore store;

  setUp(() {
    t = DateTime(2026, 10, 12, 8);
    store = AppStore(storage: MemoryStorage(), clock: () => t);
  });

  testWidgets('asks after 9 hours; "Stop now" stops it', (tester) async {
    final acme = store.addClient('Acme');
    store.toggle(acme.id, note: 'Design');
    t = t.add(const Duration(hours: 9, minutes: 30));

    await tester.pumpWidget(ConClockApp(store: store));
    await tester.pumpAndSettle();
    expect(find.text('Still working on Acme?'), findsOneWidget);
    await tester.tap(find.text('Stop now'));
    await tester.pumpAndSettle();
    expect(store.running, isNull);
    expect(store.entries.single.end, t);
  });

  testWidgets('"Keep running" snoozes the question', (tester) async {
    final acme = store.addClient('Acme');
    store.toggle(acme.id, note: 'Design');
    t = t.add(const Duration(hours: 10));
    await tester.pumpWidget(ConClockApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep running'));
    await tester.pumpAndSettle();

    t = t.add(const Duration(minutes: 1));
    await tester.pump(const Duration(seconds: 30));
    expect(find.text('Still working on Acme?'), findsNothing);
    expect(store.running, isNotNull);
    store.stop();
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('after a sleep, removing the gap splits the entry', (
    tester,
  ) async {
    final acme = store.addClient('Acme');
    store.toggle(acme.id, note: 'Design');
    await tester.pumpWidget(ConClockApp(store: store));
    await tester.pump();

    for (var i = 0; i < 4; i++) {
      // Awake: the clock moves with the ticks.
      t = t.add(const Duration(seconds: 30));
      await tester.pump(const Duration(seconds: 30));
    }
    final asleepAt = t;
    t = t.add(const Duration(minutes: 40)); // lid closed
    await tester.pump(const Duration(seconds: 30));
    await tester.pumpAndSettle();

    expect(find.textContaining('asleep'), findsOneWidget);
    await tester.tap(find.text('Remove 0:40, keep going'));
    await tester.pumpAndSettle();

    expect(store.entries.length, 2);
    expect(store.entries.last.end, asleepAt);
    expect(store.running!.start, t);
    expect(store.running!.note, 'Design');
    store.stop();
    await tester.pump(const Duration(seconds: 1));
  });
}
