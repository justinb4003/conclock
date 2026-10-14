import 'package:flutter/material.dart';

import '../backup/backup.dart';
import '../desktop/desktop.dart';
import '../store.dart';
import '../widgets/common.dart';
import '../widgets/data_location.dart';

/// App-wide options, plus data location and backups.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final theme = Theme.of(context);

    Widget header(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          header('Display'),
          SwitchListTile(
            title: const Text('Monospace times'),
            subtitle: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: 'Show times and durations as  '),
                  TextSpan(
                    text: '9:05  1:30:00',
                    style: TextStyle(fontFamily: monoFont),
                  ),
                ],
              ),
            ),
            value: store.monoTimes,
            onChanged: store.setMonoTimes,
          ),
          SwitchListTile(
            title: const Text('Decimal hours'),
            subtitle: const Text('Totals as 1.50 instead of 1:30'),
            value: store.decimalHours,
            onChanged: store.setDecimalHours,
          ),
          if (hasTray) ...[
            header('Desktop'),
            SwitchListTile(
              title: const Text('Keep running in tray when closed'),
              subtitle: const Text('Quit from the tray menu'),
              value: store.closeToTray,
              onChanged: store.setCloseToTray,
            ),
          ],
          header('Data'),
          ListTile(
            leading: const Icon(Icons.folder_outlined),
            title: const Text('Data location'),
            subtitle: Text(
              store.storageLocation,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => showDataLocation(context),
          ),
          ListTile(
            leading: const Icon(Icons.upload_file),
            title: const Text('Export backup…'),
            onTap: () => exportBackup(context),
          ),
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('Import backup…'),
            onTap: () => importBackup(context),
          ),
        ],
      ),
    );
  }
}
