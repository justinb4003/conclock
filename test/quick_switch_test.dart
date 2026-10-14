import 'package:conclock/main.dart';
import 'package:conclock/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'store_test.dart' show MemoryStorage;

void main() {
  testWidgets('quick switch filters and starts a task', (tester) async {
    var t = DateTime(2026, 10, 12, 9);
    final store = AppStore(storage: MemoryStorage(), clock: () => t);
    store.addClient('Acme');
    final globex = store.addClient('Globex');
    store.toggle(globex.id, note: 'Migration');
    t = t.add(const Duration(hours: 1));
    store.stop();
    await tester.pumpWidget(ConClockApp(store: store));
    await tester.pump();

    await tester.tap(find.byTooltip('Quick switch'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'glo mig');
    await tester.pump();
    expect(find.text('Acme'), findsOneWidget); // only the Track row
    await tester.tap(find.text('Globex › Migration'));
    await tester.pumpAndSettle();

    expect(store.running?.clientId, globex.id);
    expect(store.running?.note, 'Migration');
    store.stop();
    await tester.pump(const Duration(seconds: 1));
  });
}
