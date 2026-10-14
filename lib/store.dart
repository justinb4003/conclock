import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'models.dart';
import 'storage/storage.dart';

/// How long a task (an entry's note) stays listed under its client on the
/// Track screen after it was last worked on.
const recentTaskWindow = Duration(days: 28);

/// All app state. Every mutation notifies listeners and schedules a save.
class AppStore extends ChangeNotifier {
  AppStore({DataStorage? storage, DateTime Function()? clock})
    : _storage = storage ?? createStorage(),
      _clock = clock ?? DateTime.now;

  final DataStorage _storage;
  final DateTime Function() _clock;

  final List<Client> clients = [];

  /// Sorted newest first.
  final List<Entry> entries = [];

  String? loadError;

  /// Why the last save failed (e.g. storage full), until one succeeds.
  String? saveError;

  /// Something the user should hear once (shown as a toast), e.g. that
  /// edits were set aside because another instance saved first.
  String? _notice;

  /// The edits most recently set aside that way, for exporting (on the web
  /// the side copy is otherwise out of reach).
  String? setAside;

  /// The pending notice, if any; clears it.
  String? takeNotice() {
    final n = _notice;
    _notice = null;
    return n;
  }

  /// Log shows durations as decimal hours (1.50) instead of h:mm.
  bool decimalHours = false;

  /// Timesheet rounding (up to the next half hour).
  Rounding rounding = Rounding.off;

  /// Desktop: closing the window hides it to the tray instead of quitting.
  bool closeToTray = true;

  /// Show times and durations in a monospace font.
  bool monoTimes = false;

  Timer? _saveTimer;
  bool _dirty = false;
  Future<void> _writing = Future.value();

  String get storageLocation => _storage.location;

  bool get canChooseDataFolder => _storage.canRelocate;

  bool get dataInDefaultFolder => _storage.isDefaultLocation;

  Future<bool> hasDataIn(String dir) => _storage.hasDataAt(dir);

  /// Keeps data in [dir] from now on (null: the default place). With
  /// [useExisting], loads the data already there; otherwise writes ours
  /// there. Either way the data being dropped is kept as a side copy.
  Future<void> moveDataTo(String? dir, {required bool useExisting}) async {
    final ours = jsonEncode(toJson());
    await flush();
    await _writing;
    if (useExisting) {
      final previous = _storage.folder;
      await _storage.keepCopy('before-switch', ours);
      await _storage.relocate(dir);
      try {
        final raw = await _storage.read();
        if (raw != null) _apply(raw);
      } catch (_) {
        await _storage.relocate(previous); // unreadable: stay where we were
        rethrow;
      }
      notifyListeners();
    } else {
      await _storage.relocate(dir);
      if (await _storage.read() != null) {
        await _storage.keepCopy('replaced', null);
      }
      _changed();
      await flush();
    }
  }

  /// Current time truncated to whole seconds.
  DateTime now() {
    final t = _clock();
    return DateTime.fromMillisecondsSinceEpoch(
      t.millisecondsSinceEpoch ~/ 1000 * 1000,
    );
  }

  // ---------------------------------------------------------------- loading

  Future<void> load() async {
    try {
      final raw = await _storage.read();
      if (raw != null && raw.trim().isNotEmpty) _apply(raw);
    } catch (e) {
      clients.clear();
      entries.clear();
      loadError =
          'Saved data could not be read, so a backup copy was kept '
          'and ConClock started fresh. ($e)';
      try {
        await _storage.keepCopy('corrupt', null);
      } catch (_) {}
    }
    loadError ??= _storage.warning;
    // Another browser tab saved: adopt its data so we don't overwrite it.
    _storage.watch((raw) {
      try {
        final unsaved = _dirty ? exportJson() : null;
        _apply(raw);
        _dirty = false;
        _saveTimer?.cancel();
        _saveTimer = null;
        if (unsaved != null) {
          setAside = unsaved;
          // Edits made here moments ago lose to the other writer; keep them
          // on the side rather than dropping them silently.
          _notice =
              'Your data changed elsewhere while you had unsaved edits here. '
              'Those edits were set aside as a backup copy.';
          _storage.keepCopy('unsaved', unsaved).catchError((Object e) {
            debugPrint('ConClock: could not keep unsaved copy: $e');
          });
        }
        notifyListeners();
      } catch (e) {
        debugPrint('ConClock: ignoring unreadable external change: $e');
      }
    });
  }

