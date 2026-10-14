import 'dart:async';

import 'package:flutter/widgets.dart';

/// Rebuilds every [interval] (default once a second). Keep these small so only the clock text repaints.
class LiveBuilder extends StatefulWidget {
  const LiveBuilder({
    super.key,
    required this.builder,
    this.enabled = true,
    this.interval = const Duration(seconds: 1),
  });

  final Widget Function(BuildContext context, DateTime now) builder;
  final bool enabled;
  final Duration interval;

  @override
  State<LiveBuilder> createState() => _LiveBuilderState();
}

class _LiveBuilderState extends State<LiveBuilder> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(LiveBuilder old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (widget.enabled && _timer == null) {
      _timer = Timer.periodic(widget.interval, (_) => setState(() {}));
    } else if (!widget.enabled) {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, DateTime.now());
}
