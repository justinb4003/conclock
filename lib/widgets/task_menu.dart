import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import 'dialogs.dart';

/// Right-click (or long-press) menu for a task row: rename/merge the task.
class TaskMenuRegion extends StatelessWidget {
  const TaskMenuRegion({
    super.key,
    required this.clientId,
    required this.task,
    this.only,
    required this.child,
  });

  final String clientId;
  final String task;

  /// Limit renaming to these entries (e.g. one day's unnamed ones).
  final Iterable<Entry>? only;
  final Widget child;

  Future<void> _open(BuildContext context, Offset at) async {
    final choice = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(at.dx, at.dy, at.dx, at.dy),
      items: [
        PopupMenuItem(
          value: 'rename',
          child: Text(task.isEmpty ? 'Name these entries…' : 'Rename task…'),
        ),
      ],
    );
    if (choice == 'rename' && context.mounted) {
      await renameTask(context, clientId: clientId, task: task, only: only);
    }
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onSecondaryTapDown: (d) => _open(context, d.globalPosition),
    onLongPressStart: (d) => _open(context, d.globalPosition),
    child: child,
  );
}

/// Asks for a new name for [task] and applies it. Naming it like an
/// existing task merges them.
Future<void> renameTask(
  BuildContext context, {
  required String clientId,
  required String task,
  Iterable<Entry>? only,
}) async {
  final store = StoreScope.read(context);
  final name = await promptText(
    context,
    title: task.isEmpty ? 'Name these entries' : 'Rename task',
    initial: task,
    hint: 'Task name',
    confirmLabel: 'Rename',
    capitalization: TextCapitalization.sentences,
  );
  if (name == null || name == task || !context.mounted) return;
  final merging = store.hasTask(clientId, name);
  final (:count, :undo) = store.renameTask(clientId, task, name, only: only);
  final what = '$count ${count == 1 ? 'entry' : 'entries'}';
  toast(
    context,
    merging ? 'Merged $what into “$name”' : 'Renamed $what',
    undo: undo,
  );
}
