import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Mirrors `src/components/ui/Skeleton.tsx` — a placeholder that pulses instead
/// of a spinner, so the page keeps its shape while the first series loads.
class Skeleton extends StatefulWidget {
  const Skeleton({
    super.key,
    required this.height,
    this.width,
    this.radius = AppRadius.card,
  });

  final double height;
  final double? width;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 0.9).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: Container(
        height: widget.height,
        width: widget.width ?? double.infinity,
        decoration: BoxDecoration(
          color: AppColors.ink.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}
