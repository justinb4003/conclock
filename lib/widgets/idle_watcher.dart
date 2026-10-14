import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../format.dart';
import '../models.dart';
import '../store.dart';

/// Asks before a forgotten timer bills hours nobody worked.
const longRunning = Duration(hours: 9);

/// A clock jump this big between ticks means the computer slept.
const awayGap = Duration(minutes: 15);

/// "Keep running" on a long timer asks again after this long.
const _snooze = Duration(hours: 3);

/// Watches the running timer and asks "still working?" when it has run
/// [longRunning], or (not on web, where background tabs pause timers) when
/// the computer seems to have slept for [awayGap] or more.
class IdleWatcher extends StatefulWidget {
  const IdleWatcher({super.key, required this.child});

  final Widget child;

  @override
  State<IdleWatcher> createState() => _IdleWatcherState();
}

class _IdleWatcherState extends State<IdleWatcher> {
  Timer? _timer;
  late final AppLifecycleListener _lifecycle;
  DateTime? _lastTick;
  bool _asking = false;
  final _snoozedUntil = <String, DateTime>{};

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _check());
    _lifecycle = AppLifecycleListener(onResume: _check);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    if (!mounted || _asking) return;
    final store = StoreScope.read(context);
    final now = store.now();
    final last = _lastTick;
    _lastTick = now;
    final r = store.running;
    if (r == null) return;

    // Slept: the gap counts from the last tick (or the start, if later).
    if (!kIsWeb && last != null && now.difference(last) >= awayGap) {
      final from = last.isBefore(r.start) ? r.start : last;
      if (now.difference(from) >= awayGap) {
        await _ask(r, away: from);
        return;
      }
    }
    final snoozed = _snoozedUntil[r.id];
    if (r.durationAt(now) >= longRunning &&
        (snoozed == null || now.isAfter(snoozed))) {
      await _ask(r);
    }
  }

  Future<void> _ask(Entry r, {DateTime? away}) async {
    _asking = true;
    try {
      final choice = await showDialog<_Choice>(
        context: context,
        barrierDismissible: false,
        builder: (_) => StoreScope(
          store: StoreScope.read(context),
          child: _StillWorkingDialog(entry: r, away: away),
        ),
      );
      if (!mounted || choice == null) return;
      final store = StoreScope.read(context);
      // The timer may have been stopped elsewhere while we asked.
      if (store.running?.id != r.id) return;
      switch (choice) {
        case _Keep():
          _snoozedUntil[r.id] = store.now().add(_snooze);
        case _RemoveGap(:final from):
          store.removeGap(from);
        case _StopAt(:final at):
          store.stop(at: at);
      }
    } finally {
      _asking = false;
      if (mounted) _lastTick = StoreScope.read(context).now();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

sealed class _Choice {
  const _Choice();
}

class _Keep extends _Choice {
  const _Keep();
}

class _RemoveGap extends _Choice {
  const _RemoveGap(this.from);
  final DateTime from;
}

class _StopAt extends _Choice {
  const _StopAt(this.at);
  final DateTime at;
}

class _StillWorkingDialog extends StatelessWidget {
  const _StillWorkingDialog({required this.entry, this.away});

  final Entry entry;

  /// When the computer went to sleep, if that's why we're asking.
  final DateTime? away;

  Future<void> _pickStop(BuildContext context) async {
    final store = StoreScope.read(context);
    final now = store.now();
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now),
      helpText: 'Stopped working at',
    );
    if (t == null || !context.mounted) return;
    // The latest such time that's not in the future and after the start.
    var at = DateTime(now.year, now.month, now.day, t.hour, t.minute);
    if (at.isAfter(now)) {
      at = DateTime(now.year, now.month, now.day - 1, t.hour, t.minute);
    }
    if (!at.isAfter(entry.start)) at = entry.start;
    Navigator.pop(context, _StopAt(at));
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.read(context);
    final now = store.now();
    final client = store.clientById(entry.clientId)?.name ?? 'this client';
    final task = entry.note.trim().isEmpty ? '' : ' · ${entry.note.trim()}';
    final a = away;
    final gap = a == null ? null : now.difference(a);

    return AlertDialog(
      title: Text('Still working on $client?'),
      content: Text(
        a == null
            ? 'The timer$task has been running since '
                  '${fmtTime(context, entry.start)} (${fmtHm(entry.durationAt(now))}).'
            : 'Your computer seems to have been asleep from '
                  '${fmtTime(context, a)} to ${fmtTime(context, now)} '
                  '(${fmtHm(gap!)}) while the timer$task kept running.',
      ),
      actions: a != null
          ? [
              TextButton(
                onPressed: () => Navigator.pop(context, const _Keep()),
                child: const Text('Keep the time'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, _StopAt(a)),
                child: Text('Stop at ${fmtTime(context, a)}'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, _RemoveGap(a)),
                child: Text('Remove ${fmtHm(gap!)}, keep going'),
              ),
            ]
          : [
              TextButton(
                onPressed: () => _pickStop(context),
                child: const Text('Stop at…'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, _StopAt(now)),
                child: const Text('Stop now'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, const _Keep()),
                child: const Text('Keep running'),
              ),
            ],
    );
  }
}
