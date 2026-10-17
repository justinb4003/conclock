import 'package:conclock/models.dart';
import 'package:conclock/screens/clients_screen.dart';
import 'package:conclock/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'store_test.dart' show MemoryStorage;

void main() {
  testWidgets('tap a client to edit its name and color', (tester) async {
    final store = AppStore(storage: MemoryStorage());
    final acme = store.addClient('Acme');
    await tester.pumpWidget(
      StoreScope(
        store: store,
        child: const MaterialApp(home: ClientsScreen()),
      ),
    );

    await tester.tap(find.text('Acme'));
    await tester.pumpAndSettle();
    expect(find.text('Edit client'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Acme Corp');
    await tester.tap(find.byTooltip('Green'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(acme.name, 'Acme Corp');
    expect(acme.color, clientPalette[1]);
  });
}
