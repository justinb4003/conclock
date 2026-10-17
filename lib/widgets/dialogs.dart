import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';

Future<String?> promptText(
  BuildContext context, {
  required String title,
  String initial = '',
  String hint = '',
  String confirmLabel = 'Save',
  TextCapitalization capitalization = TextCapitalization.words,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _PromptDialog(
      title: title,
      initial: initial,
      hint: hint,
      confirmLabel: confirmLabel,
      capitalization: capitalization,
    ),
  );
}

class _PromptDialog extends StatefulWidget {
  const _PromptDialog({
    required this.title,
    required this.initial,
    required this.hint,
    required this.confirmLabel,
    required this.capitalization,
  });

  final String title;
  final String initial;
  final String hint;
  final String confirmLabel;
  final TextCapitalization capitalization;

  @override
  State<_PromptDialog> createState() => _PromptDialogState();
}

class _PromptDialogState extends State<_PromptDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final v = _controller.text.trim();
    if (v.isNotEmpty) Navigator.pop(context, v);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(hintText: widget.hint),
        textCapitalization: widget.capitalization,
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.confirmLabel)),
      ],
    );
  }
}

/// Asks for a name and adds the client.
Future<void> showAddClient(BuildContext context) async {
  final store = StoreScope.read(context);
  final name = await promptText(
    context,
    title: 'New client',
    hint: 'Client name',
    confirmLabel: 'Add',
  );
  if (name != null) store.addClient(name);
}

Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Delete',
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok ?? false;
}

Future<int?> pickColor(BuildContext context, int current) {
  return showDialog<int>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Color'),
      content: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final c in clientPalette)
            InkWell(
              customBorder: const CircleBorder(),
              onTap: () => Navigator.pop(context, c),
              child: CircleAvatar(
                radius: 20,
                backgroundColor: Color(c),
                child: c == current
                    ? const Icon(Icons.check, color: Colors.white)
                    : null,
              ),
            ),
        ],
      ),
    ),
  );
}

/// Shows [message]; with [undo], adds an Undo button.
void toast(
  BuildContext context,
  String message, {
  VoidCallback? undo,
  SnackBarAction? action,
}) => showToast(
  ScaffoldMessenger.of(context),
  message,
  undo: undo,
  action: action,
);

/// [toast] for when the caller's context is about to go away (e.g. a dialog
/// that's closing): grab the messenger first.
void showToast(
  ScaffoldMessengerState messenger,
  String message, {
  VoidCallback? undo,
  SnackBarAction? action,
}) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        action: undo == null
            ? action
            : SnackBarAction(label: 'Undo', onPressed: undo),
        // Give time to act on it. Flutter keeps snackbars with an action up
        // until dismissed unless told otherwise.
        duration: Duration(seconds: action == null ? 4 : 12),
        persist: false,
      ),
    );
}
