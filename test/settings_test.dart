import 'package:conclock/main.dart';
import 'package:conclock/models.dart';
import 'package:conclock/screens/settings_screen.dart';
import 'package:conclock/store.dart';
import 'package:conclock/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'store_test.dart' show MemoryStorage;

void main() {
  setUpAll(
    () => PackageInfo.setMockInitialValues(
      appName: 'conclock',
      packageName: 'conclock',
      version: '1.2.3',
      buildNumber: '9',
      buildSignature: '',
    ),
  );

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

  testWidgets('theme: system, light or dark', (tester) async {
    final storage = MemoryStorage();
    final store = AppStore(storage: storage);
    await tester.pumpWidget(ConClockApp(store: store));
    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();

    Brightness brightness() =>
        Theme.of(tester.element(find.text('Theme'))).brightness;
    expect(store.themeMode, ThemeMode.system);
    expect(brightness(), Brightness.light); // the test "OS" is light

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(brightness(), Brightness.dark);

    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();
    expect(brightness(), Brightness.light);

    await tester.tap(find.text('Dark'));
    await store.flush();
    final reloaded = AppStore(storage: storage);
    await reloaded.load();
    expect(reloaded.themeMode, ThemeMode.dark);
    await tester.pumpAndSettle();
  });

  testWidgets('app color and background strength', (tester) async {
    final storage = MemoryStorage();
    final store = AppStore(storage: storage);
    await tester.pumpWidget(ConClockApp(store: store));
    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();

    ThemeData theme() => Theme.of(tester.element(find.text('Color')));
    final blue = theme().colorScheme.primary;

    await tester.tap(find.byType(CircleAvatar).at(4)); // purple
    await tester.pumpAndSettle();
    expect(store.appColor, clientPalette[4]);
    expect(theme().colorScheme.primary, isNot(blue));

    final purplePlain = theme().colorScheme.surface;
    await tester.tap(find.text('Bold'));
    await tester.pumpAndSettle();
    expect(theme().colorScheme.surface, isNot(purplePlain));

    await store.flush();
    final reloaded = AppStore(storage: storage);
    await reloaded.load();
    expect(reloaded.appColor, clientPalette[4]);
    expect(reloaded.background, Backdrop.bold);
  });

  testWidgets('about shows the version', (tester) async {
    final store = AppStore(storage: MemoryStorage());
    await tester.pumpWidget(ConClockApp(store: store));
    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(SettingsScreen), const Offset(0, -3000));
    await tester.pumpAndSettle();
    expect(find.text('ConClock 1.2.3'), findsOneWidget);
    // No RELEASE_DATE define under flutter test.
    expect(find.text('Development build'), findsOneWidget);
  });
}
