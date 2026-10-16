import 'package:conclock/screens/tracker_screen.dart';
import 'package:conclock/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'store_test.dart' show MemoryStorage;

void main() {
  late DateTime t;
  late AppStore store;

  Future<void> pumpTrack(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      StoreScope(
        store: store,
        child: const MaterialApp(home: TrackerScreen()),
      ),
    );
  }

  Finder field() => find.byType(TextField);
  List<String> notes() => [for (final e in store.entries) e.note];

  setUp(() {
    t = DateTime(2026, 10, 16, 9);
    store = AppStore(storage: MemoryStorage(), clock: () => t);
  });

  testWidgets('fixing a resumed task name renames the task', (tester) async {
    final acme = store.addClient('Acme');
    store.toggle(acme.id, note: 'desing');
    t = t.add(const Duration(minutes: 30));
    store.toggle(acme.id, note: 'desing'); // stops
    t = t.add(const Duration(minutes: 5));
    store.toggle(acme.id, note: 'desing'); // resumes
    await pumpTrack(tester);

    await tester.tap(field());
    await tester.pump();
    await tester.enterText(field(), 'Design');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(notes(), ['Design', 'Design']);
    expect(find.text('Renamed “desing” to “Design”'), findsOneWidget);

    // Undo leaves this entry as typed and the earlier one as it was.
    await tester.pump(const Duration(milliseconds: 500)); // snackbar in
    await tester.tap(find.text('Undo'));
    await tester.pump();
    expect(notes(), ['Design', 'desing']);
    await tester.pump(const Duration(seconds: 5)); // let the snackbar go
  });

  testWidgets('naming a fresh entry renames nothing else', (tester) async {
    final acme = store.addClient('Acme');
    store.toggle(acme.id, note: 'Review');
    t = t.add(const Duration(minutes: 30));
    store.toggle(acme.id, note: ''); // a new, unnamed entry
    await pumpTrack(tester);

    await tester.tap(field());
    await tester.enterText(field(), 'Design');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(notes(), ['Design', 'Review']);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('New task ends this one and starts a blank one', (tester) async {
    final acme = store.addClient('Acme');
    await pumpTrack(tester);
    final newTask = find.byTooltip('New task');

    store.toggle(acme.id);
    await tester.pump();
    // Nothing named yet to move on from.
    expect(
      tester
          .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.add_task))
          .onPressed,
      isNull,
    );

    await tester.tap(field());
    await tester.enterText(field(), 'Design');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    t = t.add(const Duration(minutes: 30));
    await tester.tap(newTask);
    await tester.pump();

    expect(notes(), ['', 'Design']);
    expect(store.running?.clientId, acme.id);
    expect(store.entries.last.end, t);
    expect(tester.widget<TextField>(field()).focusNode!.hasFocus, isTrue);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('New task after typing over a name keeps the old task', (
    tester,
  ) async {
    final acme = store.addClient('Acme');
    store.toggle(acme.id, note: 'Design');
    await pumpTrack(tester);
    t = t.add(const Duration(minutes: 30));

    await tester.tap(field());
    await tester.pump();
    await tester.enterText(field(), 'Review');
    await tester.tap(find.byTooltip('New task'));
    await tester.pump();

    expect(notes(), ['Review', 'Design']);
    expect(store.running?.note, 'Review');
    expect(find.textContaining('Renamed'), findsNothing);
    await tester.pump(const Duration(seconds: 5));
  });
}
