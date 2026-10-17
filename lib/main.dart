import 'dart:ui' show AppExitResponse;
import 'package:flutter/material.dart';

import 'desktop/desktop.dart';
import 'screens/home_screen.dart';
import 'store.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initDesktopWindow();
  final store = AppStore();
  await store.load();
  runApp(ConClockApp(store: store));
}

class ConClockApp extends StatefulWidget {
  const ConClockApp({super.key, required this.store});

  final AppStore store;

  @override
  State<ConClockApp> createState() => _ConClockAppState();
}

class _ConClockAppState extends State<ConClockApp> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Saves are debounced; make sure nothing is lost when the app goes away.
    _lifecycle = AppLifecycleListener(
      onHide: widget.store.flush,
      onPause: widget.store.flush,
      onDetach: widget.store.flush,
      onExitRequested: () async {
        await widget.store.flush();
        return AppExitResponse.exit;
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StoreScope(
      store: widget.store,
      // Rebuilt on store changes for the theme settings; home is const, so
      // the screens below don't rebuild because of it.
      child: ListenableBuilder(
        listenable: widget.store,
        builder: (context, _) => MaterialApp(
          title: 'ConClock',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(
            Brightness.light,
            widget.store.appColor,
            widget.store.background,
            dyslexic: widget.store.dyslexicFont,
          ),
          darkTheme: buildTheme(
            Brightness.dark,
            widget.store.appColor,
            widget.store.background,
            dyslexic: widget.store.dyslexicFont,
          ),
          themeMode: widget.store.themeMode,
          home: const HomeScreen(),
        ),
      ),
    );
  }
}
