import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/stats/stats.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/util/iso_day.dart';
import '../../../core/widgets/charts/day_column_chart.dart';
import '../../../core/widgets/section_header.dart';
import '../../../domain/entities/health/metric_key.dart';
import '../../../domain/entities/insights/correlation.dart';
import '../../../features/correlation/engine_context.dart';
import '../../providers/health_providers.dart';
import '../../providers/insights_providers.dart';

/// One metric, in depth. Ported from `app/metric/[metric].tsx`.
///
/// Answers the three questions a tile cannot: what has it done over the window,
/// how does that compare with the user's own baseline, and what else in their
/// data moves with it. The last one is the reason this screen exists rather than
/// just being a bigger chart.
class MetricDetailScreen extends ConsumerStatefulWidget {
  const MetricDetailScreen({super.key, required this.metric});

  final MetricKey metric;

  @override
  ConsumerState<MetricDetailScreen> createState() =>
      _MetricDetailScreenState();
}

class _MetricDetailScreenState extends ConsumerState<MetricDetailScreen> {
  int? _selected;

  /// Days shown in the column chart. The engine's window is 35 days, but 35
  /// columns on a phone is a smear — two weeks is the most that stays readable.
  static const int _visibleDays = 14;

  @override
  Widget build(BuildContext context) {
    final meta = metricMeta[widget.metric]!;
    final context_ = ref.watch(engineContextProvider);
    final series = ref.watch(healthSeriesProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.canvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(meta.label, style: AppTextStyles.h5),
      ),
      body: context_ == null || series == null
          ? const Center(child: CircularProgressIndicator())
          : _Body(
              metric: widget.metric,
              engineContext: context_,
              selected: _selected,
              visibleDays: _visibleDays,
              onSelect: (index) => setState(() => _selected = index),
            ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.metric,
    required this.engineContext,
    required this.selected,
    required this.visibleDays,
    required this.onSelect,
  });

  final MetricKey metric;
  final EngineContext engineContext;
  final int? selected;
  final int visibleDays;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meta = metricMeta[metric]!;
    final stats = engineContext.metrics[metric]!;
    final days = engineContext.days;

    final start = days.length > visibleDays ? days.length - visibleDays : 0;
    final windowDays = days.sublist(start);
    final windowValues = stats.values.sublist(start);
    final selectedIndex = (selected ?? windowValues.length - 1).clamp(
      0,
      windowValues.length - 1,
    );

