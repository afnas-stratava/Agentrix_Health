import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../core/util/iso_day.dart';
import '../../domain/entities/health/metric_key.dart';
import '../../domain/entities/insights/correlation.dart';
import '../../domain/entities/insights/insight.dart';
import '../../domain/entities/labs/biomarker.dart';
import '../../domain/entities/labs/lab_report.dart';
import 'engine_context.dart';
import 'rules.dart';

/// The correlation engine. Ported from `src/features/correlation/engine.ts`.
///
/// Evaluates every rule against the context and returns ranked findings. Pure
/// and synchronous: no I/O and no clock reads beyond `context.now`, so the same
/// inputs always produce the same output — which is what makes it testable and
/// the UI cacheable.

/// Beyond this, a lab result is stale enough to discount heavily.
const int _labHalfLifeDays = 120;

const int maxInsights = 12;

/// Adjusts a rule's base score for how much we should actually trust it.
///
///  - Lab recency — a ferritin from 14 months ago is a historical footnote.
///  - Extraction confidence — a value read at 0.6 confidence is provisional.
///  - Telemetry coverage — a 40%-covered window supports weaker claims.
///
/// Medical-referral insights are floored, because "go see a doctor" should not
/// fall off the list just because the underlying data is imperfect.
int _scoreInsight(RuleOutput output, EngineContext context) {
  var multiplier = 1.0;

  final collectedAt = context.labCollectedAt;
  if (collectedAt != null && output.biomarkerCodes.isNotEmpty) {
    final collected = DateTime.tryParse(collectedAt);
    if (collected != null) {
      final ageDays = math.max(
        0,
        daysBetween(collected, DateTime.parse(context.now)),
      );
      multiplier *= math.pow(0.5, ageDays / _labHalfLifeDays);
    }
  }

  final confidences = output.biomarkerCodes
      .map((code) => context.biomarkers[code]?.confidence)
      .whereType<double>()
      .toList();
  if (confidences.isNotEmpty) {
    multiplier *= confidences.reduce(math.min);
  }

  final coverages = context.metrics.values.map((m) => m.coverage).toList();
  final meanCoverage = coverages.isEmpty
      ? 0.0
      : coverages.reduce((a, b) => a + b) / coverages.length;
  multiplier *= 0.6 + 0.4 * math.min(1, meanCoverage);

  final scored = output.baseScore * multiplier;
  final floor = output.domain == InsightDomain.medicalReferral
      ? output.baseScore * 0.75
      : 0.0;

  return math.min(100, math.max(floor, scored)).round();
}

/// Builds an [Insight], or null when the rule produced something unusable.
///
/// The validation matters: a rule with an empty title or no suggestions is a
/// bug, and it must not take the whole insights surface down with it.
Insight? _toInsight(Rule rule, RuleOutput output, EngineContext context) {
  final evidenceBiomarkers = output.biomarkerCodes
      .map((code) {
        final biomarker = context.biomarkers[code];
        if (biomarker == null) return null;
        return EvidenceBiomarker(
          code: code,
          displayName: biomarker.displayName,
          value: biomarker.value,
          unit: biomarker.unit,
          flag: biomarker.flag,
        );
      })
      .whereType<EvidenceBiomarker>()
      .toList();

  if (output.title.isEmpty ||
      output.summary.isEmpty ||
      output.suggestions.isEmpty) {
    debugPrint('Rule "${rule.id}" produced an incomplete insight; skipping.');
    return null;
  }

  return Insight(
    // Deterministic id: the same finding across recomputations keeps its
    // identity, so a dismissal in the UI persists.
    id: 'insight_${rule.id}_${context.labReportId ?? 'telemetry'}',
    ruleId: rule.id,
    title: output.title,
    summary: output.summary,
    severity: output.severity,
    domain: output.domain,
    score: _scoreInsight(output, context),
    evidence: Evidence(
      biomarkers: evidenceBiomarkers,
      correlations: output.correlations,
      telemetryNote: output.telemetryNote,
      citations: output.citations,
    ),
    suggestions: output.suggestions,
    generatedAt: context.now,
    labReportId: output.biomarkerCodes.isNotEmpty ? context.labReportId : null,
  );
}

List<Insight> runEngine(
  EngineContext context, {
  /// Rule ids the user has muted.
  Set<String> mutedRuleIds = const {},
  int limit = maxInsights,
}) {
  if (!hasSufficientTelemetry(context) && context.biomarkers.isEmpty) {
    return const [];
  }

  final insights = <Insight>[];

  for (final rule in rules) {
    if (mutedRuleIds.contains(rule.id)) continue;

    RuleOutput? output;
    try {
      output = rule.evaluate(context);
    } catch (error) {
      // One malformed rule must not empty the insights tab.
      debugPrint('Rule "${rule.id}" threw during evaluation: $error');
      continue;
    }

    if (output == null) continue;

    final insight = _toInsight(rule, output, context);
    if (insight != null) insights.add(insight);
  }

  insights.sort((a, b) {
    final bySeverity = b.severity.rank.compareTo(a.severity.rank);
    return bySeverity != 0 ? bySeverity : b.score.compareTo(a.score);
  });

  return insights.take(limit).toList();
}

/// Flattens the suggestions across insights, de-duplicated by id.
///
/// Two rules can legitimately recommend the same thing; the user should see it
/// once, attributed to the strongest finding that asked for it.
List<({Suggestion suggestion, Insight insight})> collectSuggestions(
  List<Insight> insights,
) {
  final seen = <String>{};
  final out = <({Suggestion suggestion, Insight insight})>[];

  for (final insight in insights) {
    for (final suggestion in insight.suggestions) {
      if (!seen.add(suggestion.id)) continue;
      out.add((suggestion: suggestion, insight: insight));
    }
  }

  return out;
}

/// Chronologically-latest biomarker per code, for building engine context.
///
/// Reports are sorted oldest-first and later values overwrite earlier ones, so a
/// fresh panel supersedes a stale one per-analyte rather than wholesale — which
/// matters when a recent panel is narrower than an older one. Unmapped analytes
/// are carried through rather than dropped: they are still the user's results.
List<Biomarker> mergeBiomarkers(List<LabReport> reports) {
  final sorted = [...reports]
    ..sort((a, b) {
      final aTime = a.collectedAt ?? a.uploadedAt;
      final bTime = b.collectedAt ?? b.uploadedAt;
      return aTime.compareTo(bTime);
    });

  final byCode = <BiomarkerCode, Biomarker>{};
  final unmapped = <Biomarker>[];

  for (final report in sorted) {
    for (final biomarker in report.biomarkers) {
      final code = biomarker.code;
      if (code == null) {
        unmapped.add(biomarker);
        continue;
      }
      byCode[code] = biomarker;
    }
  }

  return [...byCode.values, ...unmapped];
}

/// Plain-language rendering of a correlation, for the evidence list.
///
/// Deliberately states n alongside r: an r of 0.6 over 11 days and the same r
/// over 60 days are very different claims, and hiding the sample size is how
/// correlation UIs mislead.
String describeCorrelation(Correlation correlation) {
  final direction = switch (correlation.direction) {
    CorrelationDirection.positive => 'rises with',
    CorrelationDirection.negative => 'falls as',
    CorrelationDirection.none => 'shows no clear link to',
  };

  final lag = correlation.lagDays == 0
      ? 'same day'
      : '${correlation.lagDays}-day lag';

  return '${metricMeta[correlation.metric]!.label} $direction the paired '
      'metric (r = ${correlation.r}, n = ${correlation.n}, $lag)';
}
