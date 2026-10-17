import 'package:conclock/models.dart';
import 'package:conclock/screens/tracker_screen.dart';
import 'package:conclock/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'store_test.dart' show MemoryStorage;

void main() {
  late AppStore store;
  late Client acme;

  /// Acme's earlier tasks, newest first: Code review, Design review,
  /// Planning. Then an unnamed entry runs.
  setUp(() {
    var t = DateTime(2026, 10, 16, 9);
    store = AppStore(storage: MemoryStorage(), clock: () => t);
    acme = store.addClient('Acme');
    for (final task in ['Planning', 'Design review', 'Code review']) {
      store.toggle(acme.id, note: task);
      t = t.add(const Duration(minutes: 30));
    }
    store.toggle(acme.id, note: '');
  });

  Finder field() => find.byType(TextField);
  Finder suggestion(String task) => find.descendant(
    of: find.byType(ListView).last,
    matching: find.widgetWithText(ListTile, task),
  );

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
    await tester.tap(field());
    await tester.pump();
  }

  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(field(), text);
    await tester.pump();
  }

  Future<void> enter(WidgetTester tester) async {
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
  }

  List<String> history() => [
    for (final e in store.entries)
      if (!e.isRunning) e.note,
  ];

  testWidgets('suggests earlier tasks, any case; picking one joins it', (
    tester,
  ) async {
    await pumpTrack(tester);
    await type(tester, 'REV');
    expect(suggestion('Code review'), findsOneWidget);
    expect(suggestion('Design review'), findsOneWidget);
    expect(suggestion('Planning'), findsNothing);

    // Starting with the text ranks first.
    await type(tester, 'des');
    expect(suggestion('Design review'), findsOneWidget);
    expect(suggestion('Code review'), findsNothing);

    await tester.tap(suggestion('Design review'));
    await tester.pump();
    expect(store.running?.note, 'Design review');
    expect(history(), ['Code review', 'Design review', 'Planning']);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('typing an earlier task in another case joins it', (
    tester,
  ) async {
    await pumpTrack(tester);
    await type(tester, 'planning');
    await enter(tester);
    expect(store.running?.note, 'Planning');
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('Enter keeps a new name unless a suggestion was chosen', (
    tester,
  ) async {
    await pumpTrack(tester);
    await type(tester, 'Review');
    expect(suggestion('Code review'), findsOneWidget);
    await enter(tester);
    expect(store.running?.note, 'Review');

    // With the arrow keys, Enter takes the highlighted suggestion.
    await tester.tap(field());
    await tester.pump();
    await type(tester, 'revi');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await enter(tester);
    expect(store.running?.note, 'Design review'); // the second one
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('retyping a resumed task as another one leaves history', (
    tester,
  ) async {
    store.toggle(acme.id, note: 'Planning'); // resume it
    await pumpTrack(tester);
    await type(tester, 'code REVIEW');
    await enter(tester);
    expect(store.running?.note, 'Code review');
    expect(history(), ['Code review', 'Design review', 'Planning']);
    expect(find.textContaining('Renamed'), findsNothing);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets(
    'Tab takes the highlighted suggestion',
    (tester) async {
      await pumpTrack(tester);
      await type(tester, 'rev');
      expect(
        find.descendant(
          of: suggestion('Code review'),
          matching: find.text('Tab'),
        ),
        findsOneWidget,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(store.running?.note, 'Code review');

      // The arrow keys pick which.
      await tester.tap(field());
      await tester.pump();
      await type(tester, 'rev');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(store.running?.note, 'Design review');

      // No suggestions: Tab just moves on, keeping what's typed.
      await tester.tap(field());
      await tester.pump();
      await type(tester, 'Brand new');
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(store.running?.note, 'Brand new');
      await tester.pump(const Duration(seconds: 5));
    },
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );
}
