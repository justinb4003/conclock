import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../widgets/dialogs.dart';

/// Add, edit (name and color), reorder, archive and delete clients.
class ClientsScreen extends StatelessWidget {
  const ClientsScreen({super.key});

  /// Asks first: a client takes its whole history with it. The toast
  /// still offers Undo.
  Future<void> _delete(BuildContext context, Client c) async {
    final store = StoreScope.read(context);
    final n = store.entryCount(c.id);
    final ok = await confirm(
      context,
      title: 'Delete ${c.name}?',
      message: n == 0
          ? 'This client has no tracked time.'
          : 'This also deletes $n time ${n == 1 ? 'entry' : 'entries'}. '
                'Archive instead to keep the history.',
    );
    if (!ok || !context.mounted) return;
    toast(
      context,
      n == 0
          ? 'Deleted ${c.name}'
          : 'Deleted ${c.name} and $n ${n == 1 ? 'entry' : 'entries'}',
      undo: store.deleteClient(c),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final theme = Theme.of(context);
    final clients = store.clients;

    return Scaffold(
      appBar: AppBar(title: const Text('Clients')),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add client',
        onPressed: () => showAddClient(context),
        child: const Icon(Icons.add),
      ),
      body: clients.isEmpty
          ? const Center(child: Text('No clients yet'))
          : ReorderableListView.builder(
              buildDefaultDragHandles: false,
              padding: const EdgeInsets.only(bottom: 88),
              itemCount: clients.length,
              onReorder: (from, to) =>
                  store.moveClient(from, to > from ? to - 1 : to),
              itemBuilder: (context, i) {
                final c = clients[i];
                final muted = theme.colorScheme.onSurfaceVariant;
                return ListTile(
                  key: ValueKey(c.id),
                  onTap: () => showEditClient(context, c),
                  leading: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ReorderableDragStartListener(
                        index: i,
                        child: Icon(Icons.drag_indicator, color: muted),
                      ),
                      const SizedBox(width: 8),
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: Color(
                          c.color,
                        ).withValues(alpha: c.archived ? 0.35 : 1),
                      ),
                    ],
                  ),
                  title: Text(
                    c.name,
                    style: c.archived ? TextStyle(color: muted) : null,
                  ),
                  subtitle: c.archived ? const Text('Archived') : null,
                  trailing: PopupMenuButton<String>(
                    tooltip: 'Options for ${c.name}',
                    onSelected: (v) => switch (v) {
                      'archive' => store.setArchived(c, !c.archived),
                      'delete' => _delete(context, c),
                      _ => null,
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'archive',
                        child: Text(c.archived ? 'Unarchive' : 'Archive'),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete'),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
