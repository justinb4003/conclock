import 'package:conclock/main.dart';
import 'package:conclock/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'store_test.dart' show MemoryStorage;

void main() {
  testWidgets('started client and task slide to the top and stay there', (
    tester,
  ) async {
    var t = DateTime(2026, 10, 12, 9);
    final store = AppStore(storage: MemoryStorage(), clock: () => t);
    final acme = store.addClient('Acme');
    store.addClient('Initech');
    final globex = store.addClient('Globex');
    for (final (c, task) in [
      (globex, 'Old task'),
      (globex, 'New task'),
      (acme, 'Work'),
    ]) {
      store.toggle(c.id, note: task);
      t = t.add(const Duration(minutes: 30));
    }
    store.stop();
    await tester.pumpWidget(ConClockApp(store: store));
    await tester.pump();

    double y(String text) =>
        tester.getTopLeft(find.widgetWithText(ListTile, text)).dy;
    expect(y('Acme'), lessThan(y('Globex')));
    expect(y('New task'), lessThan(y('Old task')));
    // Relative to Acme: the status panel grows once a timer runs.
    double gap() => y('Globex') - y('Acme');
    final before = gap();

    // Resume the older task: Globex moves to the top, that task first.
    await tester.tap(find.widgetWithText(ListTile, 'Old task'));
    await tester.pump(); // the tap's async start
    await tester.pump(); // reorders, then measures
    await tester.pump(const Duration(milliseconds: 100));
    final mid = gap();
    await tester.pumpAndSettle();
    final after = gap();
    expect(after, lessThan(0)); // above Acme now
    expect(mid, inExclusiveRange(after, before)); // it slid, not jumped
    expect(y('Acme'), lessThan(y('Initech'))); // then by when last started
    expect(y('Old task'), lessThan(y('New task')));

    // Stopping leaves it on top.
    t = t.add(const Duration(minutes: 30));
    store.stop();
    await tester.pumpAndSettle();
    expect(y('Globex'), lessThan(y('Acme')));
    expect(store.running, isNull);

    // Starting another queues it above; Globex works its way down.
    store.toggle(acme.id, note: 'Work');
    await tester.pumpAndSettle();
    t = t.add(const Duration(minutes: 30));
    store.stop();
    await tester.pumpAndSettle();
    expect(y('Acme'), lessThan(y('Globex')));
    expect(y('Globex'), lessThan(y('Initech')));
  });

  test('track order leaves the user order alone', () {
    var t = DateTime(2026, 10, 12, 9);
    final store = AppStore(storage: MemoryStorage(), clock: () => t);
    store.addClient('Acme');
    store.addClient('Initech');
    final globex = store.addClient('Globex');
    store.toggle(globex.id, note: 'Work');
    t = t.add(const Duration(minutes: 30));
    store.stop();

    expect(store.recentClients.map((c) => c.name), [
      'Globex',
      'Acme',
      'Initech',
    ]);
    expect(store.clients.map((c) => c.name), ['Acme', 'Initech', 'Globex']);
  });
}
