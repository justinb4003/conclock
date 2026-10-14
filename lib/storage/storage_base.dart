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
}
