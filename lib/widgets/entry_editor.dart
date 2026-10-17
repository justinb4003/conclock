import 'package:flutter/material.dart';

import '../format.dart';
import '../models.dart';
import '../store.dart';
import 'common.dart';
import 'dialogs.dart';

/// Opens the editor for [entry], or for a new entry when null.
Future<void> showEntryEditor(BuildContext context, {Entry? entry}) {
  final store = StoreScope.read(context);
  if (store.activeClients.isEmpty && entry == null) {
    toast(context, 'Add a client first');
    return Future.value();
  }
  // The dialog's own context reaches only the app-wide messenger; toasts
  // belong to the screen that opened it.
  final messenger = ScaffoldMessenger.of(context);
  return showDialog<void>(
    context: context,
    builder: (_) => StoreScope(
      store: store,
      child: _EntryEditor(entry: entry, messenger: messenger),
    ),
  );
}

class _EntryEditor extends StatefulWidget {
  const _EntryEditor({this.entry, required this.messenger});

  final Entry? entry;
  final ScaffoldMessengerState messenger;

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

  /// Calendar days from the start's day to the end's.
  int get _endDays => _end == null ? 0 : daysBetween(_start, _end!);

  /// Puts the end [days] after the start's day at time [t] (default: its
  /// current time), moving it a day later while it isn't after the start.
  void _placeEnd(int days, [TimeOfDay? t]) {
    final e = _end;
    if (e == null) return;
    final s = _start;
    final (h, m, sec) = t == null
        ? (e.hour, e.minute, e.second)
        : (t.hour, t.minute, 0);
    var end = DateTime(s.year, s.month, s.day + days, h, m, sec);
    while (!end.isAfter(s)) {
      end = DateTime(end.year, end.month, end.day + 1, h, m, sec);
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
    final days = _endDays;
    setState(() {
      _start = DateTime(
        d.year,
        d.month,
        d.day,
        _start.hour,
        _start.minute,
        _start.second,
      );
      _placeEnd(days);
    });
  }

  Future<void> _pickStart() async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_start),
    );
    if (t == null) return;
    final days = _endDays;
    setState(() {
      _start = DateTime(
        _start.year,
        _start.month,
        _start.day,
        t.hour,
        t.minute,
      );
      _placeEnd(days);
    });
  }

  Future<void> _pickEnd() async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_end!),
    );
    if (t == null) return;
    // The first such time after the start (the next day if need be).
    setState(() => _placeEnd(0, t));
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
    final undo = StoreScope.read(context).deleteEntry(widget.entry!);
    Navigator.pop(context);
    showToast(widget.messenger, 'Entry deleted', undo: undo);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final clients = [
      for (final c in store.clients)
        if (!c.archived || c.id == _clientId) c,
    ];
    // The client may be gone (e.g. an imported backup's entry); the entry
    // keeps its id until another client is picked, so list it as unknown.
    final orphan = !clients.any((c) => c.id == _clientId);
    final now = store.now();
    final duration = _running
        ? now.difference(_start)
        : _end!.difference(_start);
    final endDays = _running ? 0 : _endDays;
    final error = _error;
    final overlaps = store.overlapping(
      _start,
      _running ? now : _end!,
      exceptId: widget.entry?.id,
      now: now,
    );

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
                  if (orphan)
                    DropdownMenuItem(
                      value: _clientId,
                      child: _ClientLabel(
                        color: clientPalette.last,
                        name: 'Unknown client',
                      ),
                    ),
                  for (final c in clients)
                    DropdownMenuItem(
                      value: c.id,
                      child: _ClientLabel(color: c.color, name: c.name),
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
                      isTime: true,
                      icon: Icons.schedule,
                      onTap: _pickStart,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _FieldButton(
                      label: 'End',
                      isTime: !_running,
                      value: _running
                          ? 'Running'
                          : fmtTime(context, _end!) +
                                (endDays > 0 ? ' (+${endDays}d)' : ''),
                      icon: Icons.schedule,
                      onTap: _running ? null : _pickEnd,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'Duration '),
                    timeSpan(
                      context,
                      fmtHm(duration.isNegative ? Duration.zero : duration),
                    ),
                  ],
                ),
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
              if (overlaps.isNotEmpty) ...[
                const SizedBox(height: 8),
                _OverlapWarning(overlaps: overlaps),
              ],
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

/// Color dot and name, as listed in the client dropdown.
class _ClientLabel extends StatelessWidget {
  const _ClientLabel({required this.color, required this.name});

  final int color;
  final String name;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      CircleAvatar(radius: 6, backgroundColor: Color(color)),
      const SizedBox(width: 10),
      Flexible(child: Text(name, overflow: TextOverflow.ellipsis)),
    ],
  );
}

class _FieldButton extends StatelessWidget {
  const _FieldButton({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    this.isTime = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;
  final bool isTime;

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
        child: Text(value, style: isTime ? timeStyle(context) : null),
      ),
    );
  }
}

/// Non-blocking note that this entry overlaps others (double billing?).
class _OverlapWarning extends StatelessWidget {
  const _OverlapWarning({required this.overlaps});

  final List<Entry> overlaps;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.read(context);
    final color = Theme.of(context).colorScheme.tertiary;
    String describe(Entry e) =>
        '${store.clientById(e.clientId)?.name ?? 'Unknown'} '
        '${fmtTime(context, e.start)} – '
        '${e.isRunning ? 'now' : fmtTime(context, e.end!)}';
    final shown = overlaps.take(2).map(describe).join(', ');
    final more = overlaps.length > 2 ? ' and ${overlaps.length - 2} more' : '';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.warning_amber_rounded, size: 18, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'Overlaps $shown$more',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}
