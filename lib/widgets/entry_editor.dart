import 'package:flutter/material.dart';

import '../format.dart';
import '../models.dart';
import '../store.dart';
import 'dialogs.dart';

/// Opens the editor for [entry], or for a new entry when null.
Future<void> showEntryEditor(BuildContext context, {Entry? entry}) {
  final store = StoreScope.read(context);
  if (store.activeClients.isEmpty && entry == null) {
    toast(context, 'Add a client first');
    return Future.value();
  }
  return showDialog<void>(
    context: context,
    builder: (_) => StoreScope(
      store: store,
      child: _EntryEditor(entry: entry),
    ),
  );
}

class _EntryEditor extends StatefulWidget {
  const _EntryEditor({this.entry});

  final Entry? entry;

  @override
  State<_EntryEditor> createState() => _EntryEditorState();
}

class _EntryEditorState extends State<_EntryEditor> {
  late String _clientId;
  late DateTime _start;
  DateTime? _end;
  late final TextEditingController _note;

  /// Fixed when the dialog opens, so a timer stopped meanwhile (another tab
  /// or window) can't leave the form half running, half not.
  late final bool _running = widget.entry?.isRunning ?? false;

  @override
  void initState() {
    super.initState();
    final store = StoreScope.read(context);
    final e = widget.entry;
    if (e != null) {
      _clientId = e.clientId;
      _start = e.start;
      _end = e.end;
    } else {
      final now = store.now();
      _clientId =
          store.entries.isNotEmpty &&
              !(store.clientById(store.entries.first.clientId)?.archived ??
                  true)
          ? store.entries.first.clientId
          : store.activeClients.first.id;
      _end = DateTime(now.year, now.month, now.day, now.hour, now.minute);
      _start = _end!.subtract(const Duration(hours: 1));
    }
    _note = TextEditingController(text: e?.note ?? '');
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  /// Puts the end on the start's day, or the next day if it would be earlier.
  void _normalizeEnd() {
    final e = _end;
    if (e == null) return;
    final s = _start;
    var end = DateTime(s.year, s.month, s.day, e.hour, e.minute, e.second);
    if (!end.isAfter(s)) {
      end = DateTime(s.year, s.month, s.day + 1, e.hour, e.minute, e.second);
    }
    _end = end;
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d == null) return;
    setState(() {
      _start = DateTime(
        d.year,
        d.month,
        d.day,
        _start.hour,
        _start.minute,
        _start.second,
      );
      _normalizeEnd();
    });
  }

  Future<void> _pickStart() async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_start),
    );
    if (t == null) return;
    setState(() {
      _start = DateTime(
        _start.year,
        _start.month,
        _start.day,
        t.hour,
        t.minute,
      );
      _normalizeEnd();
    });
  }

  Future<void> _pickEnd() async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_end!),
    );
    if (t == null) return;
    setState(() {
      _end = DateTime(_start.year, _start.month, _start.day, t.hour, t.minute);
      _normalizeEnd();
    });
  }

  String? get _error {
    final store = StoreScope.read(context);
    if (_running && _start.isAfter(store.now())) {
      return 'A running entry can’t start in the future';
    }
    return null;
  }

  void _save() {
    final store = StoreScope.read(context);
    final e = widget.entry;
    if (e == null) {
      store.addEntry(
        Entry(
          id: newId(),
          clientId: _clientId,
          start: _start,
          end: _end,
          note: _note.text.trim(),
        ),
      );
    } else {
      store.updateEntry(
        e,
        clientId: _clientId,
        start: _start,
        // Running: keep whatever the timer is doing now (it may have been
        // stopped elsewhere while this was open).
        end: _running ? store.entryById(e.id)?.end : _end,
        note: _note.text.trim(),
      );
    }
    Navigator.pop(context);
  }

  void _delete() {
    final messenger = ScaffoldMessenger.of(context);
    final undo = StoreScope.read(context).deleteEntry(widget.entry!);
    Navigator.pop(context);
    showToast(messenger, 'Entry deleted', undo: undo);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final clients = [
      for (final c in store.clients)
        if (!c.archived || c.id == _clientId) c,
    ];
    final now = store.now();
    final duration = _running
        ? now.difference(_start)
        : _end!.difference(_start);
    final nextDay = !_running && dayStart(_end!) != dayStart(_start);
    final error = _error;

    return AlertDialog(
      title: Text(widget.entry == null ? 'Add time' : 'Edit time'),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _clientId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Client'),
                items: [
                  for (final c in clients)
                    DropdownMenuItem(
                      value: c.id,
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 6,
                            backgroundColor: Color(c.color),
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              c.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
                onChanged: (v) => setState(() => _clientId = v!),
              ),
              const SizedBox(height: 16),
              _FieldButton(
                label: 'Date',
                value: MaterialLocalizations.of(
                  context,
                ).formatMediumDate(_start),
                icon: Icons.calendar_today_outlined,
                onTap: _pickDate,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _FieldButton(
                      label: 'Start',
                      value: fmtTime(context, _start),
                      icon: Icons.schedule,
                      onTap: _pickStart,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _FieldButton(
                      label: 'End',
                      value: _running
                          ? 'Running'
                          : fmtTime(context, _end!) + (nextDay ? ' (+1d)' : ''),
                      icon: Icons.schedule,
                      onTap: _running ? null : _pickEnd,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Duration ${fmtHm(duration.isNegative ? Duration.zero : duration)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _note,
                decoration: const InputDecoration(
                  labelText: 'Note',
                  border: OutlineInputBorder(),
                ),
                minLines: 2,
                maxLines: 5,
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(
                  error,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (widget.entry != null)
          TextButton(
            onPressed: _delete,
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: error == null ? _save : null,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _FieldButton extends StatelessWidget {
  const _FieldButton({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: Icon(icon, size: 18),
          enabled: onTap != null,
        ),
        child: Text(value),
      ),
    );
  }
}
