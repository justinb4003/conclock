import 'dart:ui' show AppExitResponse;
import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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

  ThemeData _theme(Brightness b) => ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF1E88E5),
      brightness: b,
    ),
    visualDensity: VisualDensity.adaptivePlatformDensity,
  );

  @override
  Widget build(BuildContext context) {
    return StoreScope(
      store: widget.store,
      child: MaterialApp(
        title: 'ConClock',
        debugShowCheckedModeBanner: false,
        theme: _theme(Brightness.light),
        darkTheme: _theme(Brightness.dark),
        home: const HomeScreen(),
      ),
    );
  }
}
