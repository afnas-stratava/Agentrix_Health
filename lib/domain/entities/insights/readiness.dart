import '../health/metric_key.dart';

/// Ported from `src/schemas/insights.ts`.

enum ReadinessBand { compromised, low, moderate, primed }

class ReadinessDriver {
  const ReadinessDriver({
    required this.metric,
    required this.contribution,
    required this.z,
  });

  final MetricKey metric;

  /// Signed contribution to the score, in points.
  final double contribution;

  /// z-score of today vs. baseline.
  final double z;

  Map<String, dynamic> toJson() => {
        'metric': metric.wireName,
        'contribution': contribution,
        'z': z,
      };
}

class Readiness {
  const Readiness({
    required this.score,
    required this.band,
    required this.drivers,
    required this.baselineDays,
    required this.computedAt,
  });

  /// 0–100 composite of HRV, RHR, sleep and load, vs. the 28-day baseline.
  final int score;

  final ReadinessBand band;
  final List<ReadinessDriver> drivers;

  /// Days of data behind the baseline; below 7 the score is suppressed.
  final int baselineDays;

  final String computedAt;

  Map<String, dynamic> toJson() => {
        'score': score,
        'band': band.name,
        'drivers': drivers.map((d) => d.toJson()).toList(),
        'baselineDays': baselineDays,
        'computedAt': computedAt,
      };
}

class ReadinessCopy {
  const ReadinessCopy({required this.label, required this.blurb});

  final String label;
  final String blurb;
}

const Map<ReadinessBand, ReadinessCopy> readinessCopy = {
  ReadinessBand.compromised: ReadinessCopy(
    label: 'Compromised',
    blurb:
        'Your autonomic markers are well below baseline. Treat today as recovery.',
  ),
  ReadinessBand.low: ReadinessCopy(
    label: 'Low',
    blurb:
        'Below your normal. Keep intensity conversational and protect sleep tonight.',
  ),
  ReadinessBand.moderate: ReadinessCopy(
    label: 'Moderate',
    blurb: 'Around your baseline. A normal training day is well within range.',
  ),
  ReadinessBand.primed: ReadinessCopy(
    label: 'Primed',
    blurb: 'Recovery markers are above baseline — a good day for hard work.',
  ),
};
