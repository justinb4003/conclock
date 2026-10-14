import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../store.dart';
import 'dialogs.dart';

/// Where data lives; on desktop, lets the user move it to a folder of their
/// choice (e.g. a synced one, to share between computers).
Future<void> showDataLocation(BuildContext context) {
  final store = StoreScope.read(context);
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final theme = Theme.of(dialogContext);
      return AlertDialog(
        title: const Text('Data location'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Everything is stored locally as JSON:'),
              const SizedBox(height: 8),
              SelectableText(
                store.storageLocation,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                ),
              ),
              if (store.canChooseDataFolder) ...[
                const SizedBox(height: 16),
                Text(
                  'To use the same data on several computers, choose a '
                  'synced folder (Dropbox, OneDrive, Syncthing…). Changes '
                  'show up as they sync; avoid editing on two computers at '
                  'the same moment.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (store.canChooseDataFolder && !store.dataInDefaultFolder)
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _move(context, null);
              },
              child: const Text('Use default'),
            ),
          if (store.canChooseDataFolder)
            TextButton(
              onPressed: () async {
                final dir = await getDirectoryPath(
                  confirmButtonText: 'Use this folder',
                );
                if (dir == null || !dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                if (context.mounted) await _move(context, dir);
              },
              child: const Text('Choose folder…'),
            ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Done'),
          ),
        ],
      );
    },
  );
}

/// Moves data to [dir] (null: default), asking what to do if data is
/// already there.
Future<void> _move(BuildContext context, String? dir) async {
  final store = StoreScope.read(context);
  var useExisting = false;
  if (dir != null && await store.hasDataIn(dir)) {
    if (!context.mounted) return;
    final choice = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('That folder already has ConClock data'),
        content: const Text(
          'Use the data that’s there (e.g. from another computer), or '
          'replace it with the data on this one? Whichever is dropped is '
          'kept as a backup copy next to it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Replace with this computer’s'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Use the data there'),
          ),
        ],
      ),
    );
    if (choice == null) return;
    useExisting = choice;
  }
  try {
    await store.moveDataTo(dir, useExisting: useExisting);
    if (context.mounted) {
      toast(context, 'Data now stored in ${store.storageLocation}');
    }
  } catch (e) {
    if (context.mounted) toast(context, 'Couldn’t use that folder: $e');
  }
}
