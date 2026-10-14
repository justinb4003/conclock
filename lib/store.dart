import 'dart:async';
import 'dart:convert';

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

  /// Log shows durations as decimal hours (1.50) instead of h:mm.
  bool decimalHours = false;

  /// Timesheet rounding (up to the next half hour).
  Rounding rounding = Rounding.off;

  Timer? _saveTimer;
  bool _dirty = false;
  Future<void> _writing = Future.value();

  String get storageLocation => _storage.location;

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
      if (raw == null || raw.trim().isEmpty) return;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      clients
        ..clear()
        ..addAll([
          for (final c in data['clients'] as List? ?? const [])
            Client.fromJson(c as Map<String, dynamic>),
        ]);
      entries
        ..clear()
        ..addAll([
          for (final e in data['entries'] as List? ?? const [])
            Entry.fromJson(e as Map<String, dynamic>),
        ]);
      _sort();
      final settings = data['settings'] as Map<String, dynamic>? ?? const {};
      decimalHours = settings['decimalHours'] as bool? ?? false;
      rounding =
          Rounding.values.asNameMap()[settings['rounding']] ?? Rounding.off;
    } catch (e) {
      clients.clear();
      entries.clear();
      loadError =
          'Saved data could not be read, so a backup copy was kept '
          'and ConClock started fresh. ($e)';
      try {
        await _storage.backupCorrupt();
      } catch (_) {}
    }
  }

  Map<String, dynamic> toJson() => {
    'version': 1,
    'settings': {'decimalHours': decimalHours, 'rounding': rounding.name},
    'clients': [for (final c in clients) c.toJson()],
    'entries': [for (final e in entries) e.toJson()],
  };

  // ----------------------------------------------------------------- saving

  void _changed() {
    _dirty = true;
    notifyListeners();
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), flush);
  }

  /// Writes pending changes now. Writes are serialized.
  Future<void> flush() {
    _saveTimer?.cancel();
    _saveTimer = null;
    if (!_dirty) return _writing;
    _dirty = false;
    final json = const JsonEncoder.withIndent('  ').convert(toJson());
    return _writing = _writing
        .then((_) => _storage.write(json))
        .catchError((Object e) => debugPrint('ConClock: save failed: $e'));
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

  int entryCount(String clientId) =>
      entries.where((e) => e.clientId == clientId).length;

  /// Entries that started in [from, to), newest first.
  Iterable<Entry> entriesIn(DateTime from, DateTime to) =>
      entries.where((e) => !e.start.isBefore(from) && e.start.isBefore(to));

  /// Total time per client for entries that started in [from, to).
  Map<String, Duration> totalsIn(DateTime from, DateTime to, DateTime now) {
    final totals = <String, Duration>{};
    for (final e in entriesIn(from, to)) {
      totals[e.clientId] =
          (totals[e.clientId] ?? Duration.zero) + e.durationAt(now);
    }
    return totals;
  }

  // --------------------------------------------------------------- settings

  void setDecimalHours(bool v) {
    if (decimalHours == v) return;
    decimalHours = v;
    _changed();
  }

  /// Distinct task names (notes) per client from finished entries that ended
  /// within [recentTaskWindow], most recently started first.
  Map<String, List<String>> recentTasks(DateTime now) {
    final cutoff = now.subtract(recentTaskWindow);
    final tasks = <String, List<String>>{};
    final seen = <String, Set<String>>{};
    for (final e in entries) {
      // Sorted by start; nothing older can still end inside the window.
      if (e.start.isBefore(cutoff.subtract(const Duration(days: 2)))) break;
      final end = e.end;
      final note = e.note.trim();
      if (end == null || end.isBefore(cutoff) || note.isEmpty) continue;
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
    entries.insert(0, e);
    _changed();
    return e;
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

  void setNote(Entry e, String note) {
    if (e.note == note) return;
    e.note = note;
    _changed();
  }

  // ----------------------------------------------------------------- entries

  void addEntry(Entry e) {
    entries.add(e);
    _sort();
    _changed();
  }

  void updateEntry(
    Entry e, {
    required String clientId,
    required DateTime start,
    required DateTime? end,
    required String note,
  }) {
    e
      ..clientId = clientId
      ..start = start
      ..end = end
      ..note = note;
    _sort();
    _changed();
  }

  void deleteEntry(Entry e) {
    entries.remove(e);
    _changed();
  }

  void _sort() => entries.sort((a, b) => b.start.compareTo(a.start));

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

  void renameClient(Client c, String name) {
    c.name = name.trim();
    _changed();
  }

  void setClientColor(Client c, int color) {
    c.color = color;
    _changed();
  }

  void setArchived(Client c, bool archived) {
    c.archived = archived;
    final r = running;
    if (archived && r != null && r.clientId == c.id) _stopEntry(r, now());
    _changed();
  }

  /// Deletes the client and all of its entries.
  void deleteClient(Client c) {
    clients.remove(c);
    entries.removeWhere((e) => e.clientId == c.id);
    _changed();
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
