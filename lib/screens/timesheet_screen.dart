import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../format.dart';
import '../models.dart';
import '../store.dart';
import '../widgets/dialogs.dart';
import '../widgets/live_builder.dart';

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

const _dayW = 68.0;
const _totalW = 76.0;
const _minNameW = 150.0;
const _rowH = 40.0;
const _taskRowH = 34.0;

/// Week grid: clients (expandable to tasks) down the side, Mon–Sun across the
/// top, hours in the cells. Hover or tap a cell for that day's task notes.
class TimesheetScreen extends StatefulWidget {
  const TimesheetScreen({super.key});

  @override
  State<TimesheetScreen> createState() => _TimesheetScreenState();
}

class _TimesheetScreenState extends State<TimesheetScreen> {
  // Static so the week and expansion survive switching tabs.
  static DateTime? _week;
  static final _expanded = <String>{};

  DateTime get _from => _week ??= weekStart(DateTime.now());

  void _shift(int weeks) => setState(() => _week = addDays(_from, 7 * weeks));

  void _copy(_Sheet sheet) {
    final b = StringBuffer();
    String row(String client, String task, List<Duration> days, Duration t) =>
        [client, task, ...days.map(_dec), _dec(t)].join('\t');
    b.writeln(
      [
        'Client',
        'Task',
        for (var i = 0; i < 7; i++)
          '${_weekdays[i]} ${fmtIsoDate(addDays(sheet.from, i))}',
        'Total',
      ].join('\t'),
    );
    for (final c in sheet.rows) {
      b.writeln(row(c.name, '', c.days, c.total));
      for (final t in c.tasks) {
        b.writeln(row(c.name, t.label, t.days, t.total));
      }
    }
    b.writeln(row('Total', '', sheet.dayTotals, sheet.total));
    Clipboard.setData(ClipboardData(text: b.toString()));
    toast(context, 'Copied week — paste into a spreadsheet');
  }

  static String _dec(Duration d) => d == Duration.zero ? '' : fmtDecimal(d);

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final theme = Theme.of(context);
    final from = _from;
    final to = addDays(from, 7);
    final running = store.running;
    final live =
        running != null &&
        !running.start.isBefore(from) &&
        running.start.isBefore(to);
    final loc = MaterialLocalizations.of(context);
    final isCurrent = from == weekStart(DateTime.now());
    final allOpen = store.clients.every((c) => _expanded.contains(c.id));

