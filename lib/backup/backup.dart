import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../format.dart';
import '../store.dart';
import '../widgets/dialogs.dart';
import 'save_file.dart';

const _jsonType = XTypeGroup(
  label: 'ConClock backup',
  extensions: ['json'],
  mimeTypes: ['application/json'],
  uniformTypeIdentifiers: ['public.json'],
);

Future<void> exportBackup(BuildContext context) async {
  final store = StoreScope.read(context);
  final name = 'conclock-backup-${fmtIsoDate(DateTime.now())}.json';
  try {
    final message = await saveTextFile(name, store.exportJson(), _jsonType);
    if (message != null && context.mounted) toast(context, message);
  } catch (e) {
    if (context.mounted) toast(context, 'Export failed: $e');
  }
}

/// Picks a backup file and, after confirming, replaces all data with it.
Future<void> importBackup(BuildContext context) async {
  final store = StoreScope.read(context);
  final String raw;
  try {
    final file = await openFile(acceptedTypeGroups: [_jsonType]);
    if (file == null) return;
    raw = await file.readAsString();
  } catch (e) {
    if (context.mounted) toast(context, 'Could not open file: $e');
    return;
  }
  if (!context.mounted) return;

  // Describe what's in the file before replacing anything.
  int clients, entries;
  try {
    final data = jsonDecode(raw) as Map<String, dynamic>;
    clients = (data['clients'] as List).length;
    entries = (data['entries'] as List? ?? const []).length;
  } catch (_) {
    toast(context, 'That file isn’t a ConClock backup');
    return;
  }

  String count(int n, String one, String many) => '$n ${n == 1 ? one : many}';
  final ok = await confirm(
    context,
    title: 'Replace all data?',
    message:
        'The backup has ${count(clients, 'client', 'clients')} and '
        '${count(entries, 'entry', 'entries')}. It will replace your current '
        '${count(store.clients.length, 'client', 'clients')} and '
        '${count(store.entries.length, 'entry', 'entries')}.\n\n'
        'A copy of your current data is kept alongside it, just in case.',
    confirmLabel: 'Replace',
  );
  if (!ok || !context.mounted) return;

  try {
    await store.importJson(raw);
    if (context.mounted) toast(context, 'Backup restored');
  } on FormatException catch (e) {
    if (context.mounted) toast(context, 'Import failed: ${e.message}');
  } catch (e) {
    if (context.mounted) toast(context, 'Import failed: $e');
  }
}
