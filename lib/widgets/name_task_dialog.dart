import 'package:flutter/material.dart';

import '../format.dart';
import '../models.dart';
import '../store.dart';

enum StopChoice { named, unnamed, discard }

/// Asks for a task name before an unnamed running entry is stopped.
/// Returns null if the user backs out (the entry keeps running).
Future<StopChoice?> askTaskName(BuildContext context, Entry entry) async {
  final store = StoreScope.read(context);
  final result = await showDialog<(StopChoice, String)>(
    context: context,
    builder: (_) => StoreScope(
      store: store,
      child: _NameTaskDialog(entry: entry),
    ),
  );
  if (result == null) return null;
  final (choice, name) = result;
  switch (choice) {
    case StopChoice.named:
      store.setNote(entry, name);
    case StopChoice.discard:
      store.deleteEntry(entry);
    case StopChoice.unnamed:
      break;
  }
  return choice;
}

class _NameTaskDialog extends StatefulWidget {
  const _NameTaskDialog({required this.entry});

  final Entry entry;

  @override
  State<_NameTaskDialog> createState() => _NameTaskDialogState();
}

class _NameTaskDialogState extends State<_NameTaskDialog> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save([String? name]) {
    final v = (name ?? _name.text).trim();
    if (v.isNotEmpty) Navigator.pop(context, (StopChoice.named, v));
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.read(context);
    final theme = Theme.of(context);
    final e = widget.entry;
    final client = store.clientById(e.clientId);
    final now = store.now();
    final suggestions = (store.recentTasks(now)[e.clientId] ?? const <String>[])
        .take(8);

    return AlertDialog(
      title: const Text('Name this task'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 6,
                  backgroundColor: Color(client?.color ?? clientPalette.last),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${client?.name ?? 'Unknown'} · '
                    '${fmtTime(context, e.start)} · ${fmtHm(e.durationAt(now))}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'What were you working on?',
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _save(),
            ),
            if (suggestions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final s in suggestions)
                    ActionChip(label: Text(s), onPressed: () => _save(s)),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, (StopChoice.discard, '')),
          style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
          child: const Text('Discard'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, (StopChoice.unnamed, '')),
          child: const Text('Leave unnamed'),
        ),
        FilledButton(
          onPressed: _name.text.trim().isEmpty ? null : _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
