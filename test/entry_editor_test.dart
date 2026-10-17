import 'package:conclock/models.dart';
import 'package:conclock/store.dart';
import 'package:conclock/widgets/entry_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'store_test.dart' show MemoryStorage;

void main() {
  late AppStore store;

  setUp(() {
    store = AppStore(
      storage: MemoryStorage(),
      clock: () => DateTime(2026, 10, 14, 12),
    );
  });

  /// A button that opens the editor on entry [id].
  Future<void> open(WidgetTester tester, String id) async {
    await tester.pumpWidget(
      StoreScope(
        store: store,
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  showEntryEditor(context, entry: store.entryById(id)),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('picking the end time puts it after the start', (tester) async {
    final acme = store.addClient('Acme');
    // A timer left running overnight: 9:00 to 10:00 the next day.
    store.addEntry(
      Entry(
        id: 'e1',
        clientId: acme.id,
        start: DateTime(2026, 10, 12, 9),
        end: DateTime(2026, 10, 13, 10),
      ),
    );
    await open(tester, 'e1');
    expect(find.textContaining('(+1d)'), findsOneWidget);
    expect(find.text('Duration 25:00'), findsOneWidget);

    // 10:00 again: the first 10:00 after the start is the same day.
    await tester.tap(find.textContaining('(+1d)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.textContaining('(+1d)'), findsNothing);
    expect(find.text('Duration 1:00'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(store.entryById('e1')!.end, DateTime(2026, 10, 12, 10));
  });

  testWidgets('an entry whose client is gone still opens and saves', (
    tester,
  ) async {
    store.addClient('Acme');
    // E.g. from an imported backup whose client list doesn't match.
    store.addEntry(
      Entry(
        id: 'orphan',
        clientId: 'deleted-client',
        start: DateTime(2026, 10, 12, 9),
        end: DateTime(2026, 10, 12, 10),
        note: 'Old work',
      ),
    );
    await open(tester, 'orphan');
    expect(tester.takeException(), isNull);
    expect(find.text('Unknown client'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(store.entryById('orphan')!.clientId, 'deleted-client');
  });
}
