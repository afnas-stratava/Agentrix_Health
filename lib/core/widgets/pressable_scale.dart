import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Mirrors `src/components/ui/PressableScale.tsx`.
///
/// Fading a large card on press reads as the card *dimming* rather than being
/// pushed; a small scale keeps the colour intact and feels physical. Keep
/// [scaleTo] subtle — 0.97 is the house default.
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.scaleTo = 0.97,
    this.semanticLabel,
    this.semanticHint,
    this.haptics = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scaleTo;
  final String? semanticLabel;
  final String? semanticHint;
  final bool haptics;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 130),
  );

  late final Animation<double> _scale = Tween<double>(
    begin: 1,
    end: widget.scaleTo,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutQuad));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;

    return Semantics(
      button: enabled,
      label: widget.semanticLabel,
      hint: widget.semanticHint,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _controller.forward() : null,
        onTapCancel: enabled ? () => _controller.reverse() : null,
        onTapUp: enabled ? (_) => _controller.reverse() : null,
        onTap: enabled
            ? () {
                if (widget.haptics) HapticFeedback.lightImpact();
                widget.onTap!();
              }
            : null,
        child: ScaleTransition(scale: _scale, child: widget.child),
      ),
    );
  }
}