  /// Replaces all state with [raw]. Parses everything first, so on a bad
  /// document it throws and leaves the current state untouched.
  void _apply(String raw) {
    final data = jsonDecode(raw);
    if (data is! Map<String, dynamic> || data['clients'] is! List) {
      throw const FormatException('Not a ConClock data file');
    }
    final newClients = [
      for (final c in data['clients'] as List)
        Client.fromJson(c as Map<String, dynamic>),
    ];
    final newEntries = [
      for (final e in data['entries'] as List? ?? const [])
        Entry.fromJson(e as Map<String, dynamic>),
    ];
    final settings = data['settings'] as Map<String, dynamic>? ?? const {};
    clients
      ..clear()
      ..addAll(newClients);
    entries
      ..clear()
      ..addAll(newEntries);
    _sort();
    decimalHours = settings['decimalHours'] as bool? ?? false;
    rounding =
        Rounding.values.asNameMap()[settings['rounding']] ?? Rounding.off;
    closeToTray = settings['closeToTray'] as bool? ?? true;
    monoTimes = settings['monoTimes'] as bool? ?? false;
  }

  // ------------------------------------------------------------- backups

  /// Everything, as a pretty-printed JSON backup.
  String exportJson() => const JsonEncoder.withIndent('  ').convert(toJson());

  /// Replaces all data with a backup. The current data is kept as a copy
  /// first. Throws [FormatException] (changing nothing) if [raw] isn't a
  /// ConClock backup.
  Future<void> importJson(String raw) async {
    final previous = jsonEncode(toJson());
    _apply(raw); // throws before changing anything if raw is bad
    _changed();
    try {
      await _storage.keepCopy('pre-import', previous);
    } catch (e) {
      debugPrint('ConClock: could not keep pre-import copy: $e');
    }
  }

  Map<String, dynamic> toJson() => {
    'version': 1,
    'settings': {
      'decimalHours': decimalHours,
      'rounding': rounding.name,
      'closeToTray': closeToTray,
      'monoTimes': monoTimes,
    },
    'clients': [for (final c in clients) c.toJson()],
    'entries': [for (final e in entries) e.toJson()],
  };

  // ----------------------------------------------------------------- saving

  void _changed() {
    _dirty = true;
    notifyListeners();
    _saveTimer?.cancel();
    // Batched so typing doesn't re-save everything per keystroke; the app
    // flushes when hidden or closed (see main.dart).
    _saveTimer = Timer(const Duration(milliseconds: 400), flush);
  }

  /// Writes pending changes now. Writes are serialized.
  Future<void> flush() {
    _saveTimer?.cancel();
    _saveTimer = null;
    if (!_dirty) return _writing;
    _dirty = false;
    final json = kIsWeb
        ? jsonEncode(toJson()) // nobody reads it by eye there
        : const JsonEncoder.withIndent('  ').convert(toJson());
    return _writing = _writing
        .then((_) => _storage.write(json))
        .then(
          (_) => _setSaveError(null),
          onError: (Object e) {
            debugPrint('ConClock: save failed: $e');
            _setSaveError('$e');
            _dirty = true; // retried on the next change or flush
          },
        );
  }

