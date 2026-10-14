import 'package:flutter/material.dart';

import '../desktop/desktop.dart';
import '../store.dart';
import '../widgets/dialogs.dart';
import '../widgets/idle_watcher.dart';
import 'clients_screen.dart';
import 'log_screen.dart';
import 'timesheet_screen.dart';
import 'tracker_screen.dart';

const _destinations = [
  (Icons.timer_outlined, Icons.timer, 'Track'),
  (Icons.list_alt_outlined, Icons.list_alt, 'Log'),
  (Icons.grid_on_outlined, Icons.grid_on, 'Timesheet'),
  (Icons.people_outline, Icons.people, 'Clients'),
];

/// Bottom navigation on narrow screens, a rail on wide ones.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final error = StoreScope.read(context).loadError;
      if (error != null && mounted) toast(context, error);
    });
  }

  Widget get _page => switch (_index) {
    0 => const TrackerScreen(),
    1 => const LogScreen(),
    2 => const TimesheetScreen(),
    _ => const ClientsScreen(),
  };

  void _select(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    return IdleWatcher(child: TrayShell(child: _layout(context)));
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
            Expanded(child: _page),
          ],
        ),
      );
    }
    return Scaffold(
      body: _page,
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
