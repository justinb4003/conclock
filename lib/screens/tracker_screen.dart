import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../format.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../tracking.dart';
import '../widgets/common.dart';
import '../widgets/dialogs.dart';
import '../widgets/live_builder.dart';
import '../widgets/quick_switch.dart';
import '../widgets/slide_on_move.dart';
import '../widgets/task_menu.dart';

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
  final _scroll = ScrollController();

  /// The entry whose note is being edited and its task name when editing
  /// began: committing a new name renames the task on its other entries too.
  String? _editEntryId;
  String _editFrom = '';

  /// The running client, to notice when another one starts.
  String? _runningClient;

  /// Tasks shown per client before "N more". Static so it survives tabs.
  static const _taskCap = 3;
  static final _showAllTasks = <String>{};

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

  void _onNoteFocus() {
    if (_noteFocus.hasFocus) {
      final r = _store?.running;
      _editEntryId = r?.id;
      _editFrom = r?.note.trim() ?? '';
    } else {
      _commitNote();
    }
    setState(() {});
  }

  /// An earlier task on [clientId] named [name] apart from case, other than
  /// [except]. Typing its name means that task.
  String? _matchingTask(
    String clientId,
    String name,
    String entryId, {
    String? except,
  }) {
    final lower = name.toLowerCase();
    for (final n in _store!.taskNames(clientId, exceptEntryId: entryId)) {
      if (n != except && n.toLowerCase() == lower) return n;
    }
    return null;
  }

  /// Suggestions for the task field: the running client's earlier tasks
  /// containing [query], any case; those starting with it first.
  Iterable<String> _taskOptions(String query) {
    final r = _store?.running;
    final typed = query.trim();
    final q = typed.toLowerCase();
    if (r == null || q.isEmpty) return const [];
    final names = [
      for (final n in _store!.taskNames(r.clientId, exceptEntryId: r.id))
        if (n != typed && n.toLowerCase().contains(q)) n,
    ];
    return [
      ...names.where((n) => n.toLowerCase().startsWith(q)),
      ...names.where((n) => !n.toLowerCase().startsWith(q)),
    ].take(8);
  }

  /// Picking a suggestion makes the running entry that task.
  void _taskSelected(String task) {
    final r = _store?.running;
    if (r != null) _store!.setNote(r, task);
    _noteFocus.unfocus();
  }

  /// Committing the field's name. If it names an earlier task (any case),
  /// this entry joins that task. Otherwise a changed name renames the task,
  /// not just this entry, so fixing a typo doesn't leave two tasks behind.
  void _commitNote() {
    final id = _editEntryId;
    _editEntryId = null;
    final store = _store;
    final e = id == null ? null : store?.entryById(id);
    if (store == null || e == null) return;
    final from = _editFrom;
    final to = e.note.trim();
    if (to.isEmpty) return;
    final match = _matchingTask(e.clientId, to, e.id, except: from);
    if (match != null) {
      if (match != e.note) store.setNote(e, match);
      return;
    }
    if (from.isEmpty || to == from) return;
    final others = [
      for (final x in store.entries)
        if (x.id != id && x.clientId == e.clientId) x,
    ];
    if (!others.any((x) => x.note.trim() == from)) return;
    final merging = others.any((x) => x.note.trim() == to);
    final (:count, :undo) = store.renameTask(
      e.clientId,
      from,
      to,
      only: others,
    );
    if (count == 0 || !mounted) return;
    toast(
      context,
      merging ? 'Merged “$from” into “$to”' : 'Renamed “$from” to “$to”',
      undo: undo,
    );
  }

  /// Ends the running task and starts a new one on the same client. A name
  /// just typed over the current task's becomes the new task's instead of a
  /// rename; otherwise the new task starts unnamed, ready to type.
  void _newTask() {
    final store = _store!;
    final r = store.running;
    if (r == null) return;
    final typed = r.note.trim();
    final from = _editEntryId == r.id ? _editFrom : typed;
    _editEntryId = null;
    final keep = from.isEmpty ? typed : from;
    if (keep.isEmpty) return;
    // A name typed over the current one (not just recased) is the next
    // task, matched to an earlier task's spelling if it names one.
    final next = from.isNotEmpty && typed.toLowerCase() != from.toLowerCase()
        ? _matchingTask(r.clientId, typed, r.id) ?? typed
        : '';
    if (typed != keep) store.setNote(r, keep);
    final started = store.toggle(r.clientId, note: next);
    if (next.isNotEmpty) {
      _noteFocus.unfocus();
    } else if (_noteFocus.hasFocus) {
      _editEntryId = started?.id;
      _editFrom = '';
    } else {
      _noteFocus.requestFocus();
    }
  }

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

  /// Load the running entry's note into the field when the entry changes,
  /// or when it changed elsewhere (e.g. a task rename) while not editing.
  void _syncNote() {
    final r = _store!.running;
    final note = r?.note ?? '';
    if (r?.id == _noteEntryId && (_noteFocus.hasFocus || _note.text == note)) {
      return;
    }
    _noteEntryId = r?.id;
    _note.text = note;
  }

  @override
  void dispose() {
    _store?.removeListener(_syncNote);
    _note.dispose();
    _noteFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _stop() async {
    _noteFocus.unfocus();
    await stopTracking(context);
  }

  /// Starts/stops [c]; with [task], resumes that task (its note prefilled).
  Future<void> _toggle(Client c, {String? task}) async {
    _noteFocus.unfocus();
    final started = await toggleTracking(context, c, task: task);
    if (started != null && task == null && _autofocusNote && mounted) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _noteFocus.requestFocus(),
      );
    }
  }

  /// The running task, then the most recent ones (all, if expanded).
  /// Collapsed: just the running one.
  List<String> _visibleTasks(
    String clientId,
    List<String> all,
    String? run, {
    required bool collapsed,
  }) {
    final running = run != null && all.contains(run);
    if (collapsed) return [if (running) run];
    // The running task leads; the rest keep most-recent-first order.
    final ordered = running ? [run, ...all.where((t) => t != run)] : all;
    if (_showAllTasks.contains(clientId) || all.length <= _taskCap) {
      return ordered;
    }
    return ordered.take(_taskCap).toList();
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
    Duration? clientTotal, {
    bool? expanded,
  }) {
    final tomorrow = addDays(today, 1);
    Duration totalAt(DateTime t) => task == null
        ? store.totalsIn(today, tomorrow, t)[c.id] ?? Duration.zero
        : store.taskTotalIn(c.id, task, today, tomorrow, t);
    final row = _TrackRow(
      key: ValueKey(task == null ? c.id : '${c.id}/$task'),
      colors: clientScheme(context, c.color),
      label: task ?? c.name,
      name: task == null ? c.name : '${c.name}, $task',
      isTask: task != null,
      running: isRunning,
      total: isRunning ? null : clientTotal ?? totalAt(now),
      liveTotal: isRunning ? totalAt : null,
      onTap: () => _toggle(c, task: task),
      expanded: expanded,
      onExpand: expanded == null
          ? null
          : () => store.setCollapsed([c.id], expanded),
      action: task == null
          ? null
          : TaskRenameButton(clientId: c.id, task: task),
    );
    if (task == null) return row;
    return TaskMenuRegion(
      key: ValueKey('menu ${c.id}/$task'),
      clientId: c.id,
      task: task,
      child: row,
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final running = store.running;
    // Most recently started first, so the running client leads (it started
    // last) and stays near the top after it stops.
    final clients = store.recentClients;
    if (running?.clientId != _runningClient) {
      _runningClient = running?.clientId;
      // Show it arriving at the top.
      if (running != null && _scroll.hasClients && _scroll.offset > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scroll.hasClients) {
            _scroll.animateTo(
              0,
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
            );
          }
        });
      }
    }
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
    final withTasks = [
      for (final c in clients)
        if (tasks[c.id]?.isNotEmpty ?? false) c.id,
    ];
    final anyExpanded = withTasks.any(
      (id) => !store.collapsedClients.contains(id),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Track'),
        actions: [
          if (clients.isNotEmpty)
            IconButton(
              tooltip: 'Quick switch',
              onPressed: () => showQuickSwitch(context),
              icon: const Icon(Icons.search),
            ),
          IconButton(
            tooltip: 'Add client',
            onPressed: () => showAddClient(context),
            icon: const Icon(Icons.person_add_alt),
          ),
          if (withTasks.isNotEmpty)
            IconButton(
              tooltip: anyExpanded ? 'Hide all tasks' : 'Show all tasks',
              onPressed: () => store.setCollapsed(withTasks, anyExpanded),
              icon: Icon(anyExpanded ? Icons.unfold_less : Icons.unfold_more),
            ),
          const SizedBox(width: 8),
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
                  taskOptions: _taskOptions,
                  onTaskSelected: _taskSelected,
                  onNewTask:
                      running != null &&
                          (running.note.trim().isNotEmpty ||
                              (_editEntryId == running.id &&
                                  _editFrom.isNotEmpty))
                      ? _newTask
                      : null,
                  onNoteChanged: (v) {
                    if (running != null) store.setNote(running, v);
                  },
                  todayTotal: (now) => store
                      .totalsIn(today, addDays(today, 1), now)
                      .values
                      .fold(Duration.zero, (a, b) => a + b),
                ),
                Expanded(
                  // A Column, not a ListView: rows keep their state when
                  // reordered, so they can slide to their new place.
                  child: SingleChildScrollView(
                    controller: _scroll,
                    padding: const EdgeInsets.only(bottom: 24),
                    child: SlideStage(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final c in clients)
                            SlideOnMove(
                              key: ValueKey('client ${c.id}'),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _row(
                                    store,
                                    c,
                                    null,
                                    running?.clientId == c.id,
                                    today,
                                    now,
                                    totals[c.id],
                                    expanded: withTasks.contains(c.id)
                                        ? !store.collapsedClients.contains(c.id)
                                        : null,
                                  ),
                                  for (final task in _visibleTasks(
                                    c.id,
                                    tasks[c.id] ?? const [],
                                    running?.clientId == c.id
                                        ? runningTask
                                        : null,
                                    collapsed: store.collapsedClients.contains(
                                      c.id,
                                    ),
                                  ))
                                    SlideOnMove(
                                      key: ValueKey('task ${c.id}/$task'),
                                      child: _row(
                                        store,
                                        c,
                                        task,
                                        running?.clientId == c.id &&
                                            runningTask == task,
                                        today,
                                        now,
                                        null,
                                      ),
                                    ),
                                  if ((tasks[c.id]?.length ?? 0) > _taskCap &&
                                      !store.collapsedClients.contains(c.id))
                                    _MoreTasks(
                                      showingAll: _showAllTasks.contains(c.id),
                                      hidden: tasks[c.id]!.length - _taskCap,
                                      onTap: () => setState(() {
                                        if (!_showAllTasks.remove(c.id)) {
                                          _showAllTasks.add(c.id);
                                        }
                                      }),
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

/// The running entry's task name, suggesting the client's earlier tasks as
/// you type. Tab takes the highlighted suggestion (the first, or the one
/// picked with the arrow keys). Enter keeps what's typed unless the arrow
/// keys were used, so a new name that's part of an old one isn't swapped
/// out.
class _TaskField extends StatefulWidget {
  const _TaskField({
    required this.controller,
    required this.focusNode,
    required this.options,
    required this.onChanged,
    required this.onSubmitted,
    required this.onSelected,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final Iterable<String> Function(String query) options;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmitted;
  final ValueChanged<String> onSelected;

  @override
  State<_TaskField> createState() => _TaskFieldState();
}

class _TaskFieldState extends State<_TaskField> {
  /// Whether the arrow keys moved through the suggestions since the last
  /// edit; only then does Enter take the highlighted one.
  bool _navigated = false;
  bool _selected = false;

  /// Phones have no Tab key to hint at.
  bool get _hasKeyboard =>
      !(defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Widget build(BuildContext context) => RawAutocomplete<String>(
    textEditingController: widget.controller,
    focusNode: widget.focusNode,
    optionsBuilder: (value) => widget.options(value.text),
    onSelected: (task) {
      _selected = true;
      widget.onSelected(task);
    },
    fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) =>
        Focus(
          canRequestFocus: false,
          skipTraversal: true,
          onKeyEvent: (_, event) {
            if (event is! KeyDownEvent) return KeyEventResult.ignored;
            final key = event.logicalKey;
            if (key == LogicalKeyboardKey.arrowDown ||
                key == LogicalKeyboardKey.arrowUp) {
              _navigated = true;
            } else if (key == LogicalKeyboardKey.tab &&
                !HardwareKeyboard.instance.isShiftPressed) {
              // Takes the highlighted suggestion if any are showing;
              // otherwise Tab moves focus as usual.
              _selected = false;
              onFieldSubmitted();
              _navigated = false;
              if (_selected) return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            onChanged: (v) {
              _navigated = false;
              widget.onChanged(v);
            },
            onSubmitted: (_) {
              _selected = false;
              if (_navigated) onFieldSubmitted();
              _navigated = false;
              if (!_selected) widget.onSubmitted();
            },
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(hintText: 'Task name…', isDense: true),
          ),
        ),
    optionsViewBuilder: (context, onSelected, options) {
      final highlighted = AutocompleteHighlightedOption.of(context);
      return Align(
        alignment: Alignment.topLeft,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(8),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240),
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 4),
              shrinkWrap: true,
              children: [
                for (final (i, task) in options.indexed)
                  ListTile(
                    dense: true,
                    title: Text(task),
                    selected: i == highlighted,
                    trailing: i == highlighted && _hasKeyboard
                        ? Text(
                            'Tab',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          )
                        : null,
                    onTap: () => onSelected(task),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// How long the status card takes to grow, shrink and cross-fade.
const _panelAnim = Duration(milliseconds: 250);

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({
    required this.running,
    required this.client,
    required this.note,
    required this.noteFocus,
    required this.onStop,
    required this.onNoteChanged,
    required this.onNoteSubmitted,
    required this.onNewTask,
    required this.taskOptions,
    required this.onTaskSelected,
    required this.todayTotal,
  });

  final Entry? running;
  final Client? client;
  final TextEditingController note;
  final FocusNode noteFocus;
  final VoidCallback onStop;
  final ValueChanged<String> onNoteChanged;
  final VoidCallback onNoteSubmitted;

  /// Null when there's no named task to move on from.
  final VoidCallback? onNewTask;
  final Iterable<String> Function(String query) taskOptions;
  final ValueChanged<String> onTaskSelected;
  final Duration Function(DateTime now) todayTotal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = running;
    final color = client == null
        ? theme.colorScheme.outline
        : Color(client!.color);

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      clipBehavior: Clip.antiAlias,
      // Starting or stopping changes the card's layout: grow or shrink to
      // it while the contents cross-fade, rather than jumping.
      child: AnimatedContainer(
        duration: _panelAnim,
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: color, width: 6)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: AnimatedSize(
          duration: _panelAnim,
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: _panelAnim,
            // Sized by the incoming layout alone, so the card shrinks on
            // stop while the old contents fade (clipped), not after.
            layoutBuilder: (current, previous) => Stack(
              clipBehavior: Clip.none,
              children: [
                for (final p in previous)
                  Positioned(key: p.key, left: 0, right: 0, top: 0, child: p),
                ?current,
              ],
            ),
            child: KeyedSubtree(
              key: ValueKey(r == null),
              // Wraps rather than overflowing with large text.
              child: r == null
                  ? Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        Text(
                          'Not tracking — press ▶ on a client to start',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text.rich(
                          TextSpan(
                            children: [
                              const TextSpan(text: 'Today '),
                              timeSpan(
                                context,
                                fmtHm(todayTotal(DateTime.now())),
                              ),
                            ],
                          ),
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
                            // Shrinks only if it can't fit (large text).
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: LiveBuilder(
                                  builder: (context, now) => Text(
                                    fmtClock(r.durationAt(now)),
                                    style: timeStyle(
                                      context,
                                      theme.textTheme.headlineSmall,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Part of the task field as far as focus goes:
                            // tapping it doesn't first commit the name.
                            TextFieldTapRegion(
                              child: IconButton(
                                tooltip: 'New task',
                                onPressed: onNewTask,
                                icon: const Icon(Icons.add_task),
                              ),
                            ),
                            IconButton.filledTonal(
                              tooltip: 'Stop ${client?.name ?? ''}'.trim(),
                              onPressed: onStop,
                              icon: const Icon(Icons.stop),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        _TaskField(
                          controller: note,
                          focusNode: noteFocus,
                          options: taskOptions,
                          onChanged: onNoteChanged,
                          onSubmitted: onNoteSubmitted,
                          onSelected: onTaskSelected,
                        ),
                        const SizedBox(height: 4),
                        LiveBuilder(
                          builder: (context, now) => DefaultTextStyle.merge(
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            child: Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              spacing: 12,
                              children: [
                                Text.rich(
                                  TextSpan(
                                    children: [
                                      const TextSpan(text: 'Started '),
                                      timeSpan(
                                        context,
                                        fmtTime(context, r.start),
                                      ),
                                    ],
                                  ),
                                ),
                                Text.rich(
                                  TextSpan(
                                    children: [
                                      const TextSpan(text: 'Today '),
                                      timeSpan(context, fmtHm(todayTotal(now))),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TrackRow extends StatelessWidget {
  const _TrackRow({
    super.key,
    required this.colors,
    required this.label,
    required this.name,
    required this.isTask,
    required this.running,
    required this.total,
    required this.liveTotal,
    required this.onTap,
    this.expanded,
    this.onExpand,
    this.action,
  });

  /// From the client's color.
  final ColorScheme colors;
  final String label;

  /// What the buttons act on, for their tooltips: the client, and the task.
  final String name;
  final bool isTask;
  final bool running;
  final Duration? total;
  final Duration Function(DateTime now)? liveTotal;
  final VoidCallback onTap;

  /// Client rows with tasks: whether they're shown, and the toggle.
  final bool? expanded;
  final VoidCallback? onExpand;

  /// Task rows: the button in the expand button's place (rename).
  final Widget? action;

  /// Room for the expand button, kept on every row so totals line up.
  static const _expandW = 48.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = timeStyle(context, theme.textTheme.bodyMedium).copyWith(
      color: running ? null : theme.colorScheme.onSurfaceVariant,
      fontWeight: running ? FontWeight.w600 : null,
    );

    // Only the play/stop button starts and stops, not the whole row. Its
    // touch target is the usual 48px around the circle (less on compact
    // desktop density); the padding and gaps keep circles and labels aligned.
    final size = isTask ? 24.0 : 36.0;
    return ListTile(
      dense: isTask,
      selected: running,
      selectedTileColor: colors.primary.withValues(alpha: isTask ? 0.08 : 0.12),
      selectedColor: theme.colorScheme.onSurface,
      // Task play buttons line up under the client name.
      contentPadding: EdgeInsets.only(left: isTask ? 52 : 10, right: 16),
      horizontalTitleGap: isTask ? 8 : 10,
      leading: IconButton(
        tooltip: running ? 'Stop $name' : 'Start $name',
        onPressed: onTap,
        iconSize: isTask ? 16 : 24,
        style: IconButton.styleFrom(
          backgroundColor: running
              ? colors.primary
              : colors.primary.withValues(alpha: 0.12),
          foregroundColor: running ? colors.onPrimary : colors.primary,
          minimumSize: Size.square(size),
          fixedSize: Size.square(size),
          padding: EdgeInsets.zero,
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
        icon: Icon(running ? Icons.stop : Icons.play_arrow),
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
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          liveTotal != null
              ? LiveBuilder(
                  builder: (context, now) =>
                      Text(fmtHm(liveTotal!(now)), style: style),
                )
              : Text(total == Duration.zero ? '' : fmtHm(total!), style: style),
          SizedBox(
            width: _expandW,
            child: onExpand == null
                ? action
                : Semantics(
                    expanded: expanded,
                    child: IconButton(
                      tooltip: expanded!
                          ? 'Hide $name tasks'
                          : 'Show $name tasks',
                      onPressed: onExpand,
                      icon: Chevron(open: expanded!),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// "N more" / "Show less" under a client's tasks.
class _MoreTasks extends StatelessWidget {
  const _MoreTasks({
    required this.showingAll,
    required this.hidden,
    required this.onTap,
  });

  final bool showingAll;
  final int hidden;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Padding(
      padding: const EdgeInsets.only(left: 52),
      child: TextButton.icon(
        onPressed: onTap,
        icon: Icon(
          showingAll ? Icons.expand_less : Icons.expand_more,
          size: 18,
        ),
        label: Text(showingAll ? 'Show less' : '$hidden more'),
      ),
    ),
  );
}
