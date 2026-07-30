import '../../../core/stats/stats.dart';
import '../health/metric_key.dart';

/// Ported from `src/schemas/insights.ts`.

enum CorrelationDirection { positive, negative, none }

/// Strength of a statistical link, exposed to the UI as plain language.
class Correlation {
  const Correlation({
    required this.metric,
    required this.r,
    required this.p,
    required this.n,
    required this.strength,
    required this.direction,
    this.lagDays = 0,
  });

  final MetricKey metric;

  /// Pearson r over the analysis window, −1…1.
  final double r;

  /// Two-tailed p-value from the t-approximation.
  final double p;

  /// Sample size (paired days) behind [r].
  final int n;

  /// Lag in days applied to the metric before correlating.
  final int lagDays;

  final CorrelationStrength strength;
  final CorrelationDirection direction;

  Map<String, dynamic> toJson() => {
    'metric': metric.wireName,
    'r': r,
    'p': p,
    'n': n,
    'lagDays': lagDays,
    'strength': strength.name,
    'direction': direction.name,
  };
}

enum InsightSeverity { info, watch, action, urgent }

enum InsightDomain {
  nutrition('nutrition'),
  training('training'),
  sleep('sleep'),
  recovery('recovery'),
  stress('stress'),
  medicalReferral('medical-referral');

  const InsightDomain(this.wireName);

  final String wireName;
}
