import 'package:flutter/widgets.dart';

/// Whether there's a tray to hide in (desktop only).
bool get hasTray => false;

Future<void> initDesktopWindow() async {}

class TrayShell extends StatelessWidget {
  const TrayShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}
