import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';

/// Saves [text] via a Save dialog. Returns a message for the user, or null
/// if cancelled.
Future<String?> saveTextFile(String name, String text, XTypeGroup type) async {
  if (Platform.isAndroid || Platform.isIOS) {
    // No save dialog on mobile; hand it over via the clipboard instead.
    await Clipboard.setData(ClipboardData(text: text));
    return 'Backup copied to the clipboard';
  }
  final location = await getSaveLocation(
    suggestedName: name,
    acceptedTypeGroups: [type],
  );
  if (location == null) return null;
  await File(location.path).writeAsString(text, flush: true);
  return 'Backup saved to ${location.path}';
}
