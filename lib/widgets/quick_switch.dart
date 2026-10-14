import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../store.dart';
import '../tracking.dart';

/// "Ctrl" on most platforms, "⌘" on Apple ones.
String get modKey => _apple ? '⌘' : 'Ctrl+';

bool get _apple =>
    defaultTargetPlatform == TargetPlatform.macOS ||
    defaultTargetPlatform == TargetPlatform.iOS;

/// Ctrl (⌘ on Apple) + [key].
SingleActivator modShortcut(LogicalKeyboardKey key) =>
    SingleActivator(key, control: !_apple, meta: _apple);

class _Choice {
  const _Choice(this.client, this.task, this.label, {this.running = false});

  final Client client;
  final String? task;
  final String label;
  final bool running;
}

/// Type-to-filter list of clients and their recent tasks; Enter starts the
/// highlighted one (or stops it if it's running).
Future<void> showQuickSwitch(BuildContext context) async {
  final store = StoreScope.read(context);
  final now = store.now();
  final tasks = store.recentTasks(now);
  final r = store.running;
  final choices = [
    for (final c in store.activeClients) ...[
      _Choice(
        c,
        null,
        c.name,
        running: r?.clientId == c.id && r!.note.trim().isEmpty,
      ),
      for (final t in tasks[c.id] ?? const <String>[])
        _Choice(
          c,
          t,
          '${c.name} › $t',
          running: r?.clientId == c.id && r!.note.trim() == t,
        ),
    ],
  ];
  final picked = await showDialog<_Choice>(
    context: context,
    builder: (_) => _QuickSwitch(choices: choices),
  );
  if (picked != null && context.mounted) {
    await toggleTracking(context, picked.client, task: picked.task);
  }
}

class _QuickSwitch extends StatefulWidget {
  const _QuickSwitch({required this.choices});

  final List<_Choice> choices;

  @override
  State<_QuickSwitch> createState() => _QuickSwitchState();
}

class _QuickSwitchState extends State<_QuickSwitch> {
  final _query = TextEditingController();
  int _selected = 0;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  /// Every word of the query must appear somewhere in the label.
  List<_Choice> get _matches {
    final words = _query.text
        .toLowerCase()
        .split(' ')
        .where((w) => w.isNotEmpty);
    return [
      for (final c in widget.choices)
        if (words.every(c.label.toLowerCase().contains)) c,
    ];
  }

  void _move(int by, int count) {
    if (count == 0) return;
    setState(() => _selected = (_selected + by) % count);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final matches = _matches;
    final selected = matches.isEmpty
        ? -1
        : _selected.clamp(0, matches.length - 1);

    return Dialog(
      alignment: const Alignment(0, -0.6),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 440),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: CallbackShortcuts(
                bindings: {
                  const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
                      _move(1, matches.length),
                  const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
                      _move(-1, matches.length),
                },
                child: TextField(
                  controller: _query,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Switch to client or task…',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (_) => setState(() => _selected = 0),
                  onSubmitted: (_) {
                    if (selected >= 0) {
                      Navigator.pop(context, matches[selected]);
                    }
                  },
                ),
              ),
            ),
            Flexible(
              child: matches.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No match'),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: matches.length,
                      itemBuilder: (context, i) {
                        final m = matches[i];
                        return ListTile(
                          dense: true,
                          selected: i == selected,
                          selectedTileColor: theme.colorScheme.primary
                              .withValues(alpha: 0.1),
                          leading: CircleAvatar(
                            radius: m.task == null ? 7 : 4,
                            backgroundColor: Color(m.client.color),
                          ),
                          title: Text(m.label, overflow: TextOverflow.ellipsis),
                          trailing: m.running
                              ? const Text('running · Enter stops')
                              : null,
                          onTap: () => Navigator.pop(context, m),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Text(
                '↑↓ Enter · ${modKey}1–9 clients · $modKey. stop · '
                '${modKey}N add time',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
