import 'package:conclock/main.dart';
import 'package:conclock/store.dart';
import 'package:conclock/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'store_test.dart' show MemoryStorage;

void main() {
  testWidgets('monospace times setting', (tester) async {
    var t = DateTime(2026, 10, 12, 9);
    final storage = MemoryStorage();
    final store = AppStore(storage: storage, clock: () => t);
    final acme = store.addClient('Acme');
    store.toggle(acme.id, note: 'Work');
    t = t.add(const Duration(minutes: 90));
    store.stop();
    await tester.pumpWidget(ConClockApp(store: store));
    await tester.pump();

    String? fontOf(String text) =>
        tester.widget<Text>(find.text(text).first).style?.fontFamily;
    expect(fontOf('1:30'), isNot(monoFont));

    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Monospace times'));
    await tester.pump();
    expect(store.monoTimes, isTrue);

    await tester.tap(find.text('Track').last);
    await tester.pumpAndSettle();
    expect(fontOf('1:30'), monoFont);

    // Saved with the data.
    await store.flush();
    final reloaded = AppStore(storage: storage);
    await reloaded.load();
    expect(reloaded.monoTimes, isTrue);
  });
}
