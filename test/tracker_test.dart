import 'package:conclock/models.dart';
import 'package:conclock/screens/tracker_screen.dart';
import 'package:conclock/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'store_test.dart' show MemoryStorage;

void main() {
  testWidgets('shows 3 recent tasks, "N more" expands the rest', (
    tester,
  ) async {
    final store = AppStore(storage: MemoryStorage());
    final acme = store.addClient('Acme');
    final day = DateTime.now().subtract(const Duration(days: 1));
    // Newest first: Task 1 is the most recent.
    for (var i = 1; i <= 5; i++) {
      store.addEntry(
        Entry(
          id: newId(),
          clientId: acme.id,
          start: DateTime(day.year, day.month, day.day, 17 - i),
          end: DateTime(day.year, day.month, day.day, 18 - i),
          note: 'Task $i',
        ),
      );
    }
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      StoreScope(
        store: store,
        child: const MaterialApp(home: TrackerScreen()),
      ),
    );

    expect(find.text('Task 3'), findsOneWidget);
    expect(find.text('Task 4'), findsNothing);
    expect(find.text('2 more'), findsOneWidget);

    // Resuming an older task keeps it visible while collapsed.
    store.toggle(acme.id, note: 'Task 5');
    await tester.pump();
    expect(find.text('Task 5'), findsWidgets);

    await tester.tap(find.text('2 more'));
    await tester.pump();
    expect(find.text('Task 4'), findsOneWidget);
    expect(find.text('Show less'), findsOneWidget);

    store.stop();
    await tester.pump(const Duration(seconds: 1));
  });
}
