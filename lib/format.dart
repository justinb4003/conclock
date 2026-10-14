import 'package:flutter/material.dart';

String _two(int n) => n.toString().padLeft(2, '0');

/// 1:05:09
String fmtClock(Duration d) {
  final s = d.inSeconds;
  return '${s ~/ 3600}:${_two(s % 3600 ~/ 60)}:${_two(s % 60)}';
}

/// 1:05
String fmtHm(Duration d) {
  final m = d.inMinutes;
  return '${m ~/ 60}:${_two(m % 60)}';
}

/// Rounds up to the next half hour (0:32 → 1:00, 0:30 → 0:30).
Duration roundUpHalfHour(Duration d) {
  const step = 30 * 60;
  final s = d.inSeconds;
  return Duration(seconds: (s + step - 1) ~/ step * step);
}

/// 1.08
String fmtDecimal(Duration d) => (d.inSeconds / 3600).toStringAsFixed(2);

/// Hours in the user's chosen format: 1.08 or 1:05.
String fmtHours(Duration d, {required bool decimal}) =>
    decimal ? fmtDecimal(d) : fmtHm(d);

/// 2026-10-12
String fmtIsoDate(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

DateTime dayStart(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

/// Whole calendar days from [from] to [to]'s day (DST-safe: such days
/// aren't exactly 24h).
int daysBetween(DateTime from, DateTime to) =>
    (dayStart(to).difference(dayStart(from)).inHours / 24).round();

/// Monday of [d]'s week (timesheet weeks run Mon–Sun).
DateTime weekStart(DateTime d) => addDays(dayStart(d), 1 - d.weekday);

String fmtTime(BuildContext context, DateTime t) =>
    MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(t),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );

String fmtDay(BuildContext context, DateTime d) {
  final today = dayStart(DateTime.now());
  final day = dayStart(d);
  if (day == today) return 'Today';
  if (day == addDays(today, -1)) return 'Yesterday';
  return MaterialLocalizations.of(context).formatFullDate(d);
}
