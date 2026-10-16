import 'package:flutter/material.dart';

import '../app_info.dart';
import '../backup/backup.dart';
import '../desktop/desktop.dart';
import '../models.dart';
import '../store.dart';
import '../widgets/common.dart';
import '../widgets/data_location.dart';

/// App-wide options, plus data location, backups and the app version.
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
          ListTile(
            title: const Text('Theme'),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.system,
                    icon: Icon(Icons.brightness_auto_outlined),
                    label: Text('System'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.light,
                    icon: Icon(Icons.light_mode_outlined),
                    label: Text('Light'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    icon: Icon(Icons.dark_mode_outlined),
                    label: Text('Dark'),
                  ),
                ],
                selected: {store.themeMode},
                showSelectedIcon: false,
                onSelectionChanged: (s) => store.setThemeMode(s.first),
              ),
            ),
          ),
          ListTile(
            title: const Text('Color'),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in clientPalette)
                    InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => store.setAppColor(c),
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: Color(c),
                        child: c == store.appColor
                            ? const Icon(
                                Icons.check,
                                size: 18,
                                color: Colors.white,
                              )
                            : null,
                      ),
                    ),
                ],
              ),
            ),
          ),
          ListTile(
            title: const Text('Background'),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: SegmentedButton<Backdrop>(
                  segments: const [
                    ButtonSegment(
                      value: Backdrop.neutral,
                      label: Text('Neutral'),
                    ),
                    ButtonSegment(
                      value: Backdrop.tinted,
                      label: Text('Tinted'),
                    ),
                    ButtonSegment(value: Backdrop.bold, label: Text('Bold')),
                  ],
                  selected: {store.background},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => store.setBackground(s.first),
                ),
              ),
            ),
          ),
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
          header('About'),
          const _AboutTile(),
        ],
      ),
    );
  }
}

class _AboutTile extends StatefulWidget {
  const _AboutTile();

  @override
  State<_AboutTile> createState() => _AboutTileState();
}

class _AboutTileState extends State<_AboutTile> {
  final _version = appVersion();

  @override
  Widget build(BuildContext context) {
    final released = DateTime.tryParse(releaseDate);
    return FutureBuilder<String>(
      future: _version,
      builder: (context, snapshot) => ListTile(
        leading: const Icon(Icons.info_outline),
        title: Text(
          snapshot.hasData ? 'ConClock ${snapshot.data}' : 'ConClock',
        ),
        subtitle: Text(
          released == null
              ? 'Development build'
              : 'Released '
                    '${MaterialLocalizations.of(context).formatFullDate(released)}',
        ),
      ),
    );
  }
}
