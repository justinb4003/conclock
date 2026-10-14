import 'package:conclock/main.dart';
import 'package:conclock/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'store_test.dart' show MemoryStorage;

void main() {
  testWidgets('track, switch, note, and visit every tab', (tester) async {
    var t = DateTime(2026, 10, 12, 9);
    final store = AppStore(storage: MemoryStorage(), clock: () => t);
    void later() => t = t.add(const Duration(minutes: 10));
    await tester.pumpWidget(ConClockApp(store: store));

    await tester.tap(find.text('Add a client'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Acme');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    store.addClient('Globex');
    await tester.pump();

    await tester.tap(find.text('Acme'));
    await tester.pump();
    expect(store.running?.clientId, store.clients.first.id);

    await tester.enterText(find.widgetWithText(TextField, ''), 'Kickoff');
    expect(store.running?.note, 'Kickoff');
    // Not listed as a task while still typing…
    expect(find.text('Kickoff'), findsOneWidget); // just the field
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    // …but committed with Enter it appears under the client, running.
    expect(find.text('Kickoff'), findsNWidgets(2));
    expect(store.running?.note, 'Kickoff');
    later();

    await tester.tap(find.text('Globex'));
    await tester.pump();
    expect(store.running?.clientId, store.clients.last.id);
    expect(store.running?.note, '');
    later();

    // Stopping an unnamed entry asks for a name; backing out keeps it running.
    await tester.tap(find.byTooltip('Stop'));
    await tester.pumpAndSettle();
    expect(find.text('Name this task'), findsOneWidget);
    await tester.tapAt(const Offset(5, 5)); // dismiss
    await tester.pumpAndSettle();
    expect(store.running?.clientId, store.clients.last.id);

    // Switching clients also asks; pick a name, then the switch happens.
    await tester.tap(find.text('Acme').first);
    await tester.pumpAndSettle();
    expect(find.text('Name this task'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'Planning');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(store.entries[1].note, 'Planning');
    expect(store.running?.clientId, store.clients.first.id);
    later();

    // Discarding while switching drops the entry and still switches.
    await tester.tap(find.text('Globex').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(store.running?.clientId, store.clients.last.id);
    expect(store.entries.length, 3);

    for (final tab in ['Log', 'Timesheet', 'Clients', 'Track']) {
      await tester.tap(find.text(tab).last);
      await tester.pump(const Duration(seconds: 2));
    }

    await tester.tap(find.text('Log').last);
    await tester.pump();
    await tester.tap(find.text('Decimal'));
    await tester.pump();
    expect(store.decimalHours, isTrue);

    // Day → client → task → entry: expand the task, open its entry.
    expect(find.text('Kickoff'), findsOneWidget);
    await tester.tap(find.text('Kickoff'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.edit_outlined).first);
    await tester.pumpAndSettle();
    expect(find.text('Edit time'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Acme').last); // collapse client
    await tester.pump();
    expect(find.text('Kickoff'), findsNothing);
    await tester.tap(find.byTooltip('Add time'));
    await tester.pumpAndSettle();
    expect(find.text('Add time'), findsWidgets);
    // The default last hour overlaps what was tracked above.
    expect(find.textContaining('Overlaps'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Timesheet').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Previous week'));
    await tester.pump();

    store.stop();
    await tester.pump();
    await store.flush();
  });
}
