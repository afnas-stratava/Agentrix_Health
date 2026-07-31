import 'dart:math' as math;

import '../../core/stats/stats.dart';
import '../../core/util/iso_day.dart';
import '../../domain/entities/health/daily_snapshot.dart';
import '../../domain/entities/health/metric_key.dart';
import '../../domain/entities/insights/correlation.dart';
import '../../domain/entities/labs/biomarker.dart';

/// Ported from `src/features/correlation/context.ts`.

/// Trailing window treated as "now".
const int recentWindowDays = 7;

/// Window immediately preceding `recent`, used as the personal baseline.
const int baselineWindowDays = 28;

/// Below this, a baseline is too thin to make claims from.
const int minBaselineDays = 7;

enum BiologicalSex {
  male('male'),
  female('female'),
  unspecified('unspecified');

  const BiologicalSex(this.wireName);

  final String wireName;
}

class MetricStats {
  const MetricStats({
    required this.key,
    required this.values,
    required this.latest,
    required this.recentMean,
    required this.baselineMean,
    required this.z,
    required this.deltaPct,
    required this.slopePerDay,
    required this.coverage,
    required this.baselineDays,
  });

  final MetricKey key;

  /// Day-aligned series, null where telemetry is missing.
  final List<double?> values;

  final double? latest;
  final double? recentMean;
  final double? baselineMean;

  /// Latest value expressed in baseline standard deviations.
  final double z;

  /// Recent mean vs. baseline mean, as a percentage.
  final double? deltaPct;

  /// OLS slope across the recent window, in units per day.
  final double slopePerDay;

  /// Fraction of days in the window that carry a value, 0–1.
  final double coverage;

  final int baselineDays;
}

MetricStats _buildMetricStats(List<DailySnapshot> series, MetricKey key) {
  final values = series.map((snapshot) => snapshot.readMetric(key)).toList();

  final recentSlice = values.sublist(
    math.max(0, values.length - recentWindowDays),
  );
  final baselineSlice = values.sublist(
    math.max(0, values.length - recentWindowDays - baselineWindowDays),
    math.max(0, values.length - recentWindowDays),
  );

  final recent = compact(recentSlice);
  final baseline = compact(baselineSlice);
  final present = compact(values);

  double? latest;
  for (var i = values.length - 1; i >= 0; i -= 1) {
    if (values[i] != null) {
      latest = values[i];
      break;
    }
  }

  final recentMean = recent.isNotEmpty ? mean(recent) : null;
  final baselineMean = baseline.length >= minBaselineDays
      ? mean(baseline)
      : null;

  return MetricStats(
    key: key,
    values: values,
    latest: latest,
    recentMean: recentMean,
    baselineMean: baselineMean,
    z: latest != null && baseline.length >= minBaselineDays
        ? zScore(latest, baseline)
        : 0.0,
    deltaPct: recentMean != null && baselineMean != null
        ? percentChange(baselineMean, recentMean)
        : null,
    slopePerDay: linearSlope(recent),
    coverage: values.isEmpty ? 0 : present.length / values.length,
    baselineDays: baseline.length,
  );
}

class EngineContext {
  EngineContext({
    required this.days,
    required this.series,
    required this.metrics,
    required this.labReportId,
    required this.labCollectedAt,
    required this.sex,
    required this.now,
    this.biomarkers = const {},
  });

  final List<IsoDay> days;
  final List<DailySnapshot> series;
  final Map<MetricKey, MetricStats> metrics;

  /// Latest value per biomarker code, already unit-converted and flagged.
  ///
  /// Keyed rather than listed because every rule looks up by code, and an
  /// unmapped analyte has nothing a rule could match on.
  final Map<BiomarkerCode, Biomarker> biomarkers;

  final String? labReportId;
  final String? labCollectedAt;
  final BiologicalSex sex;
  final String now;

  final Map<String, Correlation?> _correlationCache = {};

  /// Correlates two metrics with an optional lag; null when under-powered.
  Correlation? correlate(MetricKey a, MetricKey b, [int lagDays = 0]) {
    final cacheKey = '${a.wireName}|${b.wireName}|$lagDays';
    if (_correlationCache.containsKey(cacheKey)) {
      return _correlationCache[cacheKey];
    }

    final paired = pairSeries(metrics[a]!.values, metrics[b]!.values, lagDays);
    final n = paired.x.length;
    final r = pearson(paired.x, paired.y);

    if (!r.isFinite || n < 10) {
      _correlationCache[cacheKey] = null;
      return null;
    }

    final p = correlationPValue(r, n);
    final strength = classifyStrength(r, p, n);

    final result = Correlation(
      metric: a,
      r: (r * 1000).round() / 1000,
      p: (p * 10000).round() / 10000,
      n: n,
      lagDays: lagDays,
      strength: strength,
      direction: strength == CorrelationStrength.none
          ? CorrelationDirection.none
          : r > 0
          ? CorrelationDirection.positive
          : CorrelationDirection.negative,
    );

    _correlationCache[cacheKey] = result;
    return result;
  }
}

EngineContext buildEngineContext({
  required List<DailySnapshot> series,
  List<Biomarker> biomarkers = const [],
  String? labReportId,
  String? labCollectedAt,
  BiologicalSex sex = BiologicalSex.unspecified,
  String? now,

  /// How far back correlations look, from Settings. The recent/baseline split
  /// is unaffected — that is physiology, not a preference — but a longer window
  /// gives `correlate` more paired days to work with, which is the whole point
  /// of the setting.
  int? analysisWindowDays,
}) {
  final windowed = analysisWindowDays == null
      ? series
      : series.sublist(math.max(0, series.length - analysisWindowDays));

  final metrics = <MetricKey, MetricStats>{
    for (final key in MetricKey.values) key: _buildMetricStats(windowed, key),
  };

  return EngineContext(
    days: windowed.map((s) => s.day).toList(),
    series: windowed,
    metrics: metrics,
    biomarkers: {
      for (final biomarker in biomarkers)
        if (biomarker.code != null) biomarker.code!: biomarker,
    },
    labReportId: labReportId,
    labCollectedAt: labCollectedAt,
    sex: sex,
    now: now ?? nowIso(),
  );
}

/// True when the window has enough signal for the engine to say anything.
bool hasSufficientTelemetry(EngineContext context) => MetricKey.values.any(
  (key) => context.metrics[key]!.baselineDays >= minBaselineDays,
);
