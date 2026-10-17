import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../format.dart';
import '../models.dart';
import '../store.dart';
import '../widgets/common.dart';
import '../widgets/dialogs.dart';
import '../widgets/live_builder.dart';

const _dayW = 68.0;
const _totalW = 76.0;
const _minNameW = 150.0;

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

  void _copy(_Sheet sheet) {
    final b = StringBuffer();
    String row(String client, String task, List<Duration> days, Duration t) =>
        [client, task, ...days.map(_dec), _dec(t)].join('\t');
    b.writeln(
      [
        'Client',
        'Task',
        for (var i = 0; i < 7; i++)
          '${fmtWeekday(context, addDays(sheet.from, i))} '
              '${fmtIsoDate(addDays(sheet.from, i))}',
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
    final allOpen = store.clients.every((c) => _expanded.contains(c.id));

    return LiveBuilder(
      enabled: live,
      interval: const Duration(seconds: 30),
      builder: (context, now) {
        final sheet = _Sheet.build(
          store,
          from,
          now,
          store.rounding,
          store.roundingMinutes,
        );
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
              const SizedBox(width: 8),
            ],
          ),
          body: Column(
            children: [
              WeekBar(
                from: from,
                thisWeek: weekStart(DateTime.now()),
                onChanged: (w) => setState(() => _week = w),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Round up to',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 8),
                        DropdownButton<int>(
                          value: store.roundingMinutes,
                          underline: const SizedBox(),
                          items: [
                            for (final m in roundingSteps)
                              DropdownMenuItem(value: m, child: Text('$m min')),
                          ],
                          onChanged: (m) => store.setRoundingMinutes(m!),
                        ),
                      ],
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
                      onSelectionChanged: (s) => store.setRounding(s.first),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: sheet.rows.isEmpty
                    ? const Center(child: Text('Nothing tracked this week'))
                    : _Grid(
                        sheet: sheet,
                        now: now,
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
    int minutes,
  ) {
    final byClient = <String, _ClientLine>{};
    // Oldest first so tooltip entries read chronologically.
    final entries = store.entriesIn(from, addDays(from, 7)).toList().reversed;
    for (final e in entries) {
      final day = daysBetween(from, e.start);
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
    final rows = [
      for (final id in store.inClientOrder(byClient.keys)) byClient[id]!,
    ];
    for (final r in rows) {
      for (final t in r._tasks.values) {
        t.days = rounding == Rounding.task
            ? [for (final d in t.raw) roundUp(d, minutes)]
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
          Rounding.day => roundUp(r.raw[i], minutes),
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
    required this.now,
    required this.decimal,
    required this.expanded,
    required this.onToggle,
  });

  final _Sheet sheet;
  final DateTime now;
  final bool decimal;
  final Set<String> expanded;
  final ValueChanged<String> onToggle;

  String _fmt(Duration d) =>
      d == Duration.zero ? '' : fmtHours(d, decimal: decimal);

  String _dayName(BuildContext context, int i) => MaterialLocalizations.of(
    context,
  ).formatMediumDate(addDays(sheet.from, i));

  String _actual(Duration shown, Duration raw) =>
      shown == raw ? '' : '  (actual ${_fmt(raw)})';

  static TextSpan _heading(String title, String subtitle) => TextSpan(
    children: [
      TextSpan(
        text: '$title\n',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      TextSpan(text: subtitle),
    ],
  );

  /// Client cell: that day's tasks with hours.
  InlineSpan _clientTip(BuildContext context, _ClientLine c, int i) => TextSpan(
    children: [
      _heading(c.name, _dayName(context, i)),
      for (final t in c.tasks)
        if (t.raw[i] > Duration.zero)
          TextSpan(
            text:
                '\n${_fmt(t.days[i]).padLeft(5)}  ${t.label}'
                '${_actual(t.days[i], t.raw[i])}',
          ),
      if (c.days[i] != c.tasks.fold(Duration.zero, (a, t) => a + t.days[i]))
        TextSpan(
          text:
              '\nDay rounded up to ${_fmt(c.days[i])}'
              '${_actual(c.days[i], c.raw[i])}',
          style: const TextStyle(fontStyle: FontStyle.italic),
        ),
    ],
  );

  /// Task cell: the individual time blocks.
  InlineSpan _taskTip(
    BuildContext context,
    _ClientLine c,
    _TaskLine t,
    int i,
  ) => TextSpan(
    children: [
      _heading('${c.name} · ${t.label}', _dayName(context, i)),
      if (t.days[i] != t.raw[i])
        TextSpan(
          text:
              '\nRounded up to ${_fmt(t.days[i])}'
              '${_actual(t.days[i], t.raw[i])}',
          style: const TextStyle(fontStyle: FontStyle.italic),
        ),
      for (final e in t.entries[i])
        TextSpan(
          text:
              '\n${fmtTime(context, e.start)} – '
              '${e.isRunning ? 'now' : fmtTime(context, e.end!)}'
              '   ${_fmt(e.durationAt(now))}',
        ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final todayCol = daysBetween(sheet.from, DateTime.now());
    // Cells are targets: 48px on touch, less with desktop density.
    final rowH = 48 + theme.visualDensity.vertical * 4;
    final numStyle = timeStyle(context, theme.textTheme.bodyMedium);
    final bold = numStyle.copyWith(fontWeight: FontWeight.w600);
    final muted = numStyle.copyWith(color: scheme.onSurfaceVariant);
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
          required String where,
        }) {
          final c = Container(
            width: width,
            height: height,
            color: bg,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(text, style: style),
          );
          if (text.isEmpty) return c;
          if (tip == null) {
            return Semantics(
              container: true,
              label: '$where, $text',
              excludeSemantics: true,
              child: c,
            );
          }
          return _TipCell(tip: tip, tipStyle: tipStyle, value: text, child: c);
        }

        /// One grid row: label, Mon–Sun cells, week total.
        Widget cells({
          required Widget label,
          required String name,
          required double height,
          required List<Duration> days,
          required Duration total,
          TextStyle? style,
          TextStyle? totalStyle,
          InlineSpan Function(int day)? tip,
        }) => Row(
          children: [
            SizedBox(width: nameW + 16, height: height, child: label),
            for (var i = 0; i < 7; i++)
              cell(
                _fmt(days[i]),
                width: _dayW,
                height: height,
                style: style,
                bg: colBg(i),
                tip: tip?.call(i),
                where: '$name, ${_dayName(context, i)}',
              ),
            cell(
              _fmt(total),
              width: _totalW,
              height: height,
              style: totalStyle ?? style,
              where: '$name, week total',
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
                          text:
                              '${fmtWeekday(context, addDays(sheet.from, i))}\n',
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
                          text: MaterialLocalizations.of(
                            context,
                          ).formatShortMonthDay(addDays(sheet.from, i)),
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

        final rows = <Widget>[
          for (final c in sheet.rows) ...[
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: scheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
              ),
              child: cells(
                name: c.name,
                height: rowH,
                days: c.days,
                total: c.total,
                style: numStyle,
                totalStyle: bold,
                tip: (i) => _clientTip(context, c, i),
                // The name toggles the row; the cells show their tasks.
                label: MergeSemantics(
                  child: Semantics(
                    expanded: expanded.contains(c.id),
                    child: InkWell(
                      onTap: () => onToggle(c.id),
                      child: Row(
                        children: [
                          const SizedBox(width: 8),
                          Chevron(open: expanded.contains(c.id)),
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
                  ),
                ),
              ),
            ),
            if (expanded.contains(c.id))
              for (final t in c.tasks)
                cells(
                  name: '${c.name}, ${t.label}',
                  height: rowH,
                  days: t.days,
                  total: t.total,
                  style: muted,
                  tip: (i) => _taskTip(context, c, t, i),
                  label: Padding(
                    padding: const EdgeInsets.only(left: 56, right: 8),
                    child: Align(
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
                  ),
                ),
          ],
        ];

        final footer = DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: scheme.outline, width: 1.5)),
          ),
          child: cells(
            name: 'Total',
            height: rowH,
            days: sheet.dayTotals,
            total: sheet.total,
            style: bold,
            totalStyle: bold.copyWith(color: scheme.primary),
            label: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Total', style: theme.textTheme.titleSmall),
              ),
            ),
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

/// A day cell with a breakdown: hovering shows it, and so does tapping or
/// Enter (the cell takes focus). Screen readers get the value and the
/// breakdown as one label.
class _TipCell extends StatefulWidget {
  const _TipCell({
    required this.tip,
    required this.tipStyle,
    required this.value,
    required this.child,
  });

  final InlineSpan tip;
  final TextStyle? tipStyle;
  final String value;
  final Widget child;

  @override
  State<_TipCell> createState() => _TipCellState();
}

class _TipCellState extends State<_TipCell> {
  final _tooltip = GlobalKey<TooltipState>();

  void _show() => _tooltip.currentState?.ensureTooltipVisible();

  @override
  Widget build(BuildContext context) {
    final detail = widget.tip
        .toPlainText()
        .split('\n')
        .map((l) => l.trim().replaceAll(RegExp(r'\s+'), ' '))
        .join(', ');
    return Semantics(
      container: true,
      label: '${widget.value}, $detail',
      button: true,
      onTap: _show,
      excludeSemantics: true,
      child: Tooltip(
        key: _tooltip,
        richMessage: widget.tip,
        textStyle: widget.tipStyle,
        triggerMode: TooltipTriggerMode.manual,
        excludeFromSemantics: true,
        waitDuration: const Duration(milliseconds: 250),
        showDuration: const Duration(seconds: 6),
        child: InkWell(onTap: _show, child: widget.child),
      ),
    );
  }
}
