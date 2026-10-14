import 'package:conclock/format.dart';
import 'package:conclock/models.dart';
import 'package:conclock/screens/timesheet_screen.dart';
import 'package:conclock/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'store_test.dart' show MemoryStorage;

void main() {
  late AppStore store;

  setUp(() {
    store = AppStore(storage: MemoryStorage());
    final acme = store.addClient('Acme');
    final globex = store.addClient('Globex');
    final mon = weekStart(DateTime.now());
    void add(Client c, int day, int from, int to, String note) =>
        store.addEntry(
          Entry(
            id: newId(),
            clientId: c.id,
            start: addDays(mon, day).add(Duration(hours: from)),
            end: addDays(mon, day).add(Duration(hours: to)),
            note: note,
          ),
        );
    add(acme, 0, 9, 12, 'Design'); // Mon 3h
    add(acme, 0, 12, 13, 'Review'); // Mon 1h
    add(globex, 0, 13, 17, 'Migration'); // Mon 4h
    add(acme, 1, 9, 17, 'Design'); // Tue 8h
  });

  Future<void> pump(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      StoreScope(
        store: store,
        child: const MaterialApp(home: TimesheetScreen()),
      ),
    );
  }

  testWidgets('sums cells, rows and columns; tasks expand', (tester) async {
    await pump(tester, const Size(1000, 700));
    store.setDecimalHours(true);
    await tester.pump();

    expect(find.text('4.00'), findsWidgets); // Acme Mon, Globex Mon
    expect(find.text('12.00'), findsOneWidget); // Acme week
    expect(find.text('8.00'), findsWidgets); // Mon total, Tue total
    expect(find.text('16.00'), findsOneWidget); // grand total
    expect(find.text('Design'), findsNothing);

    await tester.tap(find.text('Acme'));
    await tester.pump();
    expect(find.text('Design'), findsOneWidget);
    expect(find.text('11.00'), findsOneWidget); // Design week total

    final tip = tester
        .widgetList<Tooltip>(find.byType(Tooltip))
        .firstWhere(
          (t) => t.richMessage?.toPlainText().contains('Acme\nMon') ?? false,
        );
    expect(tip.richMessage!.toPlainText(), contains('Design'));
    expect(tip.richMessage!.toPlainText(), contains('Review'));
    await tester.pump(const Duration(seconds: 1)); // let the save fire
  });

  test('rounds up to the next half hour', () {
    expect(roundUpHalfHour(Duration.zero), Duration.zero);
    expect(
      roundUpHalfHour(const Duration(minutes: 1)),
      const Duration(minutes: 30),
    );
    expect(
      roundUpHalfHour(const Duration(minutes: 30)),
      const Duration(minutes: 30),
    );
    expect(
      roundUpHalfHour(const Duration(minutes: 32)),
      const Duration(hours: 1),
    );
    expect(
      roundUpHalfHour(const Duration(minutes: 61)),
      const Duration(minutes: 90),
    );
  });

  testWidgets('rounding per task vs per day', (tester) async {
    // Acme on Wednesday: 32 min call + 10 min email = 0:42 actual.
    final acme = store.clients.first;
    final wed = addDays(weekStart(DateTime.now()), 2);
    for (final (from, mins, note) in [
      (9 * 60, 32, 'Call'),
      (10 * 60, 10, 'Email'),
    ]) {
      final start = wed.add(Duration(minutes: from));
      store.addEntry(
        Entry(
          id: newId(),
          clientId: acme.id,
          start: start,
          end: start.add(Duration(minutes: mins)),
          note: note,
        ),
      );
    }
    await pump(tester, const Size(1000, 700));
    store.setDecimalHours(true);
    await tester.pump();
    await tester.tap(find.byTooltip('Expand all'));
    await tester.pump();

    expect(find.text('0.70'), findsWidgets); // exact Wed

    store.setRounding(Rounding.task); // 1.00 + 0.50
    await tester.pump();
    expect(find.text('1.50'), findsWidgets);
    expect(find.text('1.00'), findsWidgets); // the call
    expect(find.text('17.50'), findsOneWidget); // 16 + 1.5

    store.setRounding(Rounding.day); // 0:42 → 1.00; tasks stay exact
    await tester.pump();
    expect(find.text('1.50'), findsNothing);
    expect(find.text('0.53'), findsWidgets); // the call, exact
    expect(find.text('17.00'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1)); // let the save fire
  });

  testWidgets('fits a phone by scrolling sideways', (tester) async {
    await pump(tester, const Size(390, 800));
    await tester.tap(find.byTooltip('Expand all'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Migration'), findsOneWidget);
  });
}
