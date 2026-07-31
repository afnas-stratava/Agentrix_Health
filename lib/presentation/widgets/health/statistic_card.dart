import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/util/iso_day.dart';
import '../../../core/widgets/charts/day_column_chart.dart';
import '../../../core/widgets/charts/day_strip.dart';
import '../../../domain/entities/health/daily_snapshot.dart';
import '../../../domain/entities/health/metric_key.dart';

/// A week of one metric, day by day, scoped by the strip above it.
///
/// The metric picker and the day strip both scope everything inside this card,
/// and they sit above the figure rather than inside it — so the columns, the
/// callout and the summary line can never disagree about what is on screen.
///
/// This is an **emphasis** chart: every column is the same measure, so they
/// share one hue and the selected day is picked out with a darker step of it.
/// Giving each day its own colour would spend the identity channel re-encoding
/// what column height already shows.
class StatisticCard extends ConsumerStatefulWidget {
  const StatisticCard({super.key, required this.series});

  /// Day-aligned, oldest first.
  final List<DailySnapshot> series;

  /// The metrics worth a column chart — daily totals, where a bar's area
  /// genuinely means something. HRV and resting heart rate are point-in-time
  /// readings and belong in the sparkline tiles instead.
  static const List<MetricKey> plottable = [
    MetricKey.activeEnergy,
    MetricKey.steps,
    MetricKey.sleepDuration,
  ];

  @override
  ConsumerState<StatisticCard> createState() => _StatisticCardState();
}

class _StatisticCardState extends ConsumerState<StatisticCard> {
  MetricKey _metric = MetricKey.activeEnergy;

  /// Null tracks "the latest day" so the card follows fresh data in, rather
  /// than pinning to whatever index happened to be last on the previous build.
  int? _selected;

  static const int _windowDays = 7;

  List<DailySnapshot> get _window {
    final series = widget.series;
    return series.length <= _windowDays
        ? series
        : series.sublist(series.length - _windowDays);
  }

  String _format(double value) {
    final meta = metricMeta[_metric]!;
    final number = _metric == MetricKey.steps
        ? NumberFormat.decimalPattern().format(value.round())
        : value.toStringAsFixed(meta.precision);
    return meta.unit.isEmpty ? number : '$number ${meta.unit}';
  }

  @override
  Widget build(BuildContext context) {
    final window = _window;
    if (window.isEmpty) return const SizedBox.shrink();

    final values = window.map((s) => s.readMetric(_metric)).toList();
    final selected = (_selected ?? window.length - 1).clamp(
      0,
      window.length - 1,
    );
    final selectedDay = window[selected].day;

    final present = values.whereType<double>().toList();
    final total = present.fold<double>(0, (sum, v) => sum + v);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.hairline),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      padding: const EdgeInsets.all(AppSpacing.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DayStrip(
            days: window.map((s) => s.day).toList(),
            selected: selectedDay,
            onSelect: (day) => setState(() {
              _selected = window.indexWhere((s) => s.day == day);
            }),
          ),
          const SizedBox(height: AppSpacing.space3),

          // One filter row, above everything it scopes.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              spacing: AppSpacing.space2,
              children: [
                for (final key in StatisticCard.plottable)
                  _MetricPill(
                    label: metricMeta[key]!.short,
                    selected: key == _metric,
                    onTap: () => setState(() => _metric = key),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.space4),

          // The chart's own title names the single series, which is why there
          // is no one-swatch legend box below it.
          Text(
            metricMeta[_metric]!.label,
            style: AppTextStyles.cardTitle.copyWith(fontSize: 15),
          ),
          Text(
            present.isEmpty
                ? 'No data in this window'
                : '${_format(total / present.length)} daily average '
                      'over ${present.length} '
                      '${present.length == 1 ? 'day' : 'days'}',
            style: AppTextStyles.cardMeta.copyWith(fontSize: 11),
          ),
          const SizedBox(height: AppSpacing.space3),

          DayColumnChart(
            values: values,
            labels: [
              for (final snapshot in window)
                DateFormat('E').format(fromIsoDay(snapshot.day)).substring(0, 1),
            ],
            selectedIndex: selected,
            formatValue: _format,
            onSelect: (index) => setState(() => _selected = index),
          ),
          const SizedBox(height: AppSpacing.space3),

          // The selected day in words. The callout carries the number, but a
          // bare figure over a one-letter axis label is easy to misread, and
          // this keeps every value reachable without tapping.
          Row(
            spacing: 6,
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 12,
                color: AppColors.faint,
              ),
              Expanded(
                child: Text(
                  values[selected] == null
                      ? '${formatRelativeDay(selectedDay)} — no data recorded'
                      : '${formatRelativeDay(selectedDay)} · '
                            '${_format(values[selected]!)}',
                  style: AppTextStyles.cardMeta.copyWith(
                    fontSize: 11,
                    color: AppColors.muted,
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

class _MetricPill extends StatelessWidget {
  const _MetricPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      inMutuallyExclusiveGroup: true,
      selected: selected,
      child: Material(
        color: selected ? AppColors.brand50 : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(
                color: selected ? AppColors.brand400 : AppColors.hairline,
              ),
            ),
            child: Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? AppColors.brand700 : AppColors.muted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
