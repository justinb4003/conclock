import 'package:flutter/material.dart';

/// Area whose [SlideOnMove] children animate when they change position.
/// Put it inside the scroll view, so scrolling doesn't count as moving.
class SlideStage extends StatefulWidget {
  const SlideStage({super.key, required this.child});

  final Widget child;

  @override
  State<SlideStage> createState() => _SlideStageState();
}

class _SlideStageState extends State<SlideStage> {
  final _box = GlobalKey();

  @override
  Widget build(BuildContext context) =>
      KeyedSubtree(key: _box, child: widget.child);
}

/// Slides its child from where it was drawn last to where it is now
/// whenever the layout moves it (e.g. the list was reordered), instead of
/// jumping. Needs a stable key so it keeps its state across the move.
/// Nested ones move relative to the enclosing [SlideOnMove], so a row
/// inside a moving group doesn't move twice.
class SlideOnMove extends StatefulWidget {
  const SlideOnMove({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 280),
  });

  final Widget child;
  final Duration duration;

  @override
  State<SlideOnMove> createState() => _SlideOnMoveState();
}

class _SlideOnMoveState extends State<SlideOnMove>
    with SingleTickerProviderStateMixin {
  late final _anim = AnimationController(vsync: this, duration: widget.duration)
    ..value = 1;
  late final _curve = CurvedAnimation(
    parent: _anim,
    curve: Curves.easeOutCubic,
  );
  final _inner = GlobalKey();

  /// Layout position last frame, relative to the reference box.
  Offset? _last;

  /// Where the slide started, relative to the current position.
  Offset _from = Offset.zero;
  bool _scheduled = false;

  Offset get _offset => _from * (1 - _curve.value);

  /// What positions are measured against: the enclosing slide's content
  /// (below its own movement) or the stage.
  RenderBox? get _reference {
    final parent = context.findAncestorStateOfType<_SlideOnMoveState>();
    final stage = context.findAncestorStateOfType<_SlideStageState>();
    final key = parent?._inner ?? stage?._box;
    return key?.currentContext?.findRenderObject() as RenderBox?;
  }

  void _schedule() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  void _measure() {
    _scheduled = false;
    if (!mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    final ref = _reference;
    if (box == null || ref == null || !box.attached || !ref.attached) return;
    // Excludes this widget's own translation (applied below this box).
    final pos = box.localToGlobal(Offset.zero, ancestor: ref);
    final last = _last;
    _last = pos;
    if (last == null || last == pos) return;
    // Start from wherever it's drawn now, even mid-slide.
    setState(() => _from = last + _offset - pos);
    _anim.forward(from: 0);
  }

  @override
  void didUpdateWidget(SlideOnMove old) {
    super.didUpdateWidget(old);
    _schedule();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _schedule();
    return AnimatedBuilder(
      animation: _curve,
      builder: (context, child) =>
          Transform.translate(offset: _offset, child: child),
      child: KeyedSubtree(key: _inner, child: widget.child),
    );
  }
}
