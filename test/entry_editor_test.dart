import 'package:conclock/models.dart';
import 'package:conclock/store.dart';
import 'package:conclock/widgets/entry_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'store_test.dart' show MemoryStorage;

void main() {
  testWidgets('end day can be moved back and forth', (tester) async {
    final store = AppStore(
      storage: MemoryStorage(),
      clock: () => DateTime(2026, 10, 14, 12),
    );
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
    await tester.pumpWidget(
      StoreScope(
        store: store,
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  showEntryEditor(context, entry: store.entryById('e1')),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.textContaining('(+1d)'), findsOneWidget);
    expect(find.text('Duration 25:00'), findsOneWidget);

    await tester.tap(find.byTooltip('End a day earlier'));
    await tester.pump();
    expect(find.textContaining('(+1d)'), findsNothing);
    expect(find.text('Duration 1:00'), findsOneWidget);
    // 10:00 the day before would be before the start.
    final earlier = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.remove),
    );
    expect(earlier.onPressed, isNull);

    await tester.tap(find.byTooltip('End a day later'));
    await tester.tap(find.byTooltip('End a day later'));
    await tester.pump();
    expect(find.textContaining('(+2d)'), findsOneWidget);
    await tester.tap(find.byTooltip('End a day earlier'));
    await tester.tap(find.byTooltip('End a day earlier'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(store.entryById('e1')!.end, DateTime(2026, 10, 12, 10));
  });
}
