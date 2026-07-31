import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/sparkline.dart';
import '../../../domain/entities/health/metric_key.dart';
import '../../../features/correlation/engine_context.dart';

/// Mirrors `src/components/health/StatTile.tsx`.

const Map<MetricKey, IconData> _metricIcon = {
  MetricKey.hrv: Icons.monitor_heart_outlined,
  MetricKey.restingHeartRate: Icons.favorite_outline,
  MetricKey.sleepDuration: Icons.bedtime_outlined,
  MetricKey.sleepEfficiency: Icons.percent,
  MetricKey.steps: Icons.directions_walk,
  MetricKey.activeEnergy: Icons.local_fire_department_outlined,
};

String _formatValue(MetricKey key, double? value) {
  if (value == null) return '—';
  if (key == MetricKey.steps) {
    return NumberFormat.decimalPattern().format(value.round());
  }
  return value.toStringAsFixed(metricMeta[key]!.precision);
}

/// Colour follows the *trend*, not the absolute value: a good number that is
/// falling is more actionable than a mediocre one holding steady.
Color _trendColor(MetricStats stats) {
  final delta = stats.deltaPct;
  if (delta == null || delta.abs() < 2) return AppColors.faint;
  final rising = delta > 0;
  final higherIsBetter =
      metricPolarity[stats.key] == MetricPolarity.higherIsBetter;
  return rising == higherIsBetter ? AppColors.optimal : AppColors.abnormal;
}

/// Large stat card for the two metrics that actually drive readiness: icon,
/// delta chip, big number, label, then a sparkline for shape.
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.stats, this.onTap});

  final MetricStats stats;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final meta = metricMeta[stats.key]!;
    final color = _trendColor(stats);
    final value = _formatValue(stats.key, stats.latest);
    final delta = stats.deltaPct?.round();

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.lightImpact();
                onTap!();
              },
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.space4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.brand50,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Icon(
                      _metricIcon[stats.key],
                      size: 15,
                      color: AppColors.brand,
                    ),
                  ),
                  if (delta != null && delta != 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        '${delta > 0 ? '+' : ''}$delta%',
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
              const SizedBox(height: AppSpacing.space3),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                spacing: 4,
                children: [
                  Flexible(
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.metricSmall,
                    ),
                  ),
                  if (meta.unit.isNotEmpty)
                    Text(
                      meta.unit,
                      style: AppTextStyles.cardMeta.copyWith(fontSize: 11),
                    ),
                ],
              ),
              Text(
                meta.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.cardBody.copyWith(fontSize: 11),
              ),
              const SizedBox(height: 10),
              Sparkline(
                // The last 30 days is as much shape as a tile this size can
                // carry legibly.
                values: stats.values.length > 30
                    ? stats.values.sublist(stats.values.length - 30)
                    : stats.values,
                color: color,
                filled: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small chip for the supporting signals — a value and a direction is all the
/// space earns.
class SignalChip extends StatelessWidget {
  const SignalChip({super.key, required this.stats, this.onTap});

  final MetricStats stats;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final meta = metricMeta[stats.key]!;
    final color = _trendColor(stats);

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.lightImpact();
                onTap!();
              },
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.hairline),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.brand50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _metricIcon[stats.key],
                  size: 16,
                  color: AppColors.brand,
                ),
              ),
              const SizedBox(height: AppSpacing.space2),
              Text(
                _formatValue(stats.key, stats.latest),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.tag.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: 4,
                children: [
                  Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Flexible(
                    child: Text(
                      meta.short,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.cardMeta.copyWith(fontSize: 9),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
