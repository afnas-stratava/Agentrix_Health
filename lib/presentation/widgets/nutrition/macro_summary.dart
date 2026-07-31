import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../domain/entities/nutrition/macros.dart';
import '../../../domain/entities/nutrition/nutrition_targets.dart';

/// Mirrors `src/components/nutrition/MacroSummary.tsx`.

/// Today's calories against today's target.
///
/// A solid ring is right here — unlike the readiness gauge, which encodes a
/// statistical estimate, a calorie total is a straight sum of things the user
/// explicitly logged. The precision the ring implies is precision the number
/// actually has.
class CalorieRing extends StatelessWidget {
  const CalorieRing({
    super.key,
    required this.consumed,
    required this.target,
    this.size = 152,
    this.strokeWidth = 12,
    this.showRemaining = true,
  });

  final int consumed;
  final int target;
  final double size;
  final double strokeWidth;

  /// Renders the remainder rather than the total in the centre.
  final bool showRemaining;

  @override
  Widget build(BuildContext context) {
    final ratio = target > 0 ? consumed / target : 0.0;
    // Capped at a full turn; overshoot is communicated by colour, not by a
    // second lap, which would read as "back to nearly empty".
    final progress = ratio.clamp(0.0, 1.0);

    final over = ratio > 1.02;
    final ringColor = over
        ? AppColors.abnormal
        : (ratio > 0.85 ? AppColors.optimal : AppColors.brand);
    final remaining = math.max(0, target - consumed);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _RingPainter(
              progress: progress.toDouble(),
              color: ringColor,
              strokeWidth: strokeWidth,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${showRemaining ? remaining : consumed}',
                style: AppTextStyles.h2.copyWith(
                  fontSize: 32,
                  height: 36 / 32,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                over
                    ? 'OVER TARGET'
                    : (showRemaining ? 'KCAL LEFT' : 'KCAL EATEN'),
                style: AppTextStyles.tag.copyWith(
                  fontSize: 10,
                  color: AppColors.faint,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$consumed / $target',
                style: AppTextStyles.cardMeta.copyWith(
                  fontSize: 11,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = (size.width - strokeWidth) / 2;
    final centre = Offset(size.width / 2, size.height / 2);

    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = AppColors.hairline,
    );

    if (progress <= 0) return;

    canvas.drawArc(
      Rect.fromCircle(center: centre, radius: radius),
      // Starts at 12 o'clock rather than 3.
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.strokeWidth != strokeWidth;
}

class MacroBar extends StatelessWidget {
  const MacroBar({
    super.key,
    required this.label,
    required this.consumed,
    required this.target,
    required this.color,
    this.unit = 'g',
    this.overIsBad = false,
  });

  final String label;
  final double consumed;
  final double target;
  final Color color;
  final String unit;

  /// Above-target is a *problem* for sugar and sodium, not for protein.
  final bool overIsBad;

  @override
  Widget build(BuildContext context) {
    final ratio = target > 0 ? consumed / target : 0.0;
    final isOver = ratio > 1;
    final barColor = isOver && overIsBad ? AppColors.abnormal : color;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.cardTitle.copyWith(fontSize: 12),
                ),
              ),
              RichText(
                text: TextSpan(
                  style: AppTextStyles.cardMeta.copyWith(
                    fontSize: 11,
                    color: isOver && overIsBad
                        ? AppColors.abnormal
                        : AppColors.muted,
                  ),
                  children: [
                    TextSpan(text: '${consumed.round()}$unit '),
                    TextSpan(
                      text: '/ ${target.round()}$unit',
                      style: AppTextStyles.cardMeta.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: SizedBox(
              height: 6,
              child: ColoredBox(
                color: AppColors.ink.withValues(alpha: 0.08),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: ratio.clamp(0.0, 1.0).toDouble(),
                  child: ColoredBox(color: barColor),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Five bars, one per macro.
///
/// Added sugar is a bar like the rest rather than a special case, but with
/// `overIsBad` so crossing it turns the row orange — a ceiling and a target look
/// the same until you pass them, and only then should they diverge.
class MacroBars extends StatelessWidget {
  const MacroBars({
    super.key,
    required this.consumed,
    required this.targets,
    required this.sugarCeilingG,
  });

  final Macros consumed;
  final MacroTargets targets;
  final int sugarCeilingG;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MacroBar(
          label: 'Protein',
          consumed: consumed.proteinG,
          target: targets.proteinG.toDouble(),
          color: AppColors.brand,
        ),
        MacroBar(
          label: 'Carbs',
          consumed: consumed.carbsG,
          target: targets.carbsG.toDouble(),
          color: AppColors.normal,
        ),
        MacroBar(
          label: 'Fat',
          consumed: consumed.fatG,
          target: targets.fatG.toDouble(),
          color: AppColors.borderline,
        ),
        MacroBar(
          label: 'Fibre',
          consumed: consumed.fibreG,
          target: targets.fibreG.toDouble(),
          color: AppColors.optimal,
        ),
        MacroBar(
          label: 'Added sugar',
          consumed: consumed.addedSugarG,
          target: sugarCeilingG.toDouble(),
          color: AppColors.limeStrong,
          overIsBad: true,
        ),
      ],
    );
  }
}

/// Glasses rather than a bar — water is logged in discrete, tappable units, and
/// a bar would imply a precision nobody has about how much they just drank.
class WaterTracker extends StatelessWidget {
  const WaterTracker({
    super.key,
    required this.ml,
    required this.targetMl,
    required this.onAdd,
  });

  final int ml;
  final int targetMl;
  final ValueChanged<int> onAdd;

  static const int _glassMl = 250;

  @override
  Widget build(BuildContext context) {
    final targetGlasses = math.max(1, (targetMl / _glassMl).round());
    final filled = ml ~/ _glassMl;
    final shown = math.min(12, targetGlasses);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: Text(
                'Water',
                style: AppTextStyles.cardTitle.copyWith(fontSize: 13),
              ),
            ),
            RichText(
              text: TextSpan(
                style: AppTextStyles.cardMeta.copyWith(
                  fontSize: 11,
                  color: AppColors.muted,
                ),
                children: [
                  TextSpan(text: '${(ml / 1000).toStringAsFixed(1)} L '),
                  TextSpan(
                    text: '/ ${(targetMl / 1000).toStringAsFixed(1)} L',
                    style: AppTextStyles.cardMeta.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.space2),

        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var i = 0; i < shown; i += 1)
              Semantics(
                label: 'Glass ${i + 1} of $targetGlasses',
                child: Container(
                  width: 24,
                  height: 32,
                  decoration: BoxDecoration(
                    color: i < filled
                        ? AppColors.brand400
                        : AppColors.surface,
                    border: Border.all(
                      color: i < filled
                          ? AppColors.brand400
                          : AppColors.hairline,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
          ],
        ),

        const SizedBox(height: AppSpacing.space3),
        Row(
          children: [
            for (final amount in const [250, 500])
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.space2),
                child: _AddButton(amount: amount, onTap: () => onAdd(amount)),
              ),
          ],
        ),
      ],
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.amount, required this.onTap});

  final int amount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Add $amount millilitres of water',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.space3,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.hairline),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Text(
            '+$amount ml',
            style: AppTextStyles.cardTitle.copyWith(
              fontSize: 12,
              color: AppColors.brand700,
            ),
          ),
        ),
      ),
    );
  }
}
