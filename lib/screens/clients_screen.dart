import 'package:flutter/material.dart';

import '../backup/backup.dart';
import '../models.dart';
import '../store.dart';
import '../widgets/dialogs.dart';

/// Add, rename, recolor, reorder, archive and delete clients.
class ClientsScreen extends StatelessWidget {
  const ClientsScreen({super.key});

  Future<void> _add(BuildContext context) async {
    final store = StoreScope.read(context);
    final name = await promptText(
      context,
      title: 'New client',
      hint: 'Client name',
      confirmLabel: 'Add',
    );
    if (name != null) store.addClient(name);
  }

  Future<void> _rename(BuildContext context, Client c) async {
    final store = StoreScope.read(context);
    final name = await promptText(
      context,
      title: 'Rename client',
      initial: c.name,
    );
    if (name != null) store.renameClient(c, name);
  }

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
    if (ok) store.deleteClient(c);
  }

  void _showDataLocation(BuildContext context) {
    final store = StoreScope.read(context);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Your data'),
        content: SelectableText(
          'Everything is stored locally as JSON:\n\n${store.storageLocation}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final theme = Theme.of(context);
    final clients = store.clients;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clients'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Data & backups',
            icon: const Icon(Icons.save_outlined),
            onSelected: (v) => switch (v) {
              'export' => exportBackup(context),
              'import' => importBackup(context),
              _ => _showDataLocation(context),
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'export',
                child: ListTile(
                  leading: Icon(Icons.upload_file),
                  title: Text('Export backup…'),
                ),
              ),
              PopupMenuItem(
                value: 'import',
                child: ListTile(
                  leading: Icon(Icons.restore),
                  title: Text('Import backup…'),
                ),
              ),
              PopupMenuItem(
                value: 'location',
                child: ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('Data location'),
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add client',
        onPressed: () => _add(context),
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
                  onTap: () => _rename(context, c),
                  leading: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ReorderableDragStartListener(
                        index: i,
                        child: Icon(Icons.drag_indicator, color: muted),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () async {
                          final color = await pickColor(context, c.color);
                          if (color != null) store.setClientColor(c, color);
                        },
                        child: CircleAvatar(
                          radius: 14,
                          backgroundColor: Color(
                            c.color,
                          ).withValues(alpha: c.archived ? 0.35 : 1),
                        ),
                      ),
                    ],
                  ),
                  title: Text(
                    c.name,
                    style: c.archived ? TextStyle(color: muted) : null,
                  ),
                  subtitle: c.archived ? const Text('Archived') : null,
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) => switch (v) {
                      'rename' => _rename(context, c),
                      'color' => pickColor(context, c.color).then((color) {
                        if (color != null) store.setClientColor(c, color);
                      }),
                      'archive' => store.setArchived(c, !c.archived),
                      'delete' => _delete(context, c),
                      _ => null,
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'rename',
                        child: Text('Rename'),
                      ),
                      const PopupMenuItem(value: 'color', child: Text('Color')),
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
