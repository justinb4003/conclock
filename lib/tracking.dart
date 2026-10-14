import 'package:flutter/widgets.dart';

import 'models.dart';
import 'store.dart';
import 'widgets/name_task_dialog.dart';

/// User-facing start/stop/switch, shared by the Track screen, keyboard
/// shortcuts and quick switch. Stopping an entry that has no task name asks
/// for one first. Times are taken when the user acted, not after a prompt.

/// Starts [c] (or resumes [task]), stopping whatever runs; if that is the
/// same client/task, just stops it. Returns the entry started, if any.
Future<Entry?> toggleTracking(
  BuildContext context,
  Client c, {
  String? task,
}) async {
  final store = StoreScope.read(context);
  final at = store.now();
  final r = store.running;
  final stopOnly =
      r != null &&
      r.clientId == c.id &&
      (task == null || r.note.trim() == task);
  if (!await _nameRunning(context, stopOnly: stopOnly)) return null;
  return store.toggle(c.id, note: task, at: at);
}

Future<void> stopTracking(BuildContext context) async {
  final store = StoreScope.read(context);
  final at = store.now();
  if (!await _nameRunning(context, stopOnly: true)) return;
  store.stop(at: at);
}

/// Asks for a name if the running entry has none. Returns false if the user
/// backed out, or discarded the entry and there's nothing left to do.
Future<bool> _nameRunning(
  BuildContext context, {
  required bool stopOnly,
}) async {
  final r = StoreScope.read(context).running;
  if (r == null || r.note.trim().isNotEmpty) return true;
  final choice = await askTaskName(context, r);
  if (choice == null || !context.mounted) return false;
  return !(choice == StopChoice.discard && stopOnly);
}
