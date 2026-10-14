/// Side copies kept per tag (see [DataStorage.keepCopy]).
const keepCopies = 3;

/// Of side copies named `<prefix><millis>`, all but the newest [keepCopies].
List<String> oldCopies(List<String> names) {
  int stamp(String n) => int.tryParse(n.substring(n.lastIndexOf('-') + 1)) ?? 0;
  final sorted = [...names]..sort((a, b) => stamp(b).compareTo(stamp(a)));
  return sorted.skip(keepCopies).toList();
}

/// Persists the app's single JSON document.
abstract class DataStorage {
  /// Human-readable description of where data lives.
  String get location;

  Future<String?> read();

  Future<void> write(String data);

  /// Keeps a side copy tagged [tag] of [data], or of what's currently
  /// stored when null (e.g. unreadable data before it gets overwritten).
  Future<void> keepCopy(String tag, String? data);

  /// Calls [onChange] when another instance (e.g. a second browser tab)
  /// saves. No-op where that can't happen.
  void watch(void Function(String data) onChange) {}

  /// Whether the data can live in a folder the user picks (desktop).
  bool get canRelocate => false;

  /// Whether data is in the default place rather than a chosen folder.
  bool get isDefaultLocation => folder == null;

  /// The folder the user chose for their data, or null for the default.
  String? get folder => null;

  /// Something the user should know about where data is (e.g. their chosen
  /// folder is missing), found while reading.
  String? get warning => null;

  /// Whether [dir] already holds ConClock data.
  Future<bool> hasDataAt(String dir) async => false;

  /// From now on read/write data in [dir] (null: the default place).
  /// Doesn't move anything; the caller decides what to write or read.
  Future<void> relocate(String? dir) async {}
}
