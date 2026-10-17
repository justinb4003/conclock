import 'package:flutter/material.dart';

import '../backup/backup.dart';
import '../desktop/desktop.dart';
import '../store.dart';
import '../widgets/dialogs.dart';
import '../widgets/idle_watcher.dart';
import 'clients_screen.dart';
import 'log_screen.dart';
import 'settings_screen.dart';
import 'timesheet_screen.dart';
import 'tracker_screen.dart';

const _destinations = [
  (Icons.timer_outlined, Icons.timer, 'Track'),
  (Icons.list_alt_outlined, Icons.list_alt, 'Log'),
  (Icons.grid_on_outlined, Icons.grid_on, 'Timesheet'),
  (Icons.people_outline, Icons.people, 'Clients'),
  (Icons.settings_outlined, Icons.settings, 'Settings'),
];

/// Bottom navigation on narrow screens, a rail on wide ones.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;
  AppStore? _store;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final error = StoreScope.read(context).loadError;
      if (error != null && mounted) toast(context, error);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final store = StoreScope.read(context);
    if (store != _store) {
      _store?.removeListener(_showNotice);
      _store = store..addListener(_showNotice);
    }
  }

  @override
  void dispose() {
    _store?.removeListener(_showNotice);
    super.dispose();
  }

  /// One-off messages from the store (e.g. edits set aside after another
  /// instance saved first).
  void _showNotice() {
    final notice = _store?.takeNotice();
    if (notice == null || !mounted) return;
    final setAside = _store?.setAside;
    toast(
      context,
      notice,
      action: setAside == null
          ? null
          : SnackBarAction(
              label: 'Export',
              onPressed: () => exportJsonAs(context, 'set-aside', setAside),
            ),
    );
  }

  /// The current tab. Its own messenger shows toasts in the tab's Scaffold,
  /// which floats them above that tab's + button; the outer one would cover
  /// it. Not keyed by tab, so an Undo toast carries over when switching.
  Widget get _page => ScaffoldMessenger(
    child: switch (_index) {
      0 => const TrackerScreen(),
      1 => const LogScreen(),
      2 => const TimesheetScreen(),
      3 => const ClientsScreen(),
      _ => const SettingsScreen(),
    },
  );

  void _select(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    return IdleWatcher(child: TrayShell(child: _layout(context)));
  }

  /// The current tab, under a warning while saving fails.
  Widget _body(BuildContext context) {
    final error = StoreScope.of(context).saveError;
    if (error == null) return _page;
    return Column(
      children: [
        _SaveErrorBanner(error: error),
        Expanded(child: _page),
      ],
    );
  }

  Widget _layout(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 720;
    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: _select,
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final (icon, selected, label) in _destinations)
                  NavigationRailDestination(
                    icon: Icon(icon),
                    selectedIcon: Icon(selected),
                    label: Text(label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: _body(context)),
          ],
        ),
      );
    }
    return Scaffold(
      body: _body(context),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _select,
        height: 64,
        destinations: [
          for (final (icon, selected, label) in _destinations)
            NavigationDestination(
              icon: Icon(icon),
              selectedIcon: Icon(selected),
              label: label,
            ),
        ],
      ),
    );
  }
}

/// Shown while saves fail: changes since are only in memory.
class _SaveErrorBanner extends StatelessWidget {
  const _SaveErrorBanner({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.errorContainer,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: Row(
            children: [
              Icon(Icons.error_outline, color: scheme.onErrorContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Couldn’t save your changes ($error). Export a backup '
                  'before closing ConClock.',
                  style: TextStyle(color: scheme.onErrorContainer),
                ),
              ),
              TextButton(
                onPressed: () => exportBackup(context),
                child: const Text('Export'),
              ),
              TextButton(
                onPressed: StoreScope.read(context).flush,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
