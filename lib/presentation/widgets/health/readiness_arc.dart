import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Mirrors `src/components/health/ReadinessArc.tsx`.
///
/// Segmented radial gauge — a ring of discrete ticks rather than a solid arc.
/// Discrete ticks are the right call for a score built from a handful of
/// weighted z-scores: a smooth sweep implies a precision the underlying data
/// does not have, whereas 40 steps reads honestly as "roughly here".
class ReadinessArc extends StatelessWidget {
  const ReadinessArc({
    super.key,
    required this.score,
    this.size = 130,
    this.sweep = 260,
    this.tickCount = 40,
    this.color = AppColors.lime,
    this.label,
    this.caption,
  });

  /// 0–100. Null renders the empty track with a placeholder.
  final int? score;

  final double size;

  /// Total sweep in degrees, centred on 12 o'clock.
  final double sweep;

  final int tickCount;
  final Color color;
  final String? label;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _TickPainter(
              score: score,
              sweep: sweep,
              tickCount: tickCount,
              color: color,
            ),
          ),
          if (score == null)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '—',
                  style: AppTextStyles.metric.copyWith(
                    color: AppColors.onBrand.withValues(alpha: 0.4),
                  ),
                ),
                if (caption != null)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 92),
                    child: Text(
                      caption!.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.tag.copyWith(
                        fontSize: 9,
                        letterSpacing: 0.9,
                        color: AppColors.onBrand.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
              ],
            )
          else
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$score',
                      style: AppTextStyles.metric.copyWith(
                        fontSize: size * 0.27,
                        height: 1.1,
                        color: AppColors.onBrand,
                      ),
                    ),
                    Text(
                      '%',
                      style: AppTextStyles.h5.copyWith(
                        fontSize: size * 0.11,
                        color: AppColors.onBrand.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
                if (label != null || caption != null)
                  Text(
                    (label ?? caption)!.toUpperCase(),
                    style: AppTextStyles.tag.copyWith(
                      fontSize: 10,
                      letterSpacing: 1,
                      color: AppColors.onBrand.withValues(alpha: 0.6),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _TickPainter extends CustomPainter {
  const _TickPainter({
    required this.score,
    required this.sweep,
    required this.tickCount,
    required this.color,
  });

  final int? score;
  final double sweep;
  final int tickCount;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2 - 4;
    final tickLength = size.width * 0.11;
    final innerRadius = outerRadius - tickLength;

    final filledCount = score == null
        ? 0
        : ((score! / 100) * tickCount).round();
    final startAngle = -sweep / 2;
    final step = sweep / (tickCount - 1);
    final track = AppColors.onBrand.withValues(alpha: 0.18);

    for (var i = 0; i < tickCount; i += 1) {
      // 0° points at 12 o'clock, so the screen angle is offset by −90°.
      final degrees = startAngle + i * step - 90;
      final radians = degrees * math.pi / 180;
      final direction = Offset(math.cos(radians), math.sin(radians));

      final paint = Paint()
        ..color = i < filledCount ? color : track
        // Ticks thicken slightly toward the filled end for a sense of
        // direction.
        ..strokeWidth = 2.5 + (i / tickCount) * 1.6
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(
        center + direction * innerRadius,
        center + direction * outerRadius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_TickPainter old) =>
      old.score != score ||
      old.sweep != sweep ||
      old.tickCount != tickCount ||
      old.color != color;
}
