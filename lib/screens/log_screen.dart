import 'package:flutter/material.dart';

import '../format.dart';
import '../models.dart';
import '../store.dart';
import '../widgets/common.dart';
import '../widgets/entry_editor.dart';
import '../widgets/live_builder.dart';
import '../widgets/task_menu.dart';

/// Entries grouped day → client → task → individual entries, with a sum at
/// every level. Clients start expanded, tasks collapsed. Tap an entry to edit.
class LogScreen extends StatefulWidget {
  const LogScreen({super.key});

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  // Static so expansion survives switching tabs during a session.
  static final _collapsedClients = <String>{};
  static final _expandedTasks = <String>{};

  void _toggle(Set<String> set, String key) => setState(() {
    if (!set.remove(key)) set.add(key);
  });

  /// Flattens the grouping into rows for a lazy ListView.
  List<_Item> _items(AppStore store) {
    final items = <_Item>[];
    final all = store.entries; // newest first
    var i = 0;
    while (i < all.length) {
      final day = dayStart(all[i].start);
      final dayEntries = <Entry>[];
      while (i < all.length && dayStart(all[i].start) == day) {
        dayEntries.add(all[i++]);
      }
      items.add(_DayItem(day, dayEntries));

      // Tasks keep newest-first order since entries arrive that way.
      final byClient = <String, Map<String, List<Entry>>>{};
      for (final e in dayEntries) {
        byClient
            .putIfAbsent(e.clientId, () => {})
            .putIfAbsent(e.note.trim(), () => [])
            .add(e);
      }
      for (final id in store.inClientOrder(byClient.keys)) {
        final client = store.clientById(id);
        final tasks = byClient[id]!;
        final clientKey = '${fmtIsoDate(day)}|$id';
        final open = !_collapsedClients.contains(clientKey);
        items.add(
          _ClientItem(clientKey, client, [
            for (final list in tasks.values) ...list,
          ], open),
        );
        if (!open) continue;
        for (final MapEntry(key: note, value: list) in tasks.entries) {
          final taskKey = '$clientKey|$note';
          final taskOpen = _expandedTasks.contains(taskKey);
          items.add(_TaskItem(taskKey, id, note, list, taskOpen));
          if (taskOpen) {
            for (final e in list) {
              items.add(_EntryItem(e));
            }
          }
        }
      }
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final items = _items(store);
    final decimal = store.decimalHours;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Log'),
        actions: [
          const Padding(
            padding: EdgeInsets.only(right: 12),
            child: HoursFormatToggle(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add time',
        onPressed: () => showEntryEditor(context),
        child: const Icon(Icons.add),
      ),
      body: items.isEmpty
          ? const Center(child: Text('No time tracked yet'))
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 88),
              itemCount: items.length,
              itemBuilder: (context, i) => switch (items[i]) {
                _DayItem item => _DayHeader(item: item, decimal: decimal),
                _ClientItem item => _ClientRow(
                  item: item,
                  decimal: decimal,
                  onTap: () => _toggle(_collapsedClients, item.key),
                ),
                _TaskItem item => _TaskRow(
                  item: item,
                  decimal: decimal,
                  onTap: () => _toggle(_expandedTasks, item.key),
                ),
                _EntryItem item => _EntryRow(
                  entry: item.entries.single,
                  decimal: decimal,
                ),
              },
            ),
    );
  }
}

// ------------------------------------------------------------------- items

sealed class _Item {
  const _Item(this.entries);

  /// Entries summed for this row.
  final List<Entry> entries;
}

class _DayItem extends _Item {
  const _DayItem(this.day, super.entries);

  final DateTime day;
}

class _ClientItem extends _Item {
  const _ClientItem(this.key, this.client, super.entries, this.open);

  final String key;
  final Client? client;
  final bool open;
}

class _TaskItem extends _Item {
  const _TaskItem(this.key, this.clientId, this.note, super.entries, this.open);

  final String key;
  final String clientId;
  final String note;
  final bool open;
}

class _EntryItem extends _Item {
  _EntryItem(Entry e) : super([e]);
}

// -------------------------------------------------------------------- rows

/// Sum of [entries], ticking while one of them is running.
class _Sum extends StatelessWidget {
  const _Sum({
    required this.entries,
    required this.decimal,
    this.style,
    this.seconds = false,
  });

  final List<Entry> entries;
  final bool decimal;
  final TextStyle? style;

  /// Show h:mm:ss while running (single entry rows).
  final bool seconds;

  @override
  Widget build(BuildContext context) {
    final running = entries.any((e) => e.isRunning);
    return LiveBuilder(
      enabled: running,
      builder: (context, now) {
        final d = entries.fold(Duration.zero, (a, e) => a + e.durationAt(now));
        final text = !decimal && running && seconds
            ? fmtClock(d)
            : fmtHours(d, decimal: decimal);
        return Text(
          text,
          style: (style ?? DefaultTextStyle.of(context).style).copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        );
      },
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.item, required this.decimal});

  final _DayItem item;
  final bool decimal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.titleSmall?.copyWith(
      color: theme.colorScheme.primary,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Row(
        children: [
          Expanded(child: Text(fmtDay(context, item.day), style: style)),
          _Sum(entries: item.entries, decimal: decimal, style: style),
        ],
      ),
    );
  }
}

class _ClientRow extends StatelessWidget {
  const _ClientRow({
    required this.item,
    required this.decimal,
    required this.onTap,
  });

  final _ClientItem item;
  final bool decimal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyLarge?.copyWith(
      fontWeight: FontWeight.w600,
    );
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
        child: Row(
          children: [
            Chevron(open: item.open),
            const SizedBox(width: 4),
            CircleAvatar(
              radius: 6,
              backgroundColor: Color(item.client?.color ?? clientPalette.last),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                item.client?.name ?? 'Unknown client',
                style: style,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _Sum(entries: item.entries, decimal: decimal, style: style),
          ],
        ),
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({
    required this.item,
    required this.decimal,
    required this.onTap,
  });

  final _TaskItem item;
  final bool decimal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final n = item.entries.length;
    final row = InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(36, 8, 16, 8),
        child: Row(
          children: [
            Chevron(open: item.open),
            const SizedBox(width: 6),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    item.note.isEmpty
                        ? TextSpan(
                            text: 'No note',
                            style: TextStyle(
                              color: muted,
                              fontStyle: FontStyle.italic,
                            ),
                          )
                        : TextSpan(text: item.note),
                    if (n > 1)
                      TextSpan(
                        text: '  ×$n',
                        style: TextStyle(color: muted),
                      ),
                  ],
                ),
                style: theme.textTheme.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            _Sum(
              entries: item.entries,
              decimal: decimal,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
    // "No note" is per-day: naming it names just this day's entries.
    return TaskMenuRegion(
      clientId: item.clientId,
      task: item.note,
      only: item.note.isEmpty ? item.entries : null,
      child: row,
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry, required this.decimal});

  final Entry entry;
  final bool decimal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final e = entry;
    final style = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontWeight: e.isRunning ? FontWeight.w600 : null,
    );
    final range =
        '${fmtTime(context, e.start)} – ${e.isRunning ? 'now' : fmtTime(context, e.end!)}';
    return InkWell(
      onTap: () => showEntryEditor(context, entry: e),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(66, 6, 16, 6),
        child: Row(
          children: [
            Expanded(child: Text(range, style: style)),
            Icon(Icons.edit_outlined, size: 14, color: style?.color),
            const SizedBox(width: 8),
            _Sum(entries: [e], decimal: decimal, style: style, seconds: true),
          ],
        ),
      ),
    );
  }
}
