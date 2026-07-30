import '../labs/biomarker.dart';
import 'correlation.dart';

/// Ported from the `Suggestion` / `Evidence` / `Insight` half of
/// `src/schemas/insights.ts`.

/// Rough cost to the user, which orders suggestions within an insight.
enum SuggestionEffort {
  low('low'),
  medium('medium'),
  high('high');

  const SuggestionEffort(this.wireName);

  final String wireName;

  int get rank => index;
}

class Suggestion {
  const Suggestion({
    required this.id,
    required this.title,
    required this.detail,
    required this.domain,
    required this.effort,
    required this.horizonDays,
  });

  final String id;
  final String title;

  /// One sentence, imperative and specific. "Add 2 Brazil nuts daily", never
  /// "eat better" — a suggestion the user cannot act on today is noise.
  final String detail;

  final InsightDomain domain;
  final SuggestionEffort effort;

  /// Expected time-to-signal before the linked metric should move. Setting
  /// expectations is the difference between a plan someone sticks to and one
  /// they abandon in week two.
  final int horizonDays;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'detail': detail,
    'domain': domain.wireName,
    'effort': effort.wireName,
    'horizonDays': horizonDays,
  };
}

/// A biomarker as cited by an insight — a snapshot, not a live reference, so the
/// evidence shown alongside a finding is the evidence that produced it.
class EvidenceBiomarker {
  const EvidenceBiomarker({
    required this.code,
    required this.displayName,
    required this.value,
    required this.unit,
    required this.flag,
  });

  final BiomarkerCode code;
  final String displayName;
  final double value;
  final String unit;
  final BiomarkerFlag flag;

  String get valueWithUnit {
    final rounded = (value * 100).round() / 100;
    final label = rounded == rounded.roundToDouble()
        ? '${rounded.round()}'
        : '$rounded';
    return '$label $unit';
  }
}

class Citation {
  const Citation({required this.label, required this.url});

  final String label;
  final String url;
}

class Evidence {
  const Evidence({
    this.biomarkers = const [],
    this.correlations = const [],
    this.telemetryNote,
    this.citations = const [],
  });

  final List<EvidenceBiomarker> biomarkers;
  final List<Correlation> correlations;

  /// Short plain-language statement of the telemetry pattern that fired.
  final String? telemetryNote;

  /// Curated links to standing clinical references, fixed at authoring time and
  /// never generated at runtime.
  final List<Citation> citations;

  bool get isEmpty =>
      biomarkers.isEmpty &&
      correlations.isEmpty &&
      telemetryNote == null &&
      citations.isEmpty;
}

class Insight {
  const Insight({
    required this.id,
    required this.ruleId,
    required this.title,
    required this.summary,
    required this.severity,
    required this.domain,
    required this.score,
    required this.evidence,
    required this.suggestions,
    required this.generatedAt,
    this.labReportId,
  });

  final String id;

  /// Stable rule identifier, so a dismissal survives re-computation.
  final String ruleId;

  final String title;
  final String summary;
  final InsightSeverity severity;
  final InsightDomain domain;

  /// 0–100 ranking score, after the engine's recency and confidence multipliers.
  final int score;

  final Evidence evidence;

  /// Never empty — an insight with no suggested action is an observation, and
  /// the engine drops it rather than showing one.
  final List<Suggestion> suggestions;

  final String generatedAt;

  /// Which lab report anchored this insight, when one did.
  final String? labReportId;

  /// True when the finding rests on both blood work and telemetry — the
  /// intersection this product exists to surface.
  bool get isCrossDomain =>
      evidence.biomarkers.isNotEmpty && evidence.telemetryNote != null;

  /// Suggestions ordered cheapest-first, so the easiest win is on top.
  List<Suggestion> get suggestionsByEffort {
    final out = [...suggestions];
    out.sort((a, b) {
      final byEffort = a.effort.rank.compareTo(b.effort.rank);
      return byEffort != 0
          ? byEffort
          : a.horizonDays.compareTo(b.horizonDays);
    });
    return out;
  }
}

extension InsightSeverityCopy on InsightSeverity {
  String get label => switch (this) {
    InsightSeverity.urgent => 'See a clinician',
    InsightSeverity.action => 'Act on this',
    InsightSeverity.watch => 'Worth watching',
    InsightSeverity.info => 'For information',
  };

  /// Ranking weight. Severity always outranks score, so a referral never sits
  /// below a high-scoring nutrition tip.
  int get rank => switch (this) {
    InsightSeverity.urgent => 3,
    InsightSeverity.action => 2,
    InsightSeverity.watch => 1,
    InsightSeverity.info => 0,
  };
}

extension InsightDomainCopy on InsightDomain {
  String get label => switch (this) {
    InsightDomain.nutrition => 'Nutrition',
    InsightDomain.training => 'Training',
    InsightDomain.sleep => 'Sleep',
    InsightDomain.recovery => 'Recovery',
    InsightDomain.stress => 'Stress',
    InsightDomain.medicalReferral => 'Medical',
  };
}