    return LiveBuilder(
      enabled: live,
      interval: const Duration(seconds: 30),
      builder: (context, now) {
        final sheet = _Sheet.build(store, from, now, store.rounding);
        return Scaffold(
          appBar: AppBar(
            title: const Text('Timesheet'),
            actions: [
              IconButton(
                tooltip: allOpen ? 'Collapse all' : 'Expand all',
                onPressed: () => setState(() {
                  if (allOpen) {
                    _expanded.clear();
                  } else {
                    _expanded.addAll(store.clients.map((c) => c.id));
                  }
                }),
                icon: Icon(allOpen ? Icons.unfold_less : Icons.unfold_more),
              ),
              IconButton(
                tooltip: 'Copy week for a spreadsheet',
                onPressed: sheet.rows.isEmpty ? null : () => _copy(sheet),
                icon: const Icon(Icons.content_copy),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 4, right: 12),
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('h:mm')),
                    ButtonSegment(value: true, label: Text('Decimal')),
                  ],
                  selected: {store.decimalHours},
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                  ),
                  onSelectionChanged: (s) => store.setDecimalHours(s.first),
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Previous week',
                      onPressed: () => _shift(-1),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Expanded(
                      child: Text(
                        '${loc.formatShortMonthDay(from)} – '
                        '${loc.formatShortMonthDay(addDays(to, -1))}, '
                        '${addDays(to, -1).year}',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    if (!isCurrent)
                      TextButton(
                        onPressed: () =>
                            setState(() => _week = weekStart(DateTime.now())),
                        child: const Text('This week'),
                      ),
                    IconButton(
                      tooltip: 'Next week',
                      onPressed: () => _shift(1),
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Round up to ½ h',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    SegmentedButton<Rounding>(
                      segments: const [
                        ButtonSegment(
                          value: Rounding.off,
                          label: Text('Off'),
                          tooltip: 'Exact time',
                        ),
                        ButtonSegment(
                          value: Rounding.task,
                          label: Text('Per task'),
                          tooltip:
                              'Each task\'s time on a day rounds up '
                              'separately; clients and days add those up',
                        ),
                        ButtonSegment(
                          value: Rounding.day,
                          label: Text('Per day'),
                          tooltip:
                              'Each client\'s total for a day rounds up; '
                              'task rows stay exact',
                        ),
                      ],
                      selected: {store.rounding},
                      showSelectedIcon: false,
                      style: const ButtonStyle(
                        visualDensity: VisualDensity.compact,
                      ),
                      onSelectionChanged: (s) => store.setRounding(s.first),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: sheet.rows.isEmpty
                    ? const Center(child: Text('No time this week'))
                    : _Grid(
                        sheet: sheet,
                        decimal: store.decimalHours,
                        expanded: _expanded,
                        onToggle: (id) => setState(() {
                          if (!_expanded.remove(id)) _expanded.add(id);
                        }),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// -------------------------------------------------------------------- data

class _TaskLine {
  _TaskLine(this.note);

  final String note;
  final entries = List.generate(7, (_) => <Entry>[]);

  /// Actual time per day.
  final raw = List.filled(7, Duration.zero);

  /// Time per day as shown/billed (rounded when rounding by task).
  late final List<Duration> days;

  String get label => note.isEmpty ? 'No note' : note;
  Duration get total => days.fold(Duration.zero, (a, b) => a + b);
}

class _ClientLine {
  _ClientLine(this.id, this.client);

  final String id;
  final Client? client;
  final raw = List.filled(7, Duration.zero);
  late final List<Duration> days;
  final _tasks = <String, _TaskLine>{};
  late final List<_TaskLine> tasks;

  String get name => client?.name ?? 'Unknown client';
  Duration get total => days.fold(Duration.zero, (a, b) => a + b);

  _TaskLine task(String note) =>
      _tasks.putIfAbsent(note, () => _TaskLine(note));
}

class _Sheet {
  _Sheet(this.from, this.rows)
    : dayTotals = List.generate(
        7,
        (i) => rows.fold(Duration.zero, (a, r) => a + r.days[i]),
      );

  final DateTime from;
  final List<_ClientLine> rows;
  final List<Duration> dayTotals;

  Duration get total => dayTotals.fold(Duration.zero, (a, b) => a + b);

  factory _Sheet.build(
    AppStore store,
    DateTime from,
    DateTime now,
    Rounding rounding,
  ) {
    final byClient = <String, _ClientLine>{};
    // Oldest first so tooltip entries read chronologically.
    final entries = store.entriesIn(from, addDays(from, 7)).toList().reversed;
    for (final e in entries) {
      // Round: DST days aren't exactly 24h.
      final day = (dayStart(e.start).difference(from).inHours / 24).round();
      final d = e.durationAt(now);
      final line = byClient.putIfAbsent(
        e.clientId,
        () => _ClientLine(e.clientId, store.clientById(e.clientId)),
      );
      final task = line.task(e.note.trim());
      line.raw[day] += d;
      task.raw[day] += d;
      task.entries[day].add(e);
    }
    final order = {
      for (var i = 0; i < store.clients.length; i++) store.clients[i].id: i,
    };
    final rows = byClient.values.toList()
      ..sort(
        (a, b) => (order[a.id] ?? order.length).compareTo(
          order[b.id] ?? order.length,
        ),
      );
    for (final r in rows) {
      for (final t in r._tasks.values) {
        t.days = rounding == Rounding.task
            ? t.raw.map(roundUpHalfHour).toList()
            : t.raw;
      }
      r.tasks = r._tasks.values.toList()
        ..sort((a, b) => b.total.compareTo(a.total));
      r.days = List.generate(
        7,
        (i) => switch (rounding) {
          Rounding.off => r.raw[i],
          // Client cell = sum of its rounded task cells.
          Rounding.task => r.tasks.fold(Duration.zero, (a, t) => a + t.days[i]),
          Rounding.day => roundUpHalfHour(r.raw[i]),
        },
      );
    }
    return _Sheet(from, rows);
  }
}

// -------------------------------------------------------------------- grid

class _Grid extends StatelessWidget {
  const _Grid({
    required this.sheet,
    required this.decimal,
    required this.expanded,
    required this.onToggle,
  });

  final _Sheet sheet;
  final bool decimal;
  final Set<String> expanded;
  final ValueChanged<String> onToggle;

  String _fmt(Duration d) =>
      d == Duration.zero ? '' : (decimal ? fmtDecimal(d) : fmtHm(d));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final loc = MaterialLocalizations.of(context);
    final today = dayStart(DateTime.now());
    final todayCol = (today.difference(sheet.from).inHours / 24).round();
    final numStyle = theme.textTheme.bodyMedium?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final bold = numStyle?.copyWith(fontWeight: FontWeight.w600);
    final muted = numStyle?.copyWith(color: scheme.onSurfaceVariant);
    final tipStyle = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onInverseSurface,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        const fixed = 7 * _dayW + _totalW + 16;
        final nameW = (constraints.maxWidth - fixed).clamp(_minNameW, 320.0);
        final width = nameW + fixed;

        Color? colBg(int i) =>
            i == todayCol ? scheme.primary.withValues(alpha: 0.07) : null;

        Widget cell(
          String text, {
          required double width,
          required double height,
          TextStyle? style,
          Color? bg,
          InlineSpan? tip,
        }) {
          Widget c = Container(
            width: width,
            height: height,
            color: bg,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(text, style: style),
          );
          if (tip != null && text.isNotEmpty) {
            c = Tooltip(
              richMessage: tip,
              textStyle: tipStyle,
              triggerMode: TooltipTriggerMode.tap,
              waitDuration: const Duration(milliseconds: 250),
              showDuration: const Duration(seconds: 6),
              child: c,
            );
          }
          return c;
        }

        TextSpan heading(String a, String b) => TextSpan(
          children: [
            TextSpan(
              text: '$a\n',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: b),
          ],
        );

        String dayName(int i) =>
            '${_weekdays[i]} ${loc.formatShortMonthDay(addDays(sheet.from, i))}';

        // Client cell: that day's tasks with hours.
        String actual(Duration shown, Duration raw) =>
            shown == raw ? '' : '  (actual ${_fmt(raw)})';

        InlineSpan clientTip(_ClientLine c, int i) => TextSpan(
          children: [
            heading(c.name, dayName(i)),
            for (final t in c.tasks)
              if (t.raw[i] > Duration.zero)
                TextSpan(
                  text:
                      '\n${_fmt(t.days[i]).padLeft(5)}  ${t.label}'
                      '${actual(t.days[i], t.raw[i])}',
                ),
            if (c.days[i] !=
                c.tasks.fold(Duration.zero, (a, t) => a + t.days[i]))
              TextSpan(
                text:
                    '\nDay rounded up to ${_fmt(c.days[i])}'
                    '${actual(c.days[i], c.raw[i])}',
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
          ],
        );

        // Task cell: the individual time blocks.
        InlineSpan taskTip(_ClientLine c, _TaskLine t, int i) => TextSpan(
          children: [
            heading('${c.name} · ${t.label}', dayName(i)),
            if (t.days[i] != t.raw[i])
              TextSpan(
                text:
                    '\nRounded up to ${_fmt(t.days[i])}'
                    '${actual(t.days[i], t.raw[i])}',
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
            for (final e in t.entries[i])
              TextSpan(
                text:
                    '\n${fmtTime(context, e.start)} – '
                    '${e.isRunning ? 'now' : fmtTime(context, e.end!)}'
                    '   ${_fmt(e.durationAt(DateTime.now()))}',
              ),
          ],
        );

        final header = Container(
          height: 48,
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
          ),
          child: Row(
            children: [
              SizedBox(width: nameW + 16),
              for (var i = 0; i < 7; i++)
                Container(
                  width: _dayW,
                  color: colBg(i),
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${_weekdays[i]}\n',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: i == todayCol
                                ? scheme.primary
                                : i >= 5
                                ? scheme.onSurfaceVariant
                                : null,
                          ),
                        ),
                        TextSpan(
                          text:
                              '${addDays(sheet.from, i).month}/'
                              '${addDays(sheet.from, i).day}',
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.right,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              Container(
                width: _totalW,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  'Total',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );

        final rows = <Widget>[];
        for (final c in sheet.rows) {
          final open = expanded.contains(c.id);
          rows.add(
            InkWell(
              onTap: () => onToggle(c.id),
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: scheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: nameW + 16,
                      height: _rowH,
                      child: Row(
                        children: [
                          const SizedBox(width: 8),
                          AnimatedRotation(
                            turns: open ? 0.25 : 0,
                            duration: const Duration(milliseconds: 120),
                            child: Icon(
                              Icons.chevron_right,
                              size: 20,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 4),
                          CircleAvatar(
                            radius: 6,
                            backgroundColor: Color(
                              c.client?.color ?? clientPalette.last,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              c.name,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    for (var i = 0; i < 7; i++)
                      cell(
                        _fmt(c.days[i]),
                        width: _dayW,
                        height: _rowH,
                        style: numStyle,
                        bg: colBg(i),
                        tip: clientTip(c, i),
                      ),
                    cell(
                      _fmt(c.total),
                      width: _totalW,
                      height: _rowH,
                      style: bold,
                    ),
                  ],
                ),
              ),
            ),
          );
          if (!open) continue;
          for (final t in c.tasks) {
            rows.add(
              Row(
                children: [
                  Container(
                    width: nameW + 16,
                    height: _taskRowH,
                    padding: const EdgeInsets.only(left: 56, right: 8),
                    alignment: Alignment.centerLeft,
                    child: Text(
                      t.label,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontStyle: t.note.isEmpty ? FontStyle.italic : null,
                      ),
                    ),
                  ),
                  for (var i = 0; i < 7; i++)
                    cell(
                      _fmt(t.days[i]),
                      width: _dayW,
                      height: _taskRowH,
                      style: muted,
                      bg: colBg(i),
                      tip: taskTip(c, t, i),
                    ),
                  cell(
                    _fmt(t.total),
                    width: _totalW,
                    height: _taskRowH,
                    style: muted,
                  ),
                ],
              ),
            );
          }
        }

        final footer = Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: scheme.outline, width: 1.5)),
          ),
          child: Row(
            children: [
              Container(
                width: nameW + 16,
                height: _rowH,
                padding: const EdgeInsets.only(left: 16),
                alignment: Alignment.centerLeft,
                child: Text('Total', style: theme.textTheme.titleSmall),
              ),
              for (var i = 0; i < 7; i++)
                cell(
                  _fmt(sheet.dayTotals[i]),
                  width: _dayW,
                  height: _rowH,
                  style: bold,
                  bg: colBg(i),
                ),
              cell(
                _fmt(sheet.total),
                width: _totalW,
                height: _rowH,
                style: bold?.copyWith(color: scheme.primary),
              ),
            ],
          ),
        );

        final table = SizedBox(
          width: width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              header,
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 8),
                  children: [...rows, footer],
                ),
              ),
            ],
          ),
        );

        // Narrow screens scroll sideways; the week stays one table.
        return width <= constraints.maxWidth
            ? Align(alignment: Alignment.topLeft, child: table)
            : Scrollbar(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: table,
                ),
              );
      },
    );
  }
}
