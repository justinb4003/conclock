import 'package:conclock/main.dart';
import 'package:conclock/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'store_test.dart' show MemoryStorage;

void main() {
  testWidgets('tasks under a client collapse, and that is saved', (
    tester,
  ) async {
    var t = DateTime(2026, 10, 12, 9);
    final storage = MemoryStorage();
    final store = AppStore(storage: storage, clock: () => t);
    final acme = store.addClient('Acme');
    final globex = store.addClient('Globex');
    for (final (c, task) in [
      (acme, 'Design'),
      (acme, 'Review'),
      (globex, 'Migration'),
    ]) {
      store.toggle(c.id, note: task);
      t = t.add(const Duration(minutes: 30));
    }
    store.stop();
    await tester.pumpWidget(ConClockApp(store: store));
    await tester.pump();
    expect(find.text('Design'), findsOneWidget);

    // One client.
    await tester.tap(find.byTooltip('Hide tasks').first);
    await tester.pump();
    expect(find.text('Design'), findsNothing);
    expect(find.text('Review'), findsNothing);
    expect(find.text('Migration'), findsOneWidget);
    expect(store.collapsedClients, {acme.id});

    // A running task stays visible while collapsed.
    store.toggle(acme.id, note: 'Review');
    await tester.pump();
    expect(find.widgetWithText(ListTile, 'Review'), findsOneWidget);
    expect(find.text('Design'), findsNothing);
    store.stop();
    await tester.pump();

    // All of them, from the app bar.
    await tester.tap(find.byTooltip('Hide all tasks'));
    await tester.pump();
    expect(find.text('Migration'), findsNothing);
    await tester.tap(find.byTooltip('Show all tasks'));
    await tester.pump();
    expect(find.text('Design'), findsOneWidget);
    expect(find.text('Migration'), findsOneWidget);

    await tester.pumpAndSettle(); // rows slide into place
    await tester.tap(find.byTooltip('Hide tasks').last);
    await store.flush();
    final reloaded = AppStore(storage: storage);
    await reloaded.load();
    expect(reloaded.collapsedClients, {globex.id});
    await tester.pump(const Duration(seconds: 1));
  });
}
