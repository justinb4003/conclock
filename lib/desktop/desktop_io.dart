import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../app_info.dart';
import '../format.dart';
import '../store.dart';
import '../tracking.dart';

/// Whether there's a tray to hide in (desktop only; not under `flutter test`,
/// which has no native plugins).
bool get hasTray =>
    (Platform.isLinux || Platform.isWindows || Platform.isMacOS) &&
    !Platform.environment.containsKey('FLUTTER_TEST');

/// Call before runApp.
Future<void> initDesktopWindow() async {
  if (!hasTray) return;
  await windowManager.ensureInitialized();
  // The native runners title the window plain "ConClock".
  await windowManager.setTitle('ConClock ${await appVersion()}');
}

/// Tray icon with status and quick actions; closing the window hides it
/// there (unless turned off) so the timer keeps running.
class TrayShell extends StatefulWidget {
  const TrayShell({super.key, required this.child});

  final Widget child;

  @override
  State<TrayShell> createState() => _TrayShellState();
}

class _TrayShellState extends State<TrayShell>
    with TrayListener, WindowListener {
  AppStore? _store;
  Timer? _tick;
  bool? _preventClose;

  /// Last menu sent, to skip redundant updates.
  String _shown = '';

  @override
  void initState() {
    super.initState();
    if (!hasTray) return;
    windowManager.addListener(this);
    trayManager.addListener(this);
    trayManager
        .setIcon(
          Platform.isWindows ? 'assets/icon/tray.ico' : 'assets/icon/tray.png',
        )
        .then((_) => _refresh());
    // Keeps the elapsed time in the menu current.
    _tick = Timer.periodic(const Duration(seconds: 30), (_) => _refresh());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final store = StoreScope.read(context);
    if (store != _store) {
      _store?.removeListener(_refresh);
      _store = store..addListener(_refresh);
      _refresh();
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    _store?.removeListener(_refresh);
    if (hasTray) {
      windowManager.removeListener(this);
      trayManager.removeListener(this);
    }
    super.dispose();
  }

  String _status(AppStore store) {
    final r = store.running;
    if (r == null) return 'Not tracking';
    final client = store.clientById(r.clientId)?.name ?? '?';
    final task = r.note.trim().isEmpty ? '' : ' · ${r.note.trim()}';
    return '$client$task — ${fmtHm(r.durationAt(store.now()))}';
  }

  Future<void> _refresh() async {
    final store = _store;
    if (!hasTray || store == null) return;
    if (_preventClose != store.closeToTray) {
      _preventClose = store.closeToTray;
      await windowManager.setPreventClose(store.closeToTray);
    }
    final status = _status(store);
    final clients = store.activeClients.toList();
    final running = store.running;
    final signature = [
      status,
      for (final c in clients) '${c.id}=${c.name}',
    ].join('|');
    if (signature == _shown) return;
    _shown = signature;
    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(key: 'status', label: status, disabled: true),
          MenuItem.separator(),
          MenuItem(key: 'show', label: 'Show ConClock'),
          if (running != null) MenuItem(key: 'stop', label: 'Stop timer'),
          if (clients.isNotEmpty)
            MenuItem.submenu(
              label: 'Start',
              submenu: Menu(
                items: [
                  for (final c in clients)
                    MenuItem(
                      key: 'client:${c.id}',
                      label: c.name,
                      checked: running?.clientId == c.id,
                    ),
                ],
              ),
            ),
          MenuItem.separator(),
          MenuItem(key: 'quit', label: 'Quit ConClock'),
        ],
      ),
    );
    if (!Platform.isLinux) await trayManager.setToolTip('ConClock: $status');
  }

  Future<void> _show() async {
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> _quit() async {
    await _store?.flush();
    await trayManager.destroy();
    await windowManager.setPreventClose(false);
    await windowManager.destroy();
  }

  /// Stopping an unnamed entry asks for a name, which needs the window.
  Future<void> _showIfPromptNeeded() async {
    final r = _store?.running;
    if (r != null && r.note.trim().isEmpty) await _show();
  }

  @override
  void onWindowClose() {
    if (_store?.closeToTray ?? true) {
      windowManager.hide();
    } else {
      _quit();
    }
  }

  @override
  void onTrayIconMouseDown() => _show();

  @override
  void onTrayIconRightMouseDown() => trayManager.popUpContextMenu();

  @override
  Future<void> onTrayMenuItemClick(MenuItem item) async {
    final key = item.key ?? '';
    final store = _store;
    if (store == null) return;
    switch (key) {
      case 'show':
        await _show();
      case 'quit':
        await _quit();
      case 'stop':
        await _showIfPromptNeeded();
        if (mounted) await stopTracking(context);
      case _ when key.startsWith('client:'):
        final client = store.clientById(key.substring('client:'.length));
        if (client == null) return;
        await _showIfPromptNeeded();
        if (mounted) await toggleTracking(context, client);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
