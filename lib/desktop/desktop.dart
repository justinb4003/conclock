// Tray icon and close-to-tray on Linux/Windows/macOS; no-ops elsewhere. The
// web build never sees the desktop plugins.
export 'desktop_stub.dart' if (dart.library.io) 'desktop_io.dart';
