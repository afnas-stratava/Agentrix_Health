import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/stats/stats.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/surface_card.dart';
import '../../../core/util/iso_day.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_tag.dart';
import '../../../core/widgets/sparkline.dart';
import '../../../domain/entities/health/metric_key.dart';
import '../../../domain/entities/insights/correlation.dart';
import '../../providers/health_providers.dart';
import 'main_shell.dart';

/// One metric in depth. Mirrors `app/metric/[metric].tsx`.
///
/// Answers the three questions a tile cannot: what it has done over the window,
/// how that compares with the user's own baseline, and what else in their data
/// moves with it. The last is why this screen exists rather than just being a
/// bigger chart.
class MetricDetailScreen extends ConsumerWidget {
  const MetricDetailScreen({super.key, required this.metric});

  final MetricKey metric;

  /// Metrics the selected one is tested against, each with the lag its
  /// physiology implies — load affects tomorrow's HRV, not today's.
  static const _comparisons = [
    (metric: MetricKey.sleepDuration, lag: 0, label: 'Same-night sleep'),
    (metric: MetricKey.activeEnergy, lag: 1, label: "Previous day's load"),
    (metric: MetricKey.steps, lag: 1, label: "Previous day's steps"),
    (
      metric: MetricKey.sleepEfficiency,
      lag: 0,
      label: 'Same-night sleep quality',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meta = metricMeta[metric]!;
    final engineContext = ref.watch(engineContextProvider);
    final stats = engineContext?.metrics[metric];
    final values = stats?.values ?? const <double?>[];
    final present = compact(values);

    String format(double? value) {
      if (value == null || !value.isFinite) return '—';
      if (metric == MetricKey.steps) return _thousands(value);
      return value.toStringAsFixed(meta.precision);
    }

    final correlations = engineContext == null
        ? const <({String label, Correlation result, MetricKey metric})>[]
        : _comparisons
              .where((c) => c.metric != metric)
              .map(
                (c) => (
                  label: c.label,
                  metric: c.metric,
                  result: engineContext.correlate(c.metric, metric, c.lag),
                ),
              )
              .where(
                (c) =>
                    c.result != null &&
                    c.result!.strength != CorrelationStrength.none,
              )
              .map(
                (c) => (label: c.label, metric: c.metric, result: c.result!),
              )
              .toList();

    final days = engineContext?.days ?? const <IsoDay>[];

    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.space6,
        AppSpacing.space6,
        AppSpacing.space6,
        MainShell.bottomInsetFor(context),
      ),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: AppSpacing.space4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meta.label,
                      style: AppTextStyles.h3.copyWith(fontSize: 26),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${values.length} days · ${present.length} with data',
                      style: AppTextStyles.cardBody,
                    ),
                  ],
                ),
              ),
            ),
            AppButton.icon(
              leading: const Icon(Icons.close, size: 16),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.space6),

        // HERO — latest, delta and the whole window as a filled sparkline.
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _MicroLabel('Latest'),
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          spacing: 4,
                          children: [
                            Text(
                              format(stats?.latest),
                              style: AppTextStyles.metric,
                            ),
                            if (meta.unit.isNotEmpty)
                              Text(
                                meta.unit,
                                style: AppTextStyles.cardBody.copyWith(
                                  fontSize: 14,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _DeltaBadge(
                    deltaPct: stats?.deltaPct,
                    higherIsBetter:
                        metricPolarity[metric] == MetricPolarity.higherIsBetter,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.space5),
              Sparkline(
                values: values,
                color: AppColors.ink,
                height: 110,
                strokeWidth: 2.5,
                filled: true,
              ),
              if (days.length > 1)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.space2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DateFormat('d MMM').format(fromIsoDay(days.first)),
                        style: AppTextStyles.cardMeta.copyWith(fontSize: 10),
                      ),
                      Text(
                        DateFormat('d MMM').format(fromIsoDay(days.last)),
                        style: AppTextStyles.cardMeta.copyWith(fontSize: 10),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.space3),
        Row(
          spacing: AppSpacing.space3,
          children: [
            Expanded(
              child: SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _MicroLabel('7-day mean'),
                    const SizedBox(height: 6),
                    Text(
                      format(stats?.recentMean),
                      style: AppTextStyles.metricSmall,
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _MicroLabel('28-day baseline'),
                    const SizedBox(height: 6),
                    Text(
                      format(stats?.baselineMean),
                      style: AppTextStyles.metricSmall,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.space3),
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _MicroLabel('Distribution'),
              const SizedBox(height: AppSpacing.space3),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final item in <(String, double?)>[
                    ('Min', present.isEmpty ? null : present.reduce(_min)),
                    ('Median', present.isEmpty ? null : median(present)),
                    ('Mean', present.isEmpty ? null : mean(present)),
                    ('Max', present.isEmpty ? null : present.reduce(_max)),
                    ('SD', present.length > 1 ? stdDev(present) : null),
                  ])
                    Column(
                      children: [
                        Text(
                          item.$1.toUpperCase(),
                          style: AppTextStyles.cardMeta.copyWith(
                            fontSize: 10,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          format(item.$2),
                          style: AppTextStyles.h6.copyWith(
                            fontSize: 15,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.space6 + AppSpacing.space1),
        Text(
          'WHAT MOVES THIS METRIC',
          style: AppTextStyles.tag.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.55,
            color: AppColors.muted,
          ),
        ),
        const SizedBox(height: AppSpacing.space3),

        if (correlations.isEmpty)
          SurfaceCard(
            child: Text(
              'No statistically meaningful relationship found yet. '
              'Correlations need at least 10 paired days and a p-value under '
              '0.05 before we will show them — weak links on thin data are '
              'worse than none.',
              style: AppTextStyles.cardBody.copyWith(
                fontSize: 13,
                height: 1.46,
              ),
            ),
          )
        else
          for (final entry in correlations)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.space3),
              child: _CorrelationCard(
                label: entry.label,
                other: entry.metric,
                selected: metric,
                result: entry.result,
              ),
            ),

        const SizedBox(height: AppSpacing.space4),
        Text(
          'Correlation is not causation. These relationships describe your own '
          'history and can be confounded by anything not measured here.',
          textAlign: TextAlign.center,
          style: AppTextStyles.cardMeta.copyWith(fontSize: 11, height: 1.4),
        ),
      ],
    );
  }
}

double _min(double a, double b) => a < b ? a : b;
double _max(double a, double b) => a > b ? a : b;

String _thousands(num value) {
  final digits = value.round().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i += 1) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

class _MicroLabel extends StatelessWidget {
  const _MicroLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: AppTextStyles.tag.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1,
        color: AppColors.muted,
      ),
    );
  }
}

