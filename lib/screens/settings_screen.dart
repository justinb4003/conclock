import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_info.dart';
import '../backup/backup.dart';
import '../desktop/desktop.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/data_location.dart';
import '../widgets/dialogs.dart';

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
          // Most used first; how the app looks (set once) after the data.
          header('Display'),
          SwitchListTile(
            title: const Text('Decimal hours'),
            subtitle: const Text('Totals as 1.50 instead of 1:30'),
            value: store.decimalHours,
            onChanged: store.setDecimalHours,
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
            title: const Text('Dyslexia-friendly font'),
            subtitle: const Text(
              'Set all text in OpenDyslexic',
              style: TextStyle(fontFamily: dyslexicFont),
            ),
            value: store.dyslexicFont,
            onChanged: store.setDyslexicFont,
          ),
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
          header('Appearance'),
          ListTile(
            title: const Text('Color'),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                children: [
                  for (final c in clientPalette)
                    ColorChoice(
                      color: c,
                      selected: c == store.appColor,
                      onTap: () => store.setAppColor(c),
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
          ListTile(
            title: const Text('Theme'),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(value: ThemeMode.system, label: Text('System')),
                  ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                  ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                ],
                selected: {store.themeMode},
                showSelectedIcon: false,
                onSelectionChanged: (s) => store.setThemeMode(s.first),
              ),
            ),
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
          header('About'),
          const _AboutTile(),
          const _SourceCodeTile(),
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

const _repoUrl = 'https://github.com/justinb4003/conclock';

/// Opens the project's GitHub page in the browser.
class _SourceCodeTile extends StatelessWidget {
  const _SourceCodeTile();

  Future<void> _open(BuildContext context) async {
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(_repoUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}
    if (!opened && context.mounted) toast(context, 'Couldn’t open the link');
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.code),
      title: const Text('Source code'),
      subtitle: const Text('github.com/justinb4003/conclock'),
      trailing: const Icon(Icons.open_in_new),
      onTap: () => _open(context),
    );
  }
}
