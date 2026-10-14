import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../store.dart';
import '../tracking.dart';
import 'entry_editor.dart';
import 'quick_switch.dart';

const _digits = [
  LogicalKeyboardKey.digit1,
  LogicalKeyboardKey.digit2,
  LogicalKeyboardKey.digit3,
  LogicalKeyboardKey.digit4,
  LogicalKeyboardKey.digit5,
  LogicalKeyboardKey.digit6,
  LogicalKeyboardKey.digit7,
  LogicalKeyboardKey.digit8,
  LogicalKeyboardKey.digit9,
];

/// App-wide keyboard shortcuts (inactive while a dialog is open):
/// Ctrl/⌘+K quick switch, +1–9 toggle the Nth client, +. stop, +N add time.
class AppShortcuts extends StatelessWidget {
  const AppShortcuts({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    void toggleNth(int n) {
      final clients = StoreScope.read(context).activeClients.toList();
      if (n < clients.length) toggleTracking(context, clients[n]);
    }

    return CallbackShortcuts(
      bindings: {
        modShortcut(LogicalKeyboardKey.keyK): () => showQuickSwitch(context),
        modShortcut(LogicalKeyboardKey.period): () => stopTracking(context),
        modShortcut(LogicalKeyboardKey.keyN): () => showEntryEditor(context),
        for (var i = 0; i < _digits.length; i++)
          modShortcut(_digits[i]): () => toggleNth(i),
      },
      child: Focus(autofocus: true, child: child),
    );
  }
}
