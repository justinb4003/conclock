import 'package:flutter/material.dart';

import '../format.dart';
import '../models.dart';
import '../store.dart';
import '../widgets/common.dart';
import '../widgets/entry_editor.dart';
import '../widgets/live_builder.dart';
import '../widgets/task_menu.dart';

/// One week's entries, grouped day → client → task → entries, or client →
/// day → task → entries, with a sum at every level. Second-level rows start
/// expanded, tasks collapsed; the unfold buttons collapse a group (or all
/// of them). Tap an entry to edit. The week bar at the top and the buttons
/// at the bottom move a week at a time.
class LogScreen extends StatefulWidget {
  const LogScreen({super.key});

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  // Static so the week, grouping and expansion survive switching tabs.
  static DateTime? _week;
  static var _byClient = false;

  /// Collapsed second-level rows and expanded tasks, keyed by day and
  /// client, so they hold in either grouping.
  static final _collapsed = <String>{};
  static final _expandedTasks = <String>{};

  void _toggle(Set<String> set, String key) => setState(() {
    if (!set.remove(key)) set.add(key);
  });

  void _goTo(DateTime week) => setState(() => _week = week);

  /// Flattens the week's grouping into rows for a lazy ListView.
  List<_Item> _items(AppStore store, DateTime from) {
    final week = store.entriesIn(from, addDays(from, 7)).toList();
    // Entries come newest first; days and tasks keep that order.
    final days = {for (final e in week) dayStart(e.start)}.toList();
    final clients = store.inClientOrder({for (final e in week) e.clientId});
    final items = <_Item>[];
    for (final top in _byClient ? clients : days) {
      bool inTop(Entry e) =>
          _byClient ? e.clientId == top : dayStart(e.start) == top;
      final topEntries = week.where(inTop).toList();
      final group = _byClient
          ? _GroupItem(topEntries, client: store.clientById(top as String))
          : _GroupItem(topEntries, day: top as DateTime);
      items.add(group);
      final subs = _byClient
          ? {for (final e in topEntries) dayStart(e.start)}.toList()
          : store.inClientOrder({for (final e in topEntries) e.clientId});
      for (final sub in subs) {
        final day = _byClient ? sub as DateTime : top as DateTime;
        final clientId = _byClient ? top as String : sub as String;
        final entries = [
          for (final e in topEntries)
            if (e.clientId == clientId && dayStart(e.start) == day) e,
        ];
        final key = '${fmtIsoDate(day)}|$clientId';
        final open = !_collapsed.contains(key);
        group.subKeys.add(key);
        if (open) group.open = true;
        items.add(
          _byClient
              ? _SubItem(key, entries, open, day: day)
              : _SubItem(
                  key,
                  entries,
                  open,
                  client: store.clientById(clientId),
                ),
        );
        if (!open) continue;
        final tasks = <String, List<Entry>>{};
        for (final e in entries) {
          tasks.putIfAbsent(e.note.trim(), () => []).add(e);
        }
        for (final MapEntry(key: note, value: list) in tasks.entries) {
          final taskKey = '$key|$note';
          final taskOpen = _expandedTasks.contains(taskKey);
          items.add(_TaskItem(taskKey, clientId, note, list, taskOpen));
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

  /// Collapses [groups] to their second-level rows, or expands them if none
  /// is open.
  void _toggleGroups(Iterable<_GroupItem> groups) => setState(() {
    final keys = [for (final g in groups) ...g.subKeys];
    if (groups.any((g) => g.open)) {
      _collapsed.addAll(keys);
    } else {
      _collapsed.removeAll(keys);
    }
  });

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final theme = Theme.of(context);
    final thisWeek = weekStart(store.now());
    final from = _week ?? thisWeek;
    final items = _items(store, from);
    final decimal = store.decimalHours;
    final groups = items.whereType<_GroupItem>();
    final anyOpen = groups.any((g) => g.open);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Log'),
        actions: [
          if (groups.isNotEmpty)
            IconButton(
              tooltip: anyOpen ? 'Collapse all' : 'Expand all',
              onPressed: () => _toggleGroups(groups),
              icon: Icon(anyOpen ? Icons.unfold_less : Icons.unfold_more),
            ),
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
      body: Column(
        children: [
          WeekBar(from: from, thisWeek: thisWeek, onChanged: _goTo),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Wrap(
              spacing: 12,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Group by',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Day')),
                    ButtonSegment(value: true, label: Text('Client')),
                  ],
                  selected: {_byClient},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) =>
                      setState(() => _byClient = s.first),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              // A new week or grouping starts at the top.
              key: ValueKey((from, _byClient)),
              padding: const EdgeInsets.only(bottom: 88),
              itemCount: items.length + 1,
              itemBuilder: (context, i) => i == items.length
                  ? _WeekFooter(
                      empty: items.isEmpty,
                      onShift: (weeks) => _goTo(addDays(from, 7 * weeks)),
                    )
                  : switch (items[i]) {
                      _GroupItem item => _GroupHeader(
                        item: item,
                        decimal: decimal,
                        onToggle: () => _toggleGroups([item]),
                      ),
                      _SubItem item => _SubRow(
                        item: item,
                        decimal: decimal,
                        onTap: () => _toggle(_collapsed, item.key),
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
          ),
        ],
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

/// A day, or a client when grouping by client.
class _GroupItem extends _Item {
  _GroupItem(super.entries, {this.day, this.client});

  final DateTime? day;
  final Client? client;
  final subKeys = <String>[];

  /// Any of its rows expanded.
  bool open = false;
}

/// A client within a day, or a day within a client.
class _SubItem extends _Item {
  const _SubItem(this.key, super.entries, this.open, {this.day, this.client});

  final String key;
  final DateTime? day;
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

/// The column at the end of each row for its button (rename on tasks),
/// kept on every row so the sums line up.
const _actionW = 48.0;

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
          style: timeStyle(
            context,
            style ?? DefaultTextStyle.of(context).style,
          ),
        );
      },
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.item,
    required this.decimal,
    required this.onToggle,
  });

  final _GroupItem item;
  final bool decimal;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.titleSmall?.copyWith(
      color: theme.colorScheme.primary,
    );
    final client = item.client;
    final what = item.day == null ? 'client' : 'day';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 4, 0),
      child: Row(
        children: [
          if (item.day == null) ...[
            CircleAvatar(
              radius: 6,
              backgroundColor: Color(client?.color ?? clientPalette.last),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              item.day == null
                  ? client?.name ?? 'Unknown client'
                  : MaterialLocalizations.of(context).formatFullDate(item.day!),
              style: style,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Semantics(
            expanded: item.open,
            child: IconButton(
              tooltip: item.open ? 'Collapse $what' : 'Expand $what',
              onPressed: onToggle,
              iconSize: 18,
              color: theme.colorScheme.onSurfaceVariant,
              icon: Icon(item.open ? Icons.unfold_less : Icons.unfold_more),
            ),
          ),
          const Spacer(),
          _Sum(entries: item.entries, decimal: decimal, style: style),
          const SizedBox(width: _actionW),
        ],
      ),
    );
  }
}

