import 'package:conclock/main.dart';
import 'package:conclock/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

    await tester.tap(find.byTooltip('Quick switch (/)'));
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

  testWidgets('/ and ? open it, but type in a text field', (tester) async {
    final store = AppStore(storage: MemoryStorage());
    final acme = store.addClient('Acme');
    await tester.pumpWidget(ConClockApp(store: store));
    await tester.pump();
    final hint = find.text('Switch to client or task…');

    await tester.sendKeyEvent(LogicalKeyboardKey.slash);
    await tester.pumpAndSettle();
    expect(hint, findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(hint, findsNothing);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.slash, character: '?');
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();
    expect(hint, findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    // In the task name field, / is just a character.
    store.toggle(acme.id);
    await tester.pump();
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.slash);
    await tester.pumpAndSettle();
    expect(hint, findsNothing);

    // Done typing (Enter): / opens it again.
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.slash);
    await tester.pumpAndSettle();
    expect(hint, findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    store.stop();
    await tester.pump(const Duration(seconds: 1));
  });
}
