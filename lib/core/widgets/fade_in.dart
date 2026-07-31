import 'dart:async';

import 'package:flutter/material.dart';

/// Mirrors `src/components/ui/FadeIn.tsx` — a short fade plus a few pixels of
/// upward travel, staggered by [delay] down the screen so sections arrive in
/// reading order instead of all at once.
class FadeIn extends StatefulWidget {
  const FadeIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 320),
    this.offsetY = 10,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final double offsetY;

  @override
  State<FadeIn> createState() => _FadeInState();
}

class _FadeInState extends State<FadeIn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  late final CurvedAnimation _eased = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  /// Held so it can be cancelled: a bare `Future.delayed` outlives a widget
  /// that is disposed before it fires, which leaves a pending timer behind
  /// every scrolled-away section — and fails any widget test that checks for
  /// them at teardown.
  Timer? _delayTimer;

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      _delayTimer = Timer(widget.delay, _controller.forward);
    }
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _eased,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: _eased.value,
        child: Transform.translate(
          offset: Offset(0, widget.offsetY * (1 - _eased.value)),
          child: child,
        ),
      ),
    );
  }
}
