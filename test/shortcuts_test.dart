import 'package:conclock/main.dart';
import 'package:conclock/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'store_test.dart' show MemoryStorage;

void main() {
  testWidgets('Ctrl+K quick switch, Ctrl+1 toggle, Ctrl+. stop', (
    tester,
  ) async {
    var t = DateTime(2026, 10, 12, 9);
    final store = AppStore(storage: MemoryStorage(), clock: () => t);
    final acme = store.addClient('Acme');
    final globex = store.addClient('Globex');
    // Give Globex a recent task to switch to.
    store.toggle(globex.id, note: 'Migration');
    t = t.add(const Duration(hours: 1));
    store.stop();
    await tester.pumpWidget(ConClockApp(store: store));
    await tester.pump();

    Future<void> ctrl(LogicalKeyboardKey key) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(key);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
    }

    await ctrl(LogicalKeyboardKey.keyK);
    expect(find.text('Switch to client or task…'), findsOneWidget);
    await tester.enterText(find.byType(EditableText).last, 'glo mig');
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(store.running?.clientId, globex.id);
    expect(store.running?.note, 'Migration');

    t = t.add(const Duration(minutes: 30));
    await ctrl(LogicalKeyboardKey.digit1); // Acme: unnamed
    expect(store.running?.clientId, acme.id);

    t = t.add(const Duration(minutes: 30));
    store.setNote(store.running!, 'Planning');
    await ctrl(LogicalKeyboardKey.period);
    expect(store.running, isNull);
    await tester.pump(const Duration(seconds: 1));
  });
}
