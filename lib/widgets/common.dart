import 'package:flutter/material.dart';

import '../format.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';

/// h:mm / Decimal switch for an app bar; the setting is shared app-wide.
/// On a phone, where the app bar has no room for both choices, one button
/// shows a sample of the current format and switches it.
class HoursFormatToggle extends StatelessWidget {
  const HoursFormatToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final decimal = store.decimalHours;
    final Widget toggle;
    if (MediaQuery.sizeOf(context).width < 600) {
      toggle = Tooltip(
        message: decimal
            ? 'Decimal hours; switch to hours and minutes'
            : 'Hours and minutes; switch to decimal hours',
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.onSurface,
          ),
          onPressed: () => store.setDecimalHours(!decimal),
          child: Text(decimal ? '1.50' : '1:30'),
        ),
      );
    } else {
      toggle = SegmentedButton<bool>(
        segments: const [
          ButtonSegment(value: false, label: Text('h:mm')),
          ButtonSegment(value: true, label: Text('Decimal')),
        ],
        selected: {decimal},
        showSelectedIcon: false,
        onSelectionChanged: (s) => store.setDecimalHours(s.first),
      );
    }
    return Padding(padding: const EdgeInsets.only(right: 4), child: toggle);
  }
}

/// Expand/collapse indicator: points right when closed, down when open.
class Chevron extends StatelessWidget {
  const Chevron({super.key, required this.open});

  final bool open;

  @override
  Widget build(BuildContext context) => AnimatedRotation(
    turns: open ? 0.25 : 0,
    duration: const Duration(milliseconds: 120),
    child: Icon(
      Icons.chevron_right,
      size: 20,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
}

/// Font for times when Settings → "Monospace times" is on (bundled asset).
const monoFont = 'IBM Plex Mono';

/// [base] for a time or duration: digits all the same width, and the
/// monospace font when that setting is on.
TextStyle timeStyle(BuildContext context, [TextStyle? base]) {
  final mono = StoreScope.of(context).monoTimes;
  return (base ?? const TextStyle()).copyWith(
    fontFamily: mono ? monoFont : null,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}

/// A time or duration inside running text, e.g. 'Today ' + timeSpan(…).
TextSpan timeSpan(BuildContext context, String text) =>
    TextSpan(text: text, style: timeStyle(context));

/// "‹ Oct 12 – Oct 18, 2026 [This week] ›" for screens showing one week.
/// Tapping the dates picks any day and goes to its week.
class WeekBar extends StatelessWidget {
  const WeekBar({
    super.key,
    required this.from,
    required this.thisWeek,
    required this.onChanged,
  });

  /// Monday of the week shown, and of the current week.
  final DateTime from;
  final DateTime thisWeek;

  /// Called with the Monday to show.
  final ValueChanged<DateTime> onChanged;

  Future<void> _pick(BuildContext context) async {
    final d = await showDatePicker(
      context: context,
      helpText: 'Go to the week of',
      initialDate: from,
      firstDate: DateTime(2000),
      lastDate: addDays(thisWeek, 365),
    );
    if (d != null) onChanged(weekStart(d));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = MaterialLocalizations.of(context);
    final last = addDays(from, 6);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Previous week',
            onPressed: () => onChanged(addDays(from, -7)),
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: TextButton(
              onPressed: () => _pick(context),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.onSurface,
                textStyle: theme.textTheme.titleMedium,
              ),
              child: Text(
                '${loc.formatShortMonthDay(from)} – '
                '${loc.formatShortMonthDay(last)}, ${last.year}',
                textAlign: TextAlign.center,
              ),
            ),
          ),
          if (from != thisWeek)
            TextButton(
              onPressed: () => onChanged(thisWeek),
              child: const Text('This week'),
            ),
          IconButton(
            tooltip: 'Next week',
            onPressed: () => onChanged(addDays(from, 7)),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

/// One palette color to pick: a 48px target, named in its tooltip (for
/// screen readers, and for anyone who can't tell the colors apart).
class ColorChoice extends StatelessWidget {
  const ColorChoice({
    super.key,
    required this.color,
    required this.selected,
    required this.onTap,
    this.radius = 16,
  });

  final int color;
  final bool selected;
  final VoidCallback onTap;
  final double radius;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    inMutuallyExclusiveGroup: true,
    child: Tooltip(
      message: colorName(color),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox.square(
          dimension: radius * 2 < 48 ? 48 : radius * 2,
          child: Center(
            child: CircleAvatar(
              radius: radius,
              backgroundColor: Color(color),
              child: selected
                  ? Icon(
                      Icons.check,
                      size: radius * 1.1,
                      color: checkColorOn(Color(color)),
                    )
                  : null,
            ),
          ),
        ),
      ),
    ),
  );
}
