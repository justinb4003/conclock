import 'dart:math';

/// Colors offered for clients (ARGB).
const clientPalette = <int>[
  0xFF1E88E5, // blue
  0xFF43A047, // green
  0xFFE53935, // red
  0xFFFB8C00, // orange
  0xFF8E24AA, // purple
  0xFF00ACC1, // cyan
  0xFFD81B60, // pink
  0xFF6D4C41, // brown
  0xFF3949AB, // indigo
  0xFF7CB342, // light green
  0xFFFDD835, // yellow
  0xFF546E7A, // blue grey
];

/// How the timesheet rounds hours: not at all, each task's daily time, or
/// each client's daily total — always up to the next half hour.
enum Rounding { off, task, day }

final _rng = Random();

String newId() =>
    DateTime.now().microsecondsSinceEpoch.toRadixString(36) +
    _rng.nextInt(1 << 30).toRadixString(36);

class Client {
  Client({
    required this.id,
    required this.name,
    required this.color,
    this.archived = false,
  });

  final String id;
  String name;
  int color;
  bool archived;

  factory Client.fromJson(Map<String, dynamic> j) => Client(
    id: j['id'] as String,
    name: j['name'] as String? ?? '',
    color: (j['color'] as num?)?.toInt() ?? clientPalette.last,
    archived: j['archived'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'color': color,
    'archived': archived,
  };
}

/// A block of time spent on a client. [end] is null while running.
class Entry {
  Entry({
    required this.id,
    required this.clientId,
    required this.start,
    this.end,
    this.note = '',
  });

  final String id;
  String clientId;
  DateTime start;
  DateTime? end;
  String note;

  bool get isRunning => end == null;

  Duration durationAt(DateTime now) {
    final d = (end ?? now).difference(start);
    return d.isNegative ? Duration.zero : d;
  }

  factory Entry.fromJson(Map<String, dynamic> j) => Entry(
    id: j['id'] as String,
    clientId: j['clientId'] as String,
    start: DateTime.parse(j['start'] as String).toLocal(),
    end: j['end'] == null ? null : DateTime.parse(j['end'] as String).toLocal(),
    note: j['note'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'clientId': clientId,
    'start': start.toUtc().toIso8601String(),
    'end': end?.toUtc().toIso8601String(),
    if (note.isNotEmpty) 'note': note,
  };
}