/// Direction-aware: a falling resting heart rate is good news and a falling HRV
/// is not, so one colour for "down" would mislead on half the metrics.
class _DeltaBadge extends StatelessWidget {
  const _DeltaBadge({required this.deltaPct, required this.higherIsBetter});

  final double? deltaPct;
  final bool higherIsBetter;

  @override
  Widget build(BuildContext context) {
    final delta = deltaPct;
    if (delta == null) {
      return const AppTag(label: 'No baseline', variant: AppTagVariant.neutral);
    }

    final rising = delta > 0;
    final good = rising == higherIsBetter;
    final colour = good ? AppColors.optimal : AppColors.borderline;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 3,
        children: [
          Icon(
            rising ? Icons.arrow_upward : Icons.arrow_downward,
            size: 12,
            color: colour,
          ),
          Text(
            '${delta.abs().round()}%',
            style: AppTextStyles.cardMeta.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colour,
            ),
          ),
        ],
      ),
    );
  }
}

class _CorrelationCard extends StatelessWidget {
  const _CorrelationCard({
    required this.label,
    required this.other,
    required this.selected,
    required this.result,
  });

  final String label;
  final MetricKey other;
  final MetricKey selected;
  final Correlation result;

  @override
  Widget build(BuildContext context) {
    final strengthColour = switch (result.strength) {
      CorrelationStrength.strong => AppColors.optimal,
      CorrelationStrength.moderate => AppColors.normal,
      _ => AppColors.borderline,
    };

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.cardTitle.copyWith(fontSize: 14),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: strengthColour.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  result.strength.name,
                  style: AppTextStyles.cardMeta.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: strengthColour,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space2),
          Text(
            '${metricMeta[other]!.label} '
            '${result.direction == CorrelationDirection.positive ? 'rises with' : 'moves against'} '
            'your ${metricMeta[selected]!.short.toLowerCase()} across '
            '${result.n} paired days'
            '${result.lagDays > 0 ? ' at a ${result.lagDays}-day lag' : ''}.',
            style: AppTextStyles.cardBody.copyWith(height: 1.5),
          ),
          const SizedBox(height: 6),
          // r, p and n together: an r of 0.6 over 11 days and the same r over 60
          // are very different claims, and hiding n is how correlation UIs
          // mislead.
          Text(
            'r = ${result.r} · '
            'p = ${result.p < 0.001 ? '<0.001' : result.p} · '
            'n = ${result.n}',
            style: AppTextStyles.cardMeta.copyWith(
              fontSize: 11,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
