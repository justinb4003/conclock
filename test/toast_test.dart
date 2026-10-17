import 'package:conclock/main.dart';
import 'package:conclock/store.dart';
import 'package:conclock/widgets/dialogs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'store_test.dart' show MemoryStorage;

void main() {
  testWidgets('a toast with Undo goes away by itself', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => toast(context, 'Deleted Acme', undo: () {}),
              child: const Text('Delete'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Deleted Acme'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('Deleted Acme'), findsNothing);
  });

  testWidgets('a toast sits above the tab\'s + button', (tester) async {
    final store = AppStore(storage: MemoryStorage());
    store.addClient('Acme');
    await tester.pumpWidget(ConClockApp(store: store));
    await tester.tap(find.text('Clients').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    final bar = tester.getRect(find.byType(SnackBar));
    final fab = tester.getRect(find.byType(FloatingActionButton));
    expect(bar.bottom, lessThanOrEqualTo(fab.top));
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });
}
