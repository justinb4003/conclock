import 'dart:convert';

import 'package:conclock/models.dart';
import 'package:conclock/storage/storage.dart';
import 'package:conclock/store.dart';
import 'package:flutter_test/flutter_test.dart';

class MemoryStorage extends DataStorage {
  String? data;

  @override
  String get location => 'memory';

  @override
  Future<String?> read() async => data;

  @override
  Future<void> write(String d) async => data = d;

  final copies = <String, String?>{};

  @override
  Future<void> keepCopy(String tag, String? data) async => copies[tag] = data;

  void Function(String)? onChange;

  @override
  void watch(void Function(String data) onChange) => this.onChange = onChange;
}

void main() {
  late DateTime t;
  late MemoryStorage storage;
  late AppStore store;

  setUp(() {
    t = DateTime(2026, 10, 12, 9);
    storage = MemoryStorage();
    store = AppStore(storage: storage, clock: () => t);
  });

  test('toggle starts, switches and stops', () {
    final a = store.addClient('Acme');
    final b = store.addClient('Globex');

    store.toggle(a.id);
    expect(store.running?.clientId, a.id);

    t = t.add(const Duration(hours: 1));
    store.toggle(b.id);
    expect(store.running?.clientId, b.id);
    expect(store.entries.length, 2);

    t = t.add(const Duration(minutes: 30));
    store.toggle(b.id);
    expect(store.running, isNull);

    final totals = store.totalsIn(
      DateTime(2026, 10, 12),
      DateTime(2026, 10, 13),
      t,
    );
    expect(totals[a.id], const Duration(hours: 1));
    expect(totals[b.id], const Duration(minutes: 30));
  });

  test('short unnamed entries are kept; same-second ones dropped', () {
    final a = store.addClient('Acme');
    store.toggle(a.id);
    store.toggle(a.id); // same second
    expect(store.entries, isEmpty);

    store.toggle(a.id);
    t = t.add(const Duration(seconds: 5));
    store.stop();
    expect(store.entries.length, 1);
  });

  test('stop time comes from when the user acted', () {
    final a = store.addClient('Acme');
    store.toggle(a.id);
    final clicked = t.add(const Duration(minutes: 30));
    t = clicked.add(const Duration(minutes: 2)); // time spent in a prompt
    store.stop(at: clicked);
    expect(store.entries.single.end, clicked);
  });

  test('round-trips through JSON storage', () async {
    final a = store.addClient('Acme');
    store.toggle(a.id);
    store.setNote(store.running!, 'Kickoff "notes"');
    store.setDecimalHours(true);
    store.setRounding(Rounding.day);
    await store.flush();

    final reloaded = AppStore(storage: storage);
    await reloaded.load();
    expect(reloaded.clients.single.name, 'Acme');
    expect(reloaded.running?.note, 'Kickoff "notes"');
    expect(reloaded.running?.start, DateTime(2026, 10, 12, 9));
    expect(reloaded.decimalHours, isTrue);
    expect(reloaded.rounding, Rounding.day);
    expect(jsonDecode(storage.data!)['version'], 1);
  });

  test('recent tasks: distinct notes, newest first, 28-day window', () {
    final a = store.addClient('Acme');
    void work(String note, Duration length) {
      store.toggle(a.id);
      store.setNote(store.running!, note);
      t = t.add(length);
      store.stop();
    }

    work('Old audit', const Duration(hours: 1));
    t = t.add(const Duration(days: 20));
    work('Workshop', const Duration(hours: 1));
    work('Report', const Duration(hours: 1));
    work('Workshop', const Duration(hours: 1));
    store.toggle(a.id); // running, no note: not a task
    store.setNote(store.running!, 'Typing in progress');

    expect(store.recentTasks(t)[a.id], ['Workshop', 'Report', 'Old audit']);
    t = t.add(const Duration(minutes: 5));
    store.stop();

    // Old audit last ended 28 days + a bit ago.
    t = t.add(const Duration(days: 8, hours: 1));
    expect(store.recentTasks(t)[a.id], [
      'Typing in progress',
      'Workshop',
      'Report',
    ]);
  });

  test('resuming a task starts it with its note; tapping again stops', () {
    final a = store.addClient('Acme');
    final b = store.addClient('Globex');
    store.toggle(b.id);
    t = t.add(const Duration(hours: 1));

    final e = store.toggle(a.id, note: 'Workshop');
    expect(e?.note, 'Workshop');
    expect(store.running?.clientId, a.id);

    t = t.add(const Duration(hours: 1));
    store.toggle(a.id, note: 'Report'); // switch tasks within a client
    expect(store.running?.note, 'Report');

    t = t.add(const Duration(hours: 1));
    expect(store.toggle(a.id, note: 'Report'), isNull);
    expect(store.running, isNull);
    expect(
      store.taskTotalIn(a.id, 'Workshop', DateTime(2026), DateTime(2027), t),
      const Duration(hours: 1),
    );
  });

  test('adopts data saved by another tab', () async {
    await store.load();
    final other = AppStore(storage: MemoryStorage());
    other.addClient('From other tab');
    var notified = false;
    store.addListener(() => notified = true);

    storage.onChange!(jsonEncode(other.toJson()));
    expect(store.clients.single.name, 'From other tab');
    expect(notified, isTrue);

    storage.onChange!('{garbage'); // ignored, state kept
    expect(store.clients.single.name, 'From other tab');
  });

  test('export then import round-trips and keeps a pre-import copy', () async {
    final a = store.addClient('Acme');
    store.toggle(a.id, note: 'Design');
    t = t.add(const Duration(hours: 2));
    store.stop();
    store.setRounding(Rounding.task);
    final backup = store.exportJson();

    final otherStorage = MemoryStorage();
    final target = AppStore(storage: otherStorage)..addClient('Doomed');
    await target.importJson(backup);

    expect(target.clients.single.name, 'Acme');
    expect(target.entries.single.note, 'Design');
    expect(target.rounding, Rounding.task);
    expect(otherStorage.copies['pre-import'], contains('Doomed'));
    await target.flush();
    expect(otherStorage.data, contains('Design'));
  });

  test('importing a bad file changes nothing', () async {
    store.addClient('Keep me');
    for (final bad in [
      'not json',
      '[]',
      '{"entries": []}',
      '{"clients": [{"id": 1}]}',
    ]) {
      await expectLater(store.importJson(bad), throwsA(anything));
      expect(store.clients.single.name, 'Keep me');
    }
    expect(storage.copies, isEmpty);
  });

  test('edits through stale objects reach the reloaded data', () async {
    await store.load();
    final a = store.addClient('Acme');
    store.toggle(a.id, note: 'Design');
    final staleEntry = store.running!;
    final staleClient = store.clients.single;

    // Another tab saves the same data: objects get replaced.
    storage.onChange!(jsonEncode(store.toJson()));
    expect(identical(store.running, staleEntry), isFalse);

    store.setNote(staleEntry, 'Design review');
    store.renameClient(staleClient, 'Acme Corp');
    expect(store.running!.note, 'Design review');
    expect(store.clients.single.name, 'Acme Corp');

    t = t.add(const Duration(hours: 1));
    store.stop();
    store.deleteEntry(staleEntry);
    expect(store.entries, isEmpty);
  });

  test('undo restores deleted entries and clients', () {
    final a = store.addClient('Acme');
    final b = store.addClient('Globex');
    store.toggle(a.id, note: 'Design');
    t = t.add(const Duration(hours: 1));
    store.toggle(b.id, note: 'Call');
    t = t.add(const Duration(hours: 1));
    store.stop();

    final undoEntry = store.deleteEntry(store.entries.last); // Design
    expect(store.entries.length, 1);
    undoEntry();
    expect(store.entries.map((e) => e.note), ['Call', 'Design']);

    final undoClient = store.deleteClient(a);
    expect(store.clients.map((c) => c.name), ['Globex']);
    expect(store.entries.single.note, 'Call');
    undoClient();
    expect(store.clients.map((c) => c.name), ['Acme', 'Globex']);
    expect(store.entries.length, 2);
  });

  test('undoing a running entry\'s delete doesn\'t leave two running', () {
    final a = store.addClient('Acme');
    store.toggle(a.id);
    t = t.add(const Duration(minutes: 5));
    final undo = store.deleteEntry(store.running!);
    store.toggle(a.id, note: 'Other');
    t = t.add(const Duration(minutes: 5));
    undo();
    expect(store.entries.where((e) => e.isRunning).length, 1);
    expect(store.running!.note, 'Other');
  });

  test('finds overlapping entries', () {
    final a = store.addClient('Acme');
    store.toggle(a.id, note: 'Morning'); // 9:00-10:00
    t = t.add(const Duration(hours: 1));
    store.stop();
    DateTime at(int h, [int m = 0]) => DateTime(2026, 10, 12, h, m);

    expect(store.overlapping(at(9, 30), at(11)).single.note, 'Morning');
    expect(store.overlapping(at(10), at(11)), isEmpty); // touching is fine
    expect(store.overlapping(at(8), at(9)), isEmpty);
    final morning = store.entries.single;
    expect(store.overlapping(at(9), at(10), exceptId: morning.id), isEmpty);
  });

  test('corrupt data does not crash load', () async {
    storage.data = '{not json';
    await store.load();
    expect(store.loadError, isNotNull);
    expect(storage.copies.containsKey('corrupt'), isTrue);
    expect(store.clients, isEmpty);
  });
}
