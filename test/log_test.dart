import 'package:conclock/main.dart';
import 'package:conclock/store.dart';
import 'package:flutter/material.dart';
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
    await tester.tap(find.byTooltip('Collapse day').first);
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
}