  void _setSaveError(String? e) {
    if (saveError == e) return;
    saveError = e;
    notifyListeners();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------- queries

  Entry? get running {
    for (final e in entries) {
      if (e.isRunning) return e;
    }
    return null;
  }

  Iterable<Client> get activeClients => clients.where((c) => !c.archived);

  Client? clientById(String id) {
    for (final c in clients) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Entries whose time overlaps [start, end), other than [exceptId].
  List<Entry> overlapping(
    DateTime start,
    DateTime end, {
    String? exceptId,
    DateTime? now,
  }) {
    final t = now ?? this.now();
    return [
      for (final e in entries)
        if (e.id != exceptId &&
            e.start.isBefore(end) &&
            (e.end ?? t).isAfter(start))
          e,
    ];
  }

  /// Sorts client ids into the user's client order (unknown ids last).
  List<String> inClientOrder(Iterable<String> ids) {
    final rank = {for (var i = 0; i < clients.length; i++) clients[i].id: i};
    return ids.toList()..sort(
      (a, b) =>
          (rank[a] ?? clients.length).compareTo(rank[b] ?? clients.length),
    );
  }

  int entryCount(String clientId) =>
      entries.where((e) => e.clientId == clientId).length;

  /// Entries that started in [from, to), newest first.
  Iterable<Entry> entriesIn(DateTime from, DateTime to) =>
      entries.skip(_firstBefore(to)).takeWhile((e) => !e.start.isBefore(from));

  /// Whether any entry started before [t].
  bool hasEntriesBefore(DateTime t) => _firstBefore(t) < entries.length;

  /// Total time per client for entries that started in [from, to).
  Map<String, Duration> totalsIn(DateTime from, DateTime to, DateTime now) {
    final totals = <String, Duration>{};
    for (final e in entriesIn(from, to)) {
      totals[e.clientId] =
          (totals[e.clientId] ?? Duration.zero) + e.durationAt(now);
    }
    return totals;
  }

  /// Distinct task names (notes) per client from finished entries that ended
  /// within [recentTaskWindow], most recently started first.
  ///
  /// Looks at every entry: one can start long before the window and still
  /// end inside it (a timer left running over a weekend, a long manual
  /// entry), and the scan is a few comparisons per entry.
  Map<String, List<String>> recentTasks(DateTime now) {
    final cutoff = now.subtract(recentTaskWindow);
    final tasks = <String, List<String>>{};
    final seen = <String, Set<String>>{};
    for (final e in entries) {
      final end = e.end;
      if (end == null || end.isBefore(cutoff)) continue;
      final note = e.note.trim();
      if (note.isEmpty) continue;
      if (seen.putIfAbsent(e.clientId, () => {}).add(note)) {
        tasks.putIfAbsent(e.clientId, () => []).add(note);
      }
    }
    return tasks;
  }

  /// Time on one task for entries that started in [from, to).
  Duration taskTotalIn(
    String clientId,
    String note,
    DateTime from,
    DateTime to,
    DateTime now,
  ) {
    var total = Duration.zero;
    for (final e in entriesIn(from, to)) {
      if (e.clientId == clientId && e.note.trim() == note) {
        total += e.durationAt(now);
      }
    }
    return total;
  }

  // --------------------------------------------------------------- settings

  void setDecimalHours(bool v) {
    if (decimalHours == v) return;
    decimalHours = v;
    _changed();
  }

  void setCloseToTray(bool v) {
    if (closeToTray == v) return;
    closeToTray = v;
    _changed();
  }

  void setMonoTimes(bool v) {
    if (monoTimes == v) return;
    monoTimes = v;
    _changed();
  }

  void setRounding(Rounding v) {
    if (rounding == v) return;
    rounding = v;
    _changed();
  }

  // ---------------------------------------------------------------- tracking

  /// Starts [clientId], or stops it if it's already running. Any other
  /// running client is stopped first. Returns the new running entry, if any.
  ///
  /// With [note], resumes that task: it stops only if that same task is the
  /// one running, otherwise it starts a new entry carrying the note.
  ///
  /// [at] is when the user acted (defaults to now), so time spent answering
  /// a prompt isn't billed.
  Entry? toggle(String clientId, {String? note, DateTime? at}) {
    final t = at ?? now();
    final r = running;
    if (r != null) {
      _stopEntry(r, t);
      if (r.clientId == clientId && (note == null || r.note.trim() == note)) {
        _changed();
        return null;
      }
    }
    final e = Entry(
      id: newId(),
      clientId: clientId,
      start: t,
      note: note ?? '',
    );
    _insertSorted(e);
    _changed();
    return e;
  }

  /// Takes [from]..now out of the running entry: it ends at [from] and the
  /// same client/task carries on in a new entry starting now.
  void removeGap(DateTime from) {
    final r = running;
    if (r == null) return;
    final t = now();
    _stopEntry(r, from.isBefore(r.start) ? r.start : from);
    _insertSorted(
      Entry(id: newId(), clientId: r.clientId, start: t, note: r.note),
    );
    _changed();
  }

  void stop({DateTime? at}) {
    final r = running;
    if (r == null) return;
    _stopEntry(r, at ?? now());
    _changed();
  }

  void _stopEntry(Entry e, DateTime t) {
    e.end = t;
    // Started and stopped within the same second: nothing to keep.
    if (!e.end!.isAfter(e.start)) entries.remove(e);
  }

  /// [e] as currently held. Objects get replaced when another tab or window's
  /// save is adopted, so callers holding older ones (e.g. an open dialog)
  /// still act on the right entry.
  Entry? _liveEntry(Entry e) => entries.contains(e) ? e : entryById(e.id);

  Entry? entryById(String id) {
    for (final x in entries) {
      if (x.id == id) return x;
    }
    return null;
  }

  Client? _liveClient(Client c) => clients.contains(c) ? c : clientById(c.id);

  bool hasTask(String clientId, String task) =>
      entries.any((e) => e.clientId == clientId && e.note.trim() == task);

  /// Renames task [from] to [to] on [clientId]'s entries (all of them, or
  /// just those in [only]). Renaming onto an existing task merges the two.
  /// Returns how many entries changed and a function that undoes it.
  ({int count, VoidCallback undo}) renameTask(
    String clientId,
    String from,
    String to, {
    Iterable<Entry>? only,
  }) {
    final targets = [
      for (final e in only ?? entries)
        if (_liveEntry(e) case final live?)
          if (live.clientId == clientId && live.note.trim() == from) live,
    ];
    final before = {for (final e in targets) e.id: e.note};
    for (final e in targets) {
      e.note = to.trim();
    }
    _changed();
    return (
      count: targets.length,
      undo: () {
        before.forEach((id, note) => entryById(id)?.note = note);
        _changed();
      },
    );
  }

  void setNote(Entry stale, String note) {
    final e = _liveEntry(stale);
    if (e == null || e.note == note) return;
    e.note = note;
    _changed();
  }

  // ----------------------------------------------------------------- entries

  void addEntry(Entry e) {
    entries.add(e);
    _sort();
    _changed();
  }

  /// Saves edits to [stale]; if it was deleted meanwhile, adds it back.
  void updateEntry(
    Entry stale, {
    required String clientId,
    required DateTime start,
    required DateTime? end,
    required String note,
  }) {
    final e = _liveEntry(stale) ?? stale;
    if (!entries.contains(e)) entries.add(e);
    e
      ..clientId = clientId
      ..start = start
      ..end = end
      ..note = note;
    _sort();
    _changed();
  }

  /// Deletes [stale]'s entry. Returns a function that undoes it.
  VoidCallback deleteEntry(Entry stale) {
    final e = _liveEntry(stale);
    if (e == null) return () {};
    entries.remove(e);
    _changed();
    return () => _restore([e]);
  }

  /// Puts deleted entries back (skipping any that reappeared meanwhile). A
  /// restored running entry stops now if something else started since.
  void _restore(List<Entry> deleted) {
    for (final e in deleted) {
      if (entryById(e.id) != null) continue;
      if (e.isRunning && running != null) e.end = now();
      entries.add(e);
    }
    _sort();
    _changed();
  }

  void _sort() => entries.sort((a, b) => b.start.compareTo(a.start));

  /// Usually at the front, but a manual entry may start later.
  void _insertSorted(Entry e) => entries.insert(_firstBefore(e.start), e);

  /// Index of the first (newest) entry that started before [t]; entries are
  /// sorted newest first, so everything from there on did too.
  int _firstBefore(DateTime t) {
    var lo = 0, hi = entries.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (entries[mid].start.isBefore(t)) {
        hi = mid;
      } else {
        lo = mid + 1;
      }
    }
    return lo;
  }

  // ----------------------------------------------------------------- clients

  Client addClient(String name) {
    final used = clients.map((c) => c.color).toSet();
    final color = clientPalette.firstWhere(
      (c) => !used.contains(c),
      orElse: () => clientPalette[clients.length % clientPalette.length],
    );
    final c = Client(id: newId(), name: name.trim(), color: color);
    clients.add(c);
    _changed();
    return c;
  }

  void renameClient(Client stale, String name) {
    final c = _liveClient(stale);
    if (c == null) return;
    c.name = name.trim();
    _changed();
  }

  void setClientColor(Client stale, int color) {
    final c = _liveClient(stale);
    if (c == null) return;
    c.color = color;
    _changed();
  }

  void setArchived(Client stale, bool archived) {
    final c = _liveClient(stale);
    if (c == null) return;
    c.archived = archived;
    final r = running;
    if (archived && r != null && r.clientId == c.id) _stopEntry(r, now());
    _changed();
  }

  /// Deletes the client and all of its entries. Returns a function that
  /// undoes it.
  VoidCallback deleteClient(Client stale) {
    final c = _liveClient(stale);
    if (c == null) return () {};
    final index = clients.indexOf(c);
    final removed = entries.where((e) => e.clientId == c.id).toList();
    clients.remove(c);
    entries.removeWhere((e) => e.clientId == c.id);
    _changed();
    return () {
      if (clientById(c.id) == null) {
        clients.insert(index.clamp(0, clients.length), c);
      }
      _restore(removed);
    };
  }

  void moveClient(int from, int to) {
    final c = clients.removeAt(from);
    clients.insert(to, c);
    _changed();
  }
}

/// Makes the [AppStore] available to the tree; dependents rebuild on change.
class StoreScope extends InheritedNotifier<AppStore> {
  const StoreScope({super.key, required AppStore store, required super.child})
    : super(notifier: store);

  static AppStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StoreScope>()!.notifier!;

  /// Access without subscribing to rebuilds (for callbacks).
  static AppStore read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<StoreScope>()!.notifier!;
}
