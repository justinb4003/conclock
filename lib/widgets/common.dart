import 'package:flutter/material.dart';

import '../store.dart';

/// h:mm / Decimal switch for an app bar; the setting is shared app-wide.
class HoursFormatToggle extends StatelessWidget {
  const HoursFormatToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return SegmentedButton<bool>(
      segments: const [
        ButtonSegment(value: false, label: Text('h:mm')),
        ButtonSegment(value: true, label: Text('Decimal')),
      ],
      selected: {store.decimalHours},
      showSelectedIcon: false,
      style: const ButtonStyle(visualDensity: VisualDensity.compact),
      onSelectionChanged: (s) => store.setDecimalHours(s.first),
    );
  }
}

/// Expand/collapse indicator: points right when closed, down when open.
class Chevron extends StatelessWidget {
  const Chevron({super.key, required this.open});

  final bool open;

  @override
  Widget build(BuildContext context) => AnimatedRotation(
    turns: open ? 0.25 : 0,
    duration: const Duration(milliseconds: 120),
    child: Icon(
      Icons.chevron_right,
      size: 20,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
}