    String format(double value) =>
        '${value.toStringAsFixed(meta.precision)}${meta.unit.isEmpty ? '' : ' ${meta.unit}'}';

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.space5,
        0,
        AppSpacing.space5,
        AppSpacing.space8,
      ),
      children: [
        _Hero(metric: metric, stats: stats, format: format),

        const SizedBox(height: AppSpacing.space5),
        SectionHeader(title: 'Last ${windowDays.length} days'),
        Container(
          padding: const EdgeInsets.all(AppSpacing.space4),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.hairline),
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: DayColumnChart(
            values: windowValues,
            labels: [
              for (final day in windowDays)
                DateFormat('E').format(fromIsoDay(day))[0],
            ],
            selectedIndex: selectedIndex,
            formatValue: format,
            onSelect: onSelect,
          ),
        ),

        const SizedBox(height: AppSpacing.space5),
        const SectionHeader(title: 'Against your baseline'),
        _BaselineTable(stats: stats, format: format),

        const SizedBox(height: AppSpacing.space5),
        _Correlations(metric: metric, engineContext: engineContext),

        const SizedBox(height: AppSpacing.space5),
        _RelatedInsights(metric: metric),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.metric,
    required this.stats,
    required this.format,
  });

  final MetricKey metric;
  final MetricStats stats;
  final String Function(double) format;

  @override
  Widget build(BuildContext context) {
    final delta = stats.deltaPct;
    final polarity = metricPolarity[metric]!;
    // "Better" is direction-aware: a falling resting heart rate is good news
    // and a falling HRV is not, and one colour for both would mislead.
    final improving = delta == null
        ? null
        : polarity == MetricPolarity.higherIsBetter
        ? delta > 0
        : delta < 0;

    final colour = improving == null
        ? AppColors.muted
        : (improving ? AppColors.optimal : AppColors.borderline);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.space5),
      decoration: BoxDecoration(
        color: AppColors.brand900,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'LATEST',
            style: AppTextStyles.tag.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: AppColors.accent2_400,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            stats.latest == null ? '—' : format(stats.latest!),
            style: AppTextStyles.metricLarge.copyWith(
              color: AppColors.onBrand,
            ),
          ),
          const SizedBox(height: AppSpacing.space2),
          if (delta == null)
            Text(
              stats.baselineDays < minBaselineDays
                  ? 'Needs ${minBaselineDays - stats.baselineDays} more days of '
                        'baseline before a comparison means anything.'
                  : 'No baseline comparison available.',
              style: AppTextStyles.cardBody.copyWith(
                color: AppColors.onBrandMuted,
                height: 1.45,
              ),
            )
          else
            Row(
              spacing: AppSpacing.space2,
              children: [
                Icon(
                  delta > 0 ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 14,
                  color: colour,
                ),
                Expanded(
                  child: Text(
                    '${delta.abs().round()}% '
                    '${delta > 0 ? 'above' : 'below'} your 28-day baseline'
                    '${improving == false ? ' — worth watching' : ''}',
                    style: AppTextStyles.bodySmall.copyWith(
                      fontSize: 13,
                      color: AppColors.onBrandMuted,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _BaselineTable extends StatelessWidget {
  const _BaselineTable({required this.stats, required this.format});

  final MetricStats stats;
  final String Function(double) format;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      (
        'Last 7 days',
        stats.recentMean == null ? '—' : format(stats.recentMean!),
      ),
      (
        '28-day baseline',
        stats.baselineMean == null ? '—' : format(stats.baselineMean!),
      ),
      (
        'Trend',
        stats.slopePerDay.abs() < 0.001
            ? 'flat'
            : '${stats.slopePerDay > 0 ? '+' : ''}'
                  '${stats.slopePerDay.toStringAsFixed(2)} / day',
      ),
      ('Latest vs baseline', '${stats.z.toStringAsFixed(1)} SD'),
      (
        'Coverage',
        '${(stats.coverage * 100).round()}% of days have data',
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.hairline),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final row in rows)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.space4,
                vertical: AppSpacing.space3,
              ),
              decoration: BoxDecoration(
                border: row == rows.last
                    ? null
                    : const Border(
                        bottom: BorderSide(
                          color: AppColors.hairline,
                          width: 1,
                        ),
                      ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(row.$1, style: AppTextStyles.bodySmall),
                  ),
                  Text(
                    row.$2,
                    style: AppTextStyles.h6.copyWith(
                      fontSize: 13,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// What else in the user's data moves with this metric.
///
/// Every pair the engine can compute is shown, including the null results —
/// "no measurable link" is a real answer, and hiding it would leave only the
/// flattering ones.
class _Correlations extends StatelessWidget {
  const _Correlations({required this.metric, required this.engineContext});

  final MetricKey metric;
  final EngineContext engineContext;

  @override
  Widget build(BuildContext context) {
    final others = MetricKey.values.where((k) => k != metric).toList();
    final pairs = <(MetricKey, Correlation?)>[
      for (final other in others) (other, engineContext.correlate(metric, other)),
    ];

    final ranked = [...pairs]
      ..sort((a, b) {
        final aStrong = a.$2?.strength ?? CorrelationStrength.none;
        final bStrong = b.$2?.strength ?? CorrelationStrength.none;
        return bStrong.index.compareTo(aStrong.index);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'What moves with it'),
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.space3),
          child: Text(
            'Pearson correlation across the window, same day. A link needs at '
            'least 10 paired days and a significant p-value before it is called '
            'anything.',
            style: AppTextStyles.cardBody.copyWith(height: 1.45),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.hairline),
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (final pair in ranked)
                _CorrelationRow(
                  other: pair.$1,
                  correlation: pair.$2,
                  isLast: pair == ranked.last,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CorrelationRow extends StatelessWidget {
  const _CorrelationRow({
    required this.other,
    required this.correlation,
    required this.isLast,
  });

  final MetricKey other;
  final Correlation? correlation;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final meta = metricMeta[other]!;
    final link = correlation;
    final hasLink = link != null && link.strength != CorrelationStrength.none;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space4,
        vertical: AppSpacing.space3,
      ),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: AppColors.hairline, width: 1),
              ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meta.label,
                  style: AppTextStyles.bodySmall.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  link == null
                      ? 'Not enough paired days'
                      : hasLink
                      ? '${link.strength.name} ${link.direction.name} link · '
                            'n = ${link.n}'
                      : 'No measurable link · n = ${link.n}',
                  style: AppTextStyles.cardMeta.copyWith(fontSize: 10),
                ),
              ],
            ),
          ),
          Text(
            link == null ? '—' : 'r = ${link.r}',
            style: AppTextStyles.h6.copyWith(
              fontSize: 13,
              letterSpacing: 0,
              color: hasLink ? AppColors.ink : AppColors.faint,
            ),
          ),
        ],
      ),
    );
  }
}

/// Findings that cite this metric, so the drilldown connects back to the plan.
class _RelatedInsights extends ConsumerWidget {
  const _RelatedInsights({required this.metric});

  final MetricKey metric;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final related = ref
        .watch(insightsProvider)
        .where(
          (insight) => insight.evidence.correlations.any(
            (c) => c.metric == metric,
          ),
        )
        .toList();

    if (related.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: 'Findings citing this', count: related.length),
        Column(
          spacing: AppSpacing.space2,
          children: [
            for (final insight in related)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.space4),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.hairline),
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      insight.title,
                      style: AppTextStyles.cardTitle.copyWith(fontSize: 14),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      insight.summary,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.cardBody.copyWith(height: 1.45),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}