class _SubRow extends StatelessWidget {
  const _SubRow({
    required this.item,
    required this.decimal,
    required this.onTap,
  });

  final _SubItem item;
  final bool decimal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyLarge?.copyWith(
      fontWeight: FontWeight.w600,
    );
    final day = item.day;
    final label = day == null
        ? item.client?.name ?? 'Unknown client'
        : MaterialLocalizations.of(context).formatMediumDate(day);
    return MergeSemantics(
      child: Semantics(
        expanded: item.open,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
            child: Row(
              children: [
                Chevron(open: item.open),
                const SizedBox(width: 4),
                if (day == null) ...[
                  CircleAvatar(
                    radius: 6,
                    backgroundColor: Color(
                      item.client?.color ?? clientPalette.last,
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(
                    label,
                    style: style,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _Sum(entries: item.entries, decimal: decimal, style: style),
                const SizedBox(width: _actionW),
              ],
            ),
          ),
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
    final row = Semantics(
      expanded: item.open,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(36, 8, 0, 8),
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
      ),
    );
    // "No note" is per-day: naming it names just this day's entries.
    final only = item.note.isEmpty ? item.entries : null;
    return Row(
      children: [
        // One node for screen readers: the name, the total, tap and
        // long-press.
        Expanded(
          child: MergeSemantics(
            child: TaskMenuRegion(
              clientId: item.clientId,
              task: item.note,
              only: only,
              child: row,
            ),
          ),
        ),
        SizedBox(
          width: _actionW,
          child: TaskRenameButton(
            clientId: item.clientId,
            task: item.note,
            only: only,
          ),
        ),
        const SizedBox(width: 4),
      ],
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
        padding: const EdgeInsets.fromLTRB(66, 6, 4, 6),
        child: Row(
          children: [
            Expanded(child: Text(range, style: timeStyle(context, style))),
            _Sum(entries: [e], decimal: decimal, style: style, seconds: true),
            SizedBox(
              width: _actionW,
              child: Icon(Icons.edit_outlined, size: 18, color: style?.color),
            ),
          ],
        ),
      ),
    );
  }
}

/// End of the list: nothing this week, or not, and the way to the weeks
/// either side without scrolling back up.
class _WeekFooter extends StatelessWidget {
  const _WeekFooter({required this.empty, required this.onShift});

  final bool empty;

  /// Moves by this many weeks.
  final ValueChanged<int> onShift;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        children: [
          if (empty) ...[
            Text(
              'Nothing tracked this week',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
          ],
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => onShift(-1),
                icon: const Icon(Icons.chevron_left),
                label: const Text('Previous week'),
              ),
              OutlinedButton.icon(
                onPressed: () => onShift(1),
                icon: const Icon(Icons.chevron_right),
                iconAlignment: IconAlignment.end,
                label: const Text('Next week'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
