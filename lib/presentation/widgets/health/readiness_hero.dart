import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/pressable_scale.dart';
import '../../../domain/entities/health/metric_key.dart';
import '../../../domain/entities/insights/readiness.dart';
import 'readiness_arc.dart';

/// Band colours for the hero surface only — these sit on deep green, so they
/// are lighter and warmer than the on-canvas status ramp in `app_colors.dart`.
const Map<ReadinessBand, Color> _bandColor = {
  ReadinessBand.compromised: Color(0xFFFF8A8A),
  ReadinessBand.low: Color(0xFFFFB27A),
  ReadinessBand.moderate: AppColors.lime,
  ReadinessBand.primed: AppColors.lime,
};

const Color _negative = Color(0xFFFFB27A);

/// Mirrors `src/components/health/ReadinessHero.tsx` — the dominant focal card:
/// band chip, the score as a segmented arc, the drivers behind it, and a CTA.
class ReadinessHero extends StatelessWidget {
  const ReadinessHero({
    super.key,
    required this.readiness,
    required this.fallbackHint,
    this.onTap,
  });

  final Readiness? readiness;

  /// Copy shown in place of drivers when there is no baseline yet.
  final String fallbackHint;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final copy = readiness == null ? null : readinessCopy[readiness!.band]!;
    final drivers = readiness?.drivers ?? const <ReadinessDriver>[];

    // Normalise bar lengths against the largest driver so the chart uses its
    // full width, with a floor so a genuinely flat day does not render
    // maxed-out bars off tiny differences.
    final scale = drivers.isEmpty
        ? 10.0
        : math.max(
            10.0,
            drivers.map((d) => d.contribution.abs()).reduce(math.max),
          );

    final topDriver = drivers.isEmpty ? null : drivers.first;
    final isDragging = topDriver != null && topDriver.contribution < 0;
    final bandColor = readiness == null
        ? AppColors.lime
        : _bandColor[readiness!.band]!;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2E0F2E1E),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: AppColors.heroGradient,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Band chip — the qualitative read, ahead of the number.
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.onBrand.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(
                              AppRadius.pill,
                            ),
                          ),
                          child: Text(
                            (copy?.label ?? 'No baseline').toUpperCase(),
                            style: AppTextStyles.tag.copyWith(
                              fontSize: 9,
                              letterSpacing: 0.5,
                              color: readiness == null
                                  ? AppColors.onBrand.withValues(alpha: 0.75)
                                  : bandColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Readiness',
                          style: AppTextStyles.h3.copyWith(
                            color: AppColors.onBrand,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          spacing: 6,
                          children: [
                            if (readiness != null)
                              Icon(
                                isDragging
                                    ? Icons.trending_down
                                    : Icons.trending_up,
                                size: 13,
                                color: isDragging ? _negative : AppColors.lime,
                              ),
                            Expanded(
                              child: Text(
                                readiness == null
                                    ? 'Building your baseline'
                                    : 'vs. ${readiness!.baselineDays}-day baseline',
                                style: AppTextStyles.cardMeta.copyWith(
                                  color: AppColors.onBrandMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  ReadinessArc(
                    score: readiness?.score,
                    color: bandColor,
                    caption: readiness == null ? 'needs 7 days' : null,
                  ),
                ],
              ),

              // Drivers, or the reason there are none.
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.space3),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: AppColors.onBrand.withValues(alpha: 0.15),
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: drivers.isEmpty
                        ? Text(
                            fallbackHint,
                            style: AppTextStyles.cardMeta.copyWith(
                              color: AppColors.onBrandMuted,
                              height: 1.4,
                            ),
                          )
                        : Column(
                            children: [
                              for (final driver in drivers.take(4))
                                _DriverBar(
                                  label: metricMeta[driver.metric]!.short,
                                  contribution: driver.contribution,
                                  scale: scale,
                                ),
                            ],
                          ),
                  ),
                ),
              ),

              if (readiness != null && onTap != null)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: PressableScale(
                      scaleTo: 0.94,
                      onTap: onTap,
                      semanticLabel:
                          'Readiness ${copy?.label}. ${copy?.blurb ?? ''}',
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.lime,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          spacing: 6,
                          children: [
                            Text(
                              'What to do today',
                              style: AppTextStyles.tag.copyWith(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0,
                                color: AppColors.ink,
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward,
                              size: 13,
                              color: AppColors.ink,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact diverging bar for one readiness driver.
///
/// Right of centre means the metric is helping today, left means it is
/// dragging. A bare score is not actionable; "HRV is costing you 14 points"
/// points straight at tonight's decision.
class _DriverBar extends StatelessWidget {
  const _DriverBar({
    required this.label,
    required this.contribution,
    required this.scale,
  });

  final String label;
  final double contribution;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final magnitude = math.min(1.0, contribution.abs() / scale);
    final isPositive = contribution >= 0;
    final color = isPositive ? AppColors.lime : _negative;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        spacing: 10,
        children: [
          SizedBox(
            width: 52,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.cardMeta.copyWith(
                fontSize: 10,
                color: AppColors.onBrand.withValues(alpha: 0.6),
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: Container(
                height: 4,
                color: AppColors.onBrand.withValues(alpha: 0.15),
                child: Row(
                  children: [
                    // Two half-width lanes so the bar diverges from the
                    // centre. `heightFactor` is load-bearing: under a loose
                    // vertical constraint the fill would collapse to nothing.
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: FractionallySizedBox(
                          widthFactor: isPositive ? 0 : magnitude,
                          heightFactor: 1,
                          child: ColoredBox(color: color),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: isPositive ? magnitude : 0,
                          heightFactor: 1,
                          child: ColoredBox(color: color),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(
            width: 26,
            child: Text(
              '${isPositive ? '+' : '−'}${contribution.abs().round()}',
              textAlign: TextAlign.right,
              style: AppTextStyles.tag.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
