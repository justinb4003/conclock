/// Persists the app's single JSON document.
abstract class DataStorage {
  /// Human-readable description of where data lives.
  String get location;

  Future<String?> read();

  Future<void> write(String data);

  /// Keep a copy of unreadable data before it gets overwritten.
  Future<void> backupCorrupt();
}
