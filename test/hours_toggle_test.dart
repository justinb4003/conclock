import 'package:conclock/main.dart';
import 'package:conclock/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'store_test.dart' show MemoryStorage;

void main() {
  Future<AppStore> pump(WidgetTester tester, double width) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = AppStore(storage: MemoryStorage());
    store.addClient('Acme');
    await tester.pumpWidget(ConClockApp(store: store));
    await tester.pump();
    return store;
  }

  testWidgets('h:mm / Decimal on Track, Log and Timesheet', (tester) async {
    final store = await pump(tester, 1000);
    await tester.tap(find.text('Decimal'));
    await tester.pump();
    expect(store.decimalHours, isTrue);
    for (final tab in ['Log', 'Timesheet']) {
      await tester.tap(find.text(tab).last);
      await tester.pumpAndSettle();
      expect(find.text('h:mm'), findsOneWidget);
    }
    await tester.tap(find.text('h:mm'));
    await tester.pump();
    expect(store.decimalHours, isFalse);
    await store.flush();
  });

  testWidgets('one switch button on a phone', (tester) async {
    final store = await pump(tester, 360);
    expect(find.text('Decimal'), findsNothing);
    await tester.tap(
      find.byTooltip('Hours and minutes; switch to decimal hours'),
    );
    await tester.pump();
    expect(store.decimalHours, isTrue);
    expect(find.text('1.50'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await store.flush();
  });
}
