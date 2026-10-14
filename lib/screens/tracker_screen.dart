import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../format.dart';
import '../models.dart';
import '../store.dart';
import '../widgets/dialogs.dart';
import '../widgets/live_builder.dart';
import '../widgets/name_task_dialog.dart';

/// Tap a client to start it; tap again (or another) to stop / switch.
class TrackerScreen extends StatefulWidget {
  const TrackerScreen({super.key});

  @override
  State<TrackerScreen> createState() => _TrackerScreenState();
}

class _TrackerScreenState extends State<TrackerScreen> {
  final _note = TextEditingController();
  final _noteFocus = FocusNode();
  AppStore? _store;
  String? _noteEntryId;

  /// On phones, popping the keyboard on every switch is more annoying than
  /// helpful; on desktop/web it makes "click client, type note" instant.
  /// (On the web this reflects the device, so phone browsers count as phones.)
  bool get _autofocusNote =>
      !(defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    // Committing the note (Enter / clicking away) adds it to the task list.
    _noteFocus.addListener(_onNoteFocus);
  }

  void _onNoteFocus() => setState(() {});

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final store = StoreScope.read(context);
    if (store != _store) {
      _store?.removeListener(_syncNote);
      _store = store..addListener(_syncNote);
      _syncNote();
    }
  }

  /// Load the running entry's note into the field when the entry changes.
  void _syncNote() {
    final r = _store!.running;
    if (r?.id == _noteEntryId) return;
    _noteEntryId = r?.id;
    _note.text = r?.note ?? '';
  }

  @override
  void dispose() {
    _store?.removeListener(_syncNote);
    _note.dispose();
    _noteFocus.dispose();
    super.dispose();
  }

  /// If the running entry has no name, asks for one before it's stopped.
  /// Returns false if the user backed out, or the entry was discarded and
  /// there's nothing left to do.
  Future<bool> _nameRunning({required bool stopOnly}) async {
    final r = _store!.running;
    if (r == null || r.note.trim().isNotEmpty) return true;
    _noteFocus.unfocus();
    final choice = await askTaskName(context, r);
    if (choice == null || !mounted) return false;
    // Discarding the entry the user was stopping finishes the action.
    return !(choice == StopChoice.discard && stopOnly);
  }

  Future<void> _stop() async {
    final store = _store!;
    final at = store.now();
    if (!await _nameRunning(stopOnly: true)) return;
    _noteFocus.unfocus();
    store.stop(at: at);
  }

  /// Starts/stops [c]; with [task], resumes that task (its note prefilled).
  Future<void> _toggle(Client c, {String? task}) async {
    final store = _store!;
    final at = store.now();
    final r = store.running;
    final stopOnly =
        r != null &&
        r.clientId == c.id &&
        (task == null || r.note.trim() == task);
    if (!await _nameRunning(stopOnly: stopOnly)) return;
    final started = store.toggle(c.id, note: task, at: at);
    if (started != null && task == null && _autofocusNote) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _noteFocus.requestFocus(),
      );
    } else {
      _noteFocus.unfocus();
    }
  }

  /// A client row, or a task row under it when [task] is set. Shows today's
  /// total, ticking while running.
  Widget _row(
    AppStore store,
    Client c,
    String? task,
    bool isRunning,
    DateTime today,
    DateTime now,
    Duration? clientTotal,
  ) {
    final tomorrow = addDays(today, 1);
    Duration totalAt(DateTime t) => task == null
        ? store.totalsIn(today, tomorrow, t)[c.id] ?? Duration.zero
        : store.taskTotalIn(c.id, task, today, tomorrow, t);
    return _TrackRow(
      key: ValueKey(task == null ? c.id : '${c.id}/$task'),
      color: Color(c.color),
      label: task ?? c.name,
      isTask: task != null,
      running: isRunning,
      total: isRunning ? null : clientTotal ?? totalAt(now),
      liveTotal: isRunning ? totalAt : null,
      onTap: () => _toggle(c, task: task),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final running = store.running;
    final clients = store.activeClients.toList();
    final now = store.now();
    final today = dayStart(now);
    final totals = store.totalsIn(today, addDays(today, 1), now);
    final tasks = store.recentTasks(now);
    // The running entry's note counts as a task once committed, i.e. while
    // the note field isn't being edited.
    final runningTask = running == null || _noteFocus.hasFocus
        ? null
        : running.note.trim();
    if (runningTask != null && runningTask.isNotEmpty) {
      final list = tasks.putIfAbsent(running!.clientId, () => []);
      if (!list.contains(runningTask)) list.insert(0, runningTask);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('ConClock'),
        actions: [
          IconButton(
            tooltip: 'Add client',
            onPressed: () => showAddClient(context),
            icon: const Icon(Icons.person_add_alt),
          ),
        ],
      ),
      body: clients.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('No clients yet'),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => showAddClient(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Add a client'),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                _StatusPanel(
                  running: running,
                  client: running == null
                      ? null
                      : store.clientById(running.clientId),
                  note: _note,
                  noteFocus: _noteFocus,
                  onStop: _stop,
                  // Enter commits the note: it shows up as a running task.
                  onNoteSubmitted: () => setState(_noteFocus.unfocus),
                  onNoteChanged: (v) {
                    if (running != null) store.setNote(running, v);
                  },
                  todayTotal: (now) => store
                      .totalsIn(today, addDays(today, 1), now)
                      .values
                      .fold(Duration.zero, (a, b) => a + b),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      for (final c in clients) ...[
                        _row(
                          store,
                          c,
                          null,
                          running?.clientId == c.id,
                          today,
                          now,
                          totals[c.id],
                        ),
                        for (final task in tasks[c.id] ?? const <String>[])
                          _row(
                            store,
                            c,
                            task,
                            running?.clientId == c.id && runningTask == task,
                            today,
                            now,
                            null,
                          ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({
    required this.running,
    required this.client,
    required this.note,
    required this.noteFocus,
    required this.onStop,
    required this.onNoteChanged,
    required this.onNoteSubmitted,
    required this.todayTotal,
  });

  final Entry? running;
  final Client? client;
  final TextEditingController note;
  final FocusNode noteFocus;
  final VoidCallback onStop;
  final ValueChanged<String> onNoteChanged;
  final VoidCallback onNoteSubmitted;
  final Duration Function(DateTime now) todayTotal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = running;
    final color = client == null
        ? theme.colorScheme.outline
        : Color(client!.color);

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: color, width: 6)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: r == null
            ? Row(
                children: [
                  Expanded(
                    child: Text(
                      'Not tracking — tap a client to start',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Text(
                    'Today ${fmtHm(todayTotal(DateTime.now()))}',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          client?.name ?? '?',
                          style: theme.textTheme.titleLarge,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      LiveBuilder(
                        builder: (context, now) => Text(
                          fmtClock(r.durationAt(now)),
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        tooltip: 'Stop',
                        onPressed: onStop,
                        icon: const Icon(Icons.stop),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: note,
                    focusNode: noteFocus,
                    onChanged: onNoteChanged,
                    onSubmitted: (_) => onNoteSubmitted(),
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText: 'Add a note…',
                      isDense: true,
                      prefixIcon: Icon(Icons.notes, size: 18),
                      prefixIconConstraints: BoxConstraints(
                        minWidth: 28,
                        minHeight: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  LiveBuilder(
                    builder: (context, now) => Text(
                      'Started ${fmtTime(context, r.start)} · Today ${fmtHm(todayTotal(now))}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _TrackRow extends StatelessWidget {
  const _TrackRow({
    super.key,
    required this.color,
    required this.label,
    required this.isTask,
    required this.running,
    required this.total,
    required this.liveTotal,
    required this.onTap,
  });

  final Color color;
  final String label;
  final bool isTask;
  final bool running;
  final Duration? total;
  final Duration Function(DateTime now)? liveTotal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyMedium?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
      color: running ? null : theme.colorScheme.onSurfaceVariant,
      fontWeight: running ? FontWeight.w600 : null,
    );

    return ListTile(
      onTap: onTap,
      dense: isTask,
      visualDensity: isTask ? VisualDensity.compact : null,
      selected: running,
      selectedTileColor: color.withValues(alpha: isTask ? 0.08 : 0.12),
      selectedColor: theme.colorScheme.onSurface,
      // Task play buttons line up under the client name.
      contentPadding: EdgeInsets.only(left: isTask ? 60 : 16, right: 16),
      leading: CircleAvatar(
        radius: isTask ? 12 : 18,
        backgroundColor: running ? color : color.withValues(alpha: 0.18),
        child: Icon(
          running ? Icons.stop : Icons.play_arrow,
          size: isTask ? 16 : null,
          color: running ? Colors.white : color,
        ),
      ),
      title: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: isTask
            ? theme.textTheme.bodyMedium?.copyWith(
                color: running ? null : theme.colorScheme.onSurfaceVariant,
                fontWeight: running ? FontWeight.w600 : null,
              )
            : running
            ? const TextStyle(fontWeight: FontWeight.w600)
            : null,
      ),
      trailing: liveTotal != null
          ? LiveBuilder(
              builder: (context, now) =>
                  Text(fmtHm(liveTotal!(now)), style: style),
            )
          : Text(total == Duration.zero ? '' : fmtHm(total!), style: style),
    );
  }
}
