import 'package:conclock/main.dart';
import 'package:conclock/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'store_test.dart' show MemoryStorage;

void main() {
  testWidgets('collapse all and per day down to client rows', (tester) async {
    var t = DateTime(2026, 10, 12, 9);
    final store = AppStore(storage: MemoryStorage(), clock: () => t);
    final acme = store.addClient('Acme');
    store.toggle(acme.id, note: 'Monday work');
    t = t.add(const Duration(hours: 1));
    store.stop();
    t = DateTime(2026, 10, 13, 9);
    store.toggle(acme.id, note: 'Tuesday work');
    t = t.add(const Duration(hours: 1));
    store.stop();
    await tester.pumpWidget(ConClockApp(store: store));
    await tester.pump();
    await tester.tap(find.text('Log').last);
    await tester.pumpAndSettle();

    expect(find.text('Monday work'), findsOneWidget);
    expect(find.text('Tuesday work'), findsOneWidget);

    // One day: the newest is listed first.
    await tester.tap(find.text('Tuesday, October 13, 2026'));
    await tester.pump();
    expect(find.text('Tuesday work'), findsNothing);
    expect(find.text('Monday work'), findsOneWidget);
    expect(find.byTooltip('Collapse all'), findsOneWidget); // Monday still open

    await tester.tap(find.byTooltip('Collapse all'));
    await tester.pump();
    expect(find.text('Monday work'), findsNothing);
    expect(find.text('Acme'), findsNWidgets(2)); // client rows stay

    await tester.tap(find.byTooltip('Expand all'));
    await tester.pump();
    expect(find.text('Monday work'), findsOneWidget);
    expect(find.text('Tuesday work'), findsOneWidget);
  });

  testWidgets('one week at a time, from the top or the bottom', (tester) async {
    var t = DateTime(2026, 10, 1, 9); // the week before last
    final store = AppStore(storage: MemoryStorage(), clock: () => t);
    final acme = store.addClient('Acme');
    store.toggle(acme.id, note: 'Old work');
    t = t.add(const Duration(hours: 1));
    store.stop();
    t = DateTime(2026, 10, 14, 9);
    store.toggle(acme.id, note: 'This week');
    t = t.add(const Duration(hours: 1));
    store.stop();
    await tester.pumpWidget(ConClockApp(store: store));
    await tester.pump();
    await tester.tap(find.text('Log').last);
    await tester.pumpAndSettle();

    expect(find.text('This week'), findsOneWidget); // the task, no button
    // Always the weekday and date, never "Today" or "Yesterday".
    expect(find.text('Wednesday, October 14, 2026'), findsOneWidget);
    expect(find.text('Old work'), findsNothing);

    await tester.tap(find.byTooltip('Previous week'));
    await tester.pumpAndSettle();
    expect(find.text('Nothing tracked this week'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Previous week'));
    await tester.pumpAndSettle();
    expect(find.text('Old work'), findsOneWidget);
    expect(find.text('Sep 28 – Oct 4, 2026'), findsOneWidget);

    // Back to the current week.
    await tester.tap(find.widgetWithText(TextButton, 'This week'));
    await tester.pumpAndSettle();
    expect(find.text('Old work'), findsNothing);
    expect(find.widgetWithText(TextButton, 'This week'), findsNothing);
  });

  testWidgets('group by client: client, then its days', (tester) async {
    var t = DateTime(2026, 10, 12, 9);
    final store = AppStore(storage: MemoryStorage(), clock: () => t);
    final acme = store.addClient('Acme');
    final globex = store.addClient('Globex');
    for (final (day, c, task) in [
      (12, acme, 'Design'),
      (12, globex, 'Audit'),
      (13, acme, 'Build'),
    ]) {
      t = DateTime(2026, 10, day, 9 + store.entries.length);
      store.toggle(c.id, note: task);
      t = t.add(const Duration(minutes: 30));
      store.stop();
    }
    await tester.pumpWidget(ConClockApp(store: store));
    await tester.pump();
    await tester.tap(find.text('Log').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Client'));
    await tester.pumpAndSettle();

    double y(String text) => tester.getTopLeft(find.text(text).first).dy;
    // Acme, with its two days (newest first), then Globex.
    expect(y('Acme'), lessThan(y('Build')));
    expect(y('Build'), lessThan(y('Design')));
    expect(y('Design'), lessThan(y('Globex')));
    expect(y('Globex'), lessThan(y('Audit')));
    expect(find.text('1:00'), findsOneWidget); // Acme's week

    await tester.tap(find.text('Acme').first); // the group
    await tester.pump();
    expect(find.text('Design'), findsNothing);
    expect(find.text('Audit'), findsOneWidget);
  });

  testWidgets('a screen reader can open a task and its menu', (tester) async {
    final semantics = tester.ensureSemantics();
    var t = DateTime(2026, 10, 12, 9);
    final store = AppStore(storage: MemoryStorage(), clock: () => t);
    final acme = store.addClient('Acme');
    store.toggle(acme.id, note: 'Monday work');
    t = t.add(const Duration(hours: 1));
    store.stop();
    await tester.pumpWidget(ConClockApp(store: store));
    await tester.pump();
    await tester.tap(find.text('Log').last);
    await tester.pumpAndSettle();

    // The row's actions as the platform sees them: on its merged node.
    SemanticsNode row() {
      var node = find.semantics
          .byLabel(RegExp('Monday work'))
          .evaluate()
          .single;
      while (node.isMergedIntoParent) {
        node = node.parent!;
      }
      return node;
    }

    row().owner!.performAction(row().id, SemanticsAction.tap);
    await tester.pumpAndSettle();
    expect(find.text('9:00 AM – 10:00 AM'), findsOneWidget);

    row().owner!.performAction(row().id, SemanticsAction.longPress);
    await tester.pumpAndSettle();
    expect(find.text('Rename task…'), findsOneWidget);
    semantics.dispose();
  });
}
