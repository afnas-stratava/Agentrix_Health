import 'dart:math' as math;

import '../../domain/entities/health/metric_key.dart';
import '../../domain/entities/insights/readiness.dart';
import 'engine_context.dart';

/// Ported from `src/features/correlation/readiness.ts`.
///
/// Composite readiness, expressed against the user's *own* baseline rather than
/// a population norm — a 42 ms HRV is excellent for one person and a red flag
/// for another.
///
/// Weights reflect how much each signal independently predicts next-day
/// capacity. HRV dominates, resting heart rate confirms it, sleep supplies the
/// mechanism, and load is a modest negative when it outruns recovery.
///
/// Insertion order is load-bearing only for tie-breaking `baselineDays`; it is
/// preserved here to match the JavaScript object-key iteration order of the
/// original.
const Map<MetricKey, double> _weights = {
  MetricKey.hrv: 0.4,
  MetricKey.restingHeartRate: 0.25,
  MetricKey.sleepDuration: 0.2,
  MetricKey.sleepEfficiency: 0.15,
};

/// z-scores beyond this are almost always artefacts (missed strap, illness).
const double _zClamp = 2.5;

/// Bands are symmetric about 50, because 50 *is* "exactly at your own
/// baseline". An asymmetric ramp would tell a perfectly average day it was a
/// bad one, which erodes trust in the number faster than any inaccuracy.
ReadinessBand _band(int score) {
  if (score < 30) return ReadinessBand.compromised;
  if (score < 45) return ReadinessBand.low;
  if (score < 65) return ReadinessBand.moderate;
  return ReadinessBand.primed;
}

Readiness? computeReadiness(EngineContext context) {
  final drivers = <ReadinessDriver>[];
  var weighted = 0.0;
  var weightUsed = 0.0;
  var baselineDays = 0;

  for (final entry in _weights.entries) {
    final key = entry.key;
    final weight = entry.value;
    final stats = context.metrics[key]!;
    if (stats.baselineDays < minBaselineDays || stats.latest == null) continue;

    baselineDays = math.max(baselineDays, stats.baselineDays);

    final clamped = math.max(-_zClamp, math.min(_zClamp, stats.z));
    // Flip the sign for metrics where lower is better, so a positive
    // contribution always means "this is helping you today".
    final oriented = metricPolarity[key] == MetricPolarity.lowerIsBetter
        ? -clamped
        : clamped;

    weighted += oriented * weight;
    weightUsed += weight;

    drivers.add(
      ReadinessDriver(
        metric: key,
        contribution: (((oriented * weight) / _zClamp) * 50 * 10).round() / 10,
        z: (clamped * 100).round() / 100,
      ),
    );
  }

  // With no usable baseline, showing a number would be inventing one.
  if (weightUsed == 0 || baselineDays < minBaselineDays) return null;

  // Normalise to the weight actually available, then map z ∈ [−2.5, 2.5] onto
  // 0–100 centred at 50 (= exactly at your own baseline).
  final normalisedZ = weighted / weightUsed;
  final score = math
      .min(100.0, math.max(0.0, 50 + (normalisedZ / _zClamp) * 50))
      .round();

  drivers.sort((a, b) => b.contribution.abs().compareTo(a.contribution.abs()));

  return Readiness(
    score: score,
    band: _band(score),
    drivers: drivers,
    baselineDays: baselineDays,
    computedAt: context.now,
  );
}
