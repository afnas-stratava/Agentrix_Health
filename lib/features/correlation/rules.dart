import 'dart:math' as math;

import '../../core/stats/stats.dart';
import '../../core/util/iso_day.dart';
import '../../domain/entities/health/metric_key.dart';
import '../../domain/entities/insights/correlation.dart';
import '../../domain/entities/insights/insight.dart';
import '../../domain/entities/labs/biomarker.dart';
import 'engine_context.dart';

/// Rule catalogue. Ported from `src/features/correlation/rules.ts`.
///
/// Each rule is a pure predicate over telemetry + biomarkers. A rule fires only
/// when BOTH sides agree — a lab value alone is a number on a page, and a
/// telemetry drift alone is a bad night's sleep. The intersection is the only
/// place this product has something to say that Apple Health does not.
///
/// Nothing here diagnoses. Severity `urgent` never means "you have X"; it means
/// "take this printout to a clinician".
///
/// Citations are curated links to standing clinical references (NIH ODS,
/// professional societies). They are fixed at authoring time and never generated
/// at runtime — a fabricated citation on a health claim is the worst failure
/// mode this file has.

class RuleOutput {
  const RuleOutput({
    required this.title,
    required this.summary,
    required this.severity,
    required this.domain,
    required this.baseScore,
    required this.suggestions,
    this.biomarkerCodes = const [],
    this.telemetryNote,
    this.correlations = const [],
    this.citations = const [],
  });

  final String title;
  final String summary;
  final InsightSeverity severity;
  final InsightDomain domain;

  /// 0–100 before the engine applies its recency and confidence multipliers.
  final int baseScore;

  final List<BiomarkerCode> biomarkerCodes;
  final String? telemetryNote;
  final List<Correlation> correlations;
  final List<Citation> citations;
  final List<Suggestion> suggestions;
}

class Rule {
  const Rule({
    required this.id,
    required this.name,
    required this.evaluate,
  });

  final String id;

  /// Short label used where rules can be muted.
  final String name;

  final RuleOutput? Function(EngineContext context) evaluate;
}

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

Suggestion _suggestion(
  String id,
  String title,
  String detail,
  InsightDomain domain,
  SuggestionEffort effort,
  int horizonDays,
) => Suggestion(
  id: id,
  title: title,
  detail: detail,
  domain: domain,
  effort: effort,
  horizonDays: horizonDays,
);

/// A metric is "suppressed" when the recent mean sits meaningfully below
/// baseline. A thin baseline never counts — that is how a two-day-old install
/// starts announcing findings.
bool _isSuppressed(EngineContext context, MetricKey key, [double pct = -8]) {
  final stats = context.metrics[key]!;
  if (stats.baselineDays < minBaselineDays || stats.deltaPct == null) {
    return false;
  }
  return stats.deltaPct! <= pct;
}

bool _isElevated(EngineContext context, MetricKey key, [double pct = 5]) {
  final stats = context.metrics[key]!;
  if (stats.baselineDays < minBaselineDays || stats.deltaPct == null) {
    return false;
  }
  return stats.deltaPct! >= pct;
}

/// Absolute percentage, for prose that already carries the direction in words.
String _pct(double? value) =>
    value == null ? '—' : '${value.abs().round()}%';

String _thousands(num value) {
  final digits = value.round().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i += 1) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// Keeps only a correlation strong enough to cite. A null or `none` link must
/// never appear as evidence — quoting a non-significant r is worse than quoting
/// nothing.
List<Correlation> _significant(Correlation? correlation) =>
    correlation != null && correlation.strength != CorrelationStrength.none
    ? [correlation]
    : const [];

bool _isLowFlag(BiomarkerFlag flag) => const {
  BiomarkerFlag.low,
  BiomarkerFlag.criticalLow,
  BiomarkerFlag.borderlineLow,
}.contains(flag);

bool _isHighFlag(BiomarkerFlag flag) => const {
  BiomarkerFlag.high,
  BiomarkerFlag.criticalHigh,
  BiomarkerFlag.borderlineHigh,
}.contains(flag);

class _Citations {
  static const iron = Citation(
    label: 'NIH Office of Dietary Supplements — Iron',
    url: 'https://ods.od.nih.gov/factsheets/Iron-HealthProfessional/',
  );
  static const vitaminD = Citation(
    label: 'NIH Office of Dietary Supplements — Vitamin D',
    url: 'https://ods.od.nih.gov/factsheets/VitaminD-HealthProfessional/',
  );
  static const b12 = Citation(
    label: 'NIH Office of Dietary Supplements — Vitamin B12',
    url: 'https://ods.od.nih.gov/factsheets/VitaminB12-HealthProfessional/',
  );
  static const magnesium = Citation(
    label: 'NIH Office of Dietary Supplements — Magnesium',
    url: 'https://ods.od.nih.gov/factsheets/Magnesium-HealthProfessional/',
  );
  static const cholesterol = Citation(
    label: 'American Heart Association — Cholesterol',
    url: 'https://www.heart.org/en/health-topics/cholesterol',
  );
  static const prediabetes = Citation(
    label: 'CDC — Prediabetes',
    url:
        'https://www.cdc.gov/diabetes/prevention-type-2/prediabetes-risk-factors.html',
  );
  static const thyroid = Citation(
    label: 'American Thyroid Association — Hypothyroidism',
    url: 'https://www.thyroid.org/hypothyroidism/',
  );
  static const sleep = Citation(
    label: 'CDC — About Sleep',
    url: 'https://www.cdc.gov/sleep/about/index.html',
  );
  static const liver = Citation(
    label: 'American Liver Foundation — NAFLD',
    url:
        'https://liverfoundation.org/liver-diseases/fatty-liver-disease/nonalcoholic-fatty-liver-disease-nafld/',
  );
  static const physicalActivity = Citation(
    label: 'WHO — Physical Activity Guidelines',
    url:
        'https://www.who.int/news-room/fact-sheets/detail/physical-activity',
  );
}

// ---------------------------------------------------------------------------
// Rules
// ---------------------------------------------------------------------------

final _ironDeficiencyRecovery = Rule(
  id: 'iron-deficiency-recovery-drag',
  name: 'Low iron stores suppressing recovery',
  evaluate: (context) {
    final ferritin = context.biomarkers[BiomarkerCode.ferritin];
    if (ferritin == null || !_isLowFlag(ferritin.flag)) return null;

    final hrvDown = _isSuppressed(context, MetricKey.hrv, -6);
    final rhrUp = _isElevated(context, MetricKey.restingHeartRate, 3);
    if (!hrvDown && !rhrUp) return null;

    final hrv = context.metrics[MetricKey.hrv]!;
    final rhr = context.metrics[MetricKey.restingHeartRate]!;
    final isCritical = ferritin.flag == BiomarkerFlag.criticalLow;
    final isFrank = ferritin.flag != BiomarkerFlag.borderlineLow;

    final notes = <String>[
      if (hrvDown)
        'HRV is down ${_pct(hrv.deltaPct)} against your 28-day baseline',
      if (rhrUp) 'resting heart rate is up ${_pct(rhr.deltaPct)}',
    ];

    return RuleOutput(
      title: isFrank
          ? 'Low iron stores are tracking with poor recovery'
          : 'Iron stores are on the low side of normal',
      summary:
          'Ferritin of ${ferritin.valueWithUnit} sits '
          '${isFrank ? 'below' : 'at the bottom of'} the reference range, and '
          'over the same period ${notes.join(' and ')}. Reduced iron '
          'availability limits oxygen transport and mitochondrial output, which '
          'typically shows up first as depressed HRV and a drifting resting '
          'heart rate — well before you notice it as fatigue.',
      severity: isCritical
          ? InsightSeverity.urgent
          : isFrank
          ? InsightSeverity.action
          : InsightSeverity.watch,
      domain: InsightDomain.nutrition,
      baseScore: isCritical ? 96 : (isFrank ? 88 : 68),
      biomarkerCodes: [
        BiomarkerCode.ferritin,
        if (context.biomarkers.containsKey(BiomarkerCode.hemoglobin))
          BiomarkerCode.hemoglobin,
      ],
      telemetryNote: notes.join('; '),
      correlations: _significant(
        context.correlate(MetricKey.activeEnergy, MetricKey.hrv, 1),
      ),
      citations: const [_Citations.iron],
      suggestions: [
        _suggestion(
          'iron-dietary',
          'Pair iron sources with vitamin C',
          'Add 85–110 g of red meat, liver, lentils or fortified cereal to two '
              'meals a day, each alongside a vitamin-C source (bell pepper, '
              'citrus, strawberries). Ascorbate can raise non-haem iron '
              'absorption several-fold.',
          InsightDomain.nutrition,
          SuggestionEffort.low,
          60,
        ),
        _suggestion(
          'iron-inhibitors',
          'Move coffee and tea away from meals',
          'Keep tea, coffee and calcium supplements at least 60 minutes clear of '
              'iron-containing meals — polyphenols and calcium are the two '
              'strongest dietary inhibitors of iron uptake.',
          InsightDomain.nutrition,
          SuggestionEffort.low,
          45,
        ),
        _suggestion(
          'iron-clinician',
          isCritical
              ? 'Book a clinician review this week'
              : 'Ask about a full iron panel',
          isCritical
              ? 'A ferritin this low warrants a clinical work-up to establish '
                    'the cause before supplementing. Bring this report.'
              : 'Request transferrin saturation, TIBC and hs-CRP together — '
                    'ferritin is an acute-phase reactant and can read falsely '
                    'normal during inflammation.',
          InsightDomain.medicalReferral,
          isCritical ? SuggestionEffort.medium : SuggestionEffort.low,
          14,
        ),
        _suggestion(
          'iron-load-management',
          'Cap intensity until HRV recovers',
          'Hold sessions at conversational intensity while HRV is below '
              'baseline. Training hard into low iron availability deepens the '
              'deficit rather than adapting to it.',
          InsightDomain.training,
          SuggestionEffort.medium,
          21,
        ),
      ],
    );
  },
);

final _inflammationRecovery = Rule(
  id: 'inflammation-recovery-suppression',
  name: 'Systemic inflammation blunting recovery',
  evaluate: (context) {
    final crp = context.biomarkers[BiomarkerCode.hsCrp];
    if (crp == null || !_isHighFlag(crp.flag)) return null;

    final hrvDown = _isSuppressed(context, MetricKey.hrv, -5);
    final sleepFragmented = _isSuppressed(
      context,
      MetricKey.sleepEfficiency,
      -3,
    );
    if (!hrvDown && !sleepFragmented) return null;

    final isHigh = crp.flag != BiomarkerFlag.borderlineHigh;
    final hrv = context.metrics[MetricKey.hrv]!;
    final efficiency = context.metrics[MetricKey.sleepEfficiency]!;

    return RuleOutput(
      title: isHigh
          ? 'Inflammation is showing up in your recovery data'
          : 'Low-grade inflammation worth watching',
      summary:
          'hs-CRP of ${crp.valueWithUnit} indicates '
          '${isHigh ? 'meaningful' : 'low-grade'} systemic inflammation. '
          'Inflammatory cytokines shift autonomic balance toward sympathetic '
          'dominance, which is exactly the pattern in your recent telemetry'
          '${hrvDown ? ' — HRV down ${_pct(hrv.deltaPct)}' : ''}'
          '${sleepFragmented ? ' and sleep efficiency down ${_pct(efficiency.deltaPct)}' : ''}.',
      severity: crp.flag == BiomarkerFlag.criticalHigh
          ? InsightSeverity.urgent
          : (isHigh ? InsightSeverity.action : InsightSeverity.watch),
      domain: InsightDomain.recovery,
      baseScore: crp.flag == BiomarkerFlag.criticalHigh
          ? 94
          : (isHigh ? 82 : 62),
      biomarkerCodes: const [BiomarkerCode.hsCrp],
      telemetryNote: hrvDown
          ? 'HRV ${_pct(hrv.deltaPct)} below baseline over the last 7 days'
          : 'Sleep efficiency below baseline over the last 7 days',
      correlations: _significant(
        context.correlate(MetricKey.sleepDuration, MetricKey.hrv, 0),
      ),
      citations: const [_Citations.physicalActivity],
      suggestions: [
        _suggestion(
          'crp-omega3',
          'Add oily fish twice a week',
          'Two 120 g servings of salmon, mackerel or sardines per week supplies '
              'roughly 2 g/day of EPA+DHA — the dose range associated with '
              'measurable CRP reduction.',
          InsightDomain.nutrition,
          SuggestionEffort.low,
          56,
        ),
        _suggestion(
          'crp-recheck',
          'Re-test hs-CRP in 6–8 weeks',
          'A single elevated hs-CRP can reflect a transient infection. Repeat '
              'when you are symptom-free for at least two weeks; a persistently '
              'high value needs a clinical explanation.',
          InsightDomain.medicalReferral,
          SuggestionEffort.low,
          56,
        ),
        _suggestion(
          'crp-zone2',
          'Shift volume toward zone 2',
          'Replace one hard session a week with 45–60 minutes at conversational '
              'pace. Moderate aerobic volume lowers CRP; repeated '
              'high-intensity work on an inflamed baseline raises it.',
          InsightDomain.training,
          SuggestionEffort.medium,
          42,
        ),
      ],
    );
  },
);

final _vitaminDSleep = Rule(
  id: 'vitamin-d-sleep-quality',
  name: 'Vitamin D insufficiency and sleep',
  evaluate: (context) {
    final vitD = context.biomarkers[BiomarkerCode.vitaminD];
    if (vitD == null || !_isLowFlag(vitD.flag)) return null;

    final sleep = context.metrics[MetricKey.sleepDuration]!;
    final efficiency = context.metrics[MetricKey.sleepEfficiency]!;
    final poorSleep =
        (sleep.recentMean != null && sleep.recentMean! < 7) ||
        (efficiency.recentMean != null && efficiency.recentMean! < 85);
    if (!poorSleep) return null;

    final isDeficient = vitD.flag != BiomarkerFlag.borderlineLow;
    final sleepLabel = sleep.recentMean != null
        ? formatDuration(sleep.recentMean!)
        : '—';
    final efficiencyLabel = efficiency.recentMean != null
        ? '${efficiency.recentMean!.round()}%'
        : '—';

    return RuleOutput(
      title: isDeficient
          ? 'Vitamin D deficiency alongside short sleep'
          : 'Vitamin D is below the optimal band',
      summary:
          'Your 25-OH vitamin D is ${vitD.valueWithUnit}'
          '${isDeficient ? ', which meets the threshold for deficiency' : ', inside the lab range but below the 40–60 ng/mL band'}. '
          'You are averaging $sleepLabel of sleep at $efficiencyLabel '
          'efficiency. Vitamin D receptors are expressed in the brainstem '
          'regions that regulate sleep, and low status is consistently '
          'associated with shorter, more fragmented sleep.',
      severity: isDeficient ? InsightSeverity.action : InsightSeverity.watch,
      domain: InsightDomain.sleep,
      baseScore: isDeficient ? 78 : 58,
      biomarkerCodes: const [BiomarkerCode.vitaminD],
      telemetryNote:
          'Averaging ${sleep.recentMean != null ? formatDuration(sleep.recentMean!) : 'unknown'} '
          'asleep over the last 7 nights',
      correlations: _significant(
        context.correlate(MetricKey.sleepDuration, MetricKey.hrv, 0),
      ),
      citations: const [_Citations.vitaminD, _Citations.sleep],
      suggestions: [
        _suggestion(
          'vitd-morning-light',
          'Get 15 minutes of outdoor light before 10am',
          'Morning sunlight both supports cutaneous synthesis and anchors your '
              'circadian phase — the second effect is the one that shows up in '
              'sleep efficiency within a fortnight.',
          InsightDomain.sleep,
          SuggestionEffort.low,
          14,
        ),
        _suggestion(
          'vitd-supplement',
          'Discuss a repletion dose with your clinician',
          'Typical adult repletion is 2000–4000 IU/day of D3 taken with a '
              'fat-containing meal, followed by a re-test at 12 weeks. Dosing '
              'above this should be supervised.',
          InsightDomain.nutrition,
          SuggestionEffort.low,
          84,
        ),
        _suggestion(
          'vitd-k2-magnesium',
          'Take D3 with a magnesium-rich meal',
          'Magnesium is a cofactor for the hydroxylation steps that activate '
              'vitamin D. Leafy greens, pumpkin seeds or almonds at the same '
              'meal is sufficient.',
          InsightDomain.nutrition,
          SuggestionEffort.low,
          84,
        ),
      ],
    );
  },
);

final _glycemicActivity = Rule(
  id: 'glycemic-drift-low-activity',
  name: 'Glycaemic drift with low movement',
  evaluate: (context) {
    final hba1c = context.biomarkers[BiomarkerCode.hba1c];
    final glucose = context.biomarkers[BiomarkerCode.fastingGlucose];
    final marker = hba1c ?? glucose;
    if (marker == null || !_isHighFlag(marker.flag)) return null;

    final steps = context.metrics[MetricKey.steps]!;
    final energy = context.metrics[MetricKey.activeEnergy]!;
    final lowMovement =
        (steps.recentMean != null && steps.recentMean! < 7500) ||
        (energy.recentMean != null && energy.recentMean! < 350);
    if (!lowMovement) return null;

    final isPrediabetic = marker.flag != BiomarkerFlag.borderlineHigh;
    final stepsLabel = steps.recentMean != null
        ? _thousands(steps.recentMean!)
        : '—';
    final energyLabel = energy.recentMean != null
        ? '${energy.recentMean!.round()}'
        : '—';

    return RuleOutput(
      title: isPrediabetic
          ? 'Glycaemic markers are elevated and movement is low'
          : 'Blood sugar is creeping toward the upper range',
      summary:
          '${marker.displayName} of ${marker.valueWithUnit} places you '
          '${isPrediabetic ? 'in the pre-diabetic band' : 'above the optimal band'}. '
          'Over the same window you averaged $stepsLabel steps and '
          '$energyLabel kcal of active energy per day. Skeletal muscle '
          'contraction clears glucose independently of insulin, so movement '
          'volume is the fastest lever you have on this number.',
      severity: isPrediabetic ? InsightSeverity.action : InsightSeverity.watch,
      domain: InsightDomain.nutrition,
      baseScore: isPrediabetic ? 86 : 64,
      biomarkerCodes: [
        if (hba1c != null) BiomarkerCode.hba1c,
        if (glucose != null) BiomarkerCode.fastingGlucose,
        if (context.biomarkers.containsKey(BiomarkerCode.triglycerides))
          BiomarkerCode.triglycerides,
      ],
      telemetryNote:
          '$stepsLabel steps/day average over the last 7 days',
      correlations: _significant(
        context.correlate(MetricKey.steps, MetricKey.restingHeartRate, 1),
      ),
      citations: const [_Citations.prediabetes, _Citations.physicalActivity],
      suggestions: [
        _suggestion(
          'glycemic-post-meal-walk',
          'Walk 10–15 minutes after your largest meal',
          'A short walk inside 30 minutes of eating blunts the post-prandial '
              'glucose peak more effectively than the same walk at any other '
              'time of day.',
          InsightDomain.nutrition,
          SuggestionEffort.low,
          30,
        ),
        _suggestion(
          'glycemic-step-target',
          'Raise your daily floor to 8,000 steps',
          'You are averaging ${steps.recentMean != null ? _thousands(steps.recentMean!) : 'fewer'} '
              'steps. Adding roughly '
              '${steps.recentMean != null ? _thousands(math.max(500, ((8000 - steps.recentMean!) / 100).round() * 100)) : '1,500'} '
              'per day gets you to the band where insulin sensitivity improves '
              'measurably.',
          InsightDomain.training,
          SuggestionEffort.medium,
          90,
        ),
        _suggestion(
          'glycemic-resistance',
          'Add two resistance sessions a week',
          'Two full-body sessions per week build the muscle mass that acts as '
              'your glucose sink. Effects on HbA1c appear at the 10–12 week '
              're-test, not sooner.',
          InsightDomain.training,
          SuggestionEffort.medium,
          84,
        ),
        _suggestion(
          'glycemic-fibre',
          'Front-load 30 g of fibre a day',
          'Legumes, oats and intact whole grains slow gastric emptying and '
              'flatten the glucose curve. Increase gradually over two weeks to '
              'stay comfortable.',
          InsightDomain.nutrition,
          SuggestionEffort.medium,
          60,
        ),
      ],
    );
  },
);

final _insulinResistancePattern = Rule(
  id: 'triglyceride-hdl-ratio',
  name: 'Triglyceride/HDL ratio',
  evaluate: (context) {
    final tg = context.biomarkers[BiomarkerCode.triglycerides];
    final hdl = context.biomarkers[BiomarkerCode.hdl];
    if (tg == null || hdl == null || hdl.value <= 0) return null;

    final ratio = tg.value / hdl.value;
    if (ratio < 2.5) return null;

    final energy = context.metrics[MetricKey.activeEnergy]!;

    return RuleOutput(
      title: 'Your triglyceride-to-HDL ratio suggests insulin resistance',
      summary:
          'Triglycerides ${tg.valueWithUnit} against HDL ${hdl.valueWithUnit} '
          'gives a ratio of ${ratio.toStringAsFixed(1)}. Above 3.0 this ratio is '
          'one of the better cheap surrogates for insulin resistance — often '
          'flagging it years before fasting glucose moves.'
          '${energy.recentMean != null ? ' Your active energy is averaging ${energy.recentMean!.round()} kcal/day.' : ''}',
      severity: ratio >= 3.5 ? InsightSeverity.action : InsightSeverity.watch,
      domain: InsightDomain.nutrition,
      baseScore: ratio >= 3.5 ? 80 : 62,
      biomarkerCodes: [
        BiomarkerCode.triglycerides,
        BiomarkerCode.hdl,
        if (context.biomarkers.containsKey(BiomarkerCode.hba1c))
          BiomarkerCode.hba1c,
      ],
      correlations: _significant(
        context.correlate(
          MetricKey.activeEnergy,
          MetricKey.restingHeartRate,
          2,
        ),
      ),
      citations: const [_Citations.cholesterol],
      suggestions: [
        _suggestion(
          'tg-refined-carbs',
          'Cut liquid sugar and refined starch first',
          'Triglycerides respond faster to removing sugary drinks, juice and '
              'refined flour than to any other single dietary change — often '
              'within 4–6 weeks.',
          InsightDomain.nutrition,
          SuggestionEffort.medium,
          42,
        ),
        _suggestion(
          'tg-alcohol',
          'Hold alcohol to a maximum of 3 units a week',
          'Ethanol is directly lipogenic in the liver. If your triglycerides are '
              'the outlier on this panel, alcohol is the first thing to test by '
              'removing it.',
          InsightDomain.nutrition,
          SuggestionEffort.medium,
          42,
        ),
        _suggestion(
          'tg-zone2',
          'Build to 150 minutes of zone 2 a week',
          'Sustained aerobic work raises HDL and lowers triglycerides in '
              'parallel, which moves both sides of this ratio at once.',
          InsightDomain.training,
          SuggestionEffort.high,
          90,
        ),
      ],
    );
  },
);

final _thyroidReferral = Rule(
  id: 'subclinical-thyroid',
  name: 'Thyroid signal',
  evaluate: (context) {
    final tsh = context.biomarkers[BiomarkerCode.tsh];
    if (tsh == null) return null;
    const actionable = {
      BiomarkerFlag.high,
      BiomarkerFlag.criticalHigh,
      BiomarkerFlag.borderlineHigh,
      BiomarkerFlag.low,
      BiomarkerFlag.criticalLow,
    };
    if (!actionable.contains(tsh.flag)) return null;

    final isHigh = _isHighFlag(tsh.flag);
    final rhr = context.metrics[MetricKey.restingHeartRate]!;
    final energy = context.metrics[MetricKey.activeEnergy]!;

    // Hypothyroid physiology depresses heart rate and output; hyperthyroid
    // lifts it. Requiring the telemetry to agree with the direction of the TSH
    // is what keeps this from firing on every borderline result.
    final consistent = isHigh
        ? _isSuppressed(context, MetricKey.activeEnergy, -10) ||
              (rhr.deltaPct != null && rhr.deltaPct! < -3)
        : _isElevated(context, MetricKey.restingHeartRate, 5);
    if (!consistent) return null;

    final rhrFell = rhr.deltaPct != null && rhr.deltaPct! < 0;

    return RuleOutput(
      title: isHigh
          ? 'TSH is elevated and your output has dropped'
          : 'TSH is suppressed with an elevated heart rate',
      summary:
          'TSH of ${tsh.valueWithUnit} is ${isHigh ? 'above' : 'below'} the '
          'reference interval. '
          '${isHigh ? 'Active energy is down ${_pct(energy.deltaPct)} and resting heart rate has drifted ${rhrFell ? 'down' : 'up'} — both consistent with reduced thyroid drive.' : 'Resting heart rate is up ${_pct(rhr.deltaPct)}, consistent with increased thyroid drive.'} '
          'Thyroid status is a clinical diagnosis, not something this app can '
          'settle.',
      severity: InsightSeverity.urgent,
      domain: InsightDomain.medicalReferral,
      baseScore: 92,
      biomarkerCodes: [
        BiomarkerCode.tsh,
        if (context.biomarkers.containsKey(BiomarkerCode.freeT4))
          BiomarkerCode.freeT4,
        if (context.biomarkers.containsKey(BiomarkerCode.freeT3))
          BiomarkerCode.freeT3,
      ],
      telemetryNote:
          'Resting heart rate ${_pct(rhr.deltaPct)} '
          '${rhrFell ? 'below' : 'above'} baseline',
      citations: const [_Citations.thyroid],
      suggestions: [
        _suggestion(
          'thyroid-referral',
          'Take this panel to your GP',
          'Ask for free T4, free T3 and thyroid peroxidase antibodies. An '
              'isolated TSH cannot distinguish subclinical from overt thyroid '
              'disease.',
          InsightDomain.medicalReferral,
          SuggestionEffort.medium,
          14,
        ),
        _suggestion(
          'thyroid-no-self-supplement',
          'Do not start iodine on your own',
          'Iodine supplementation can worsen autoimmune thyroid disease. Wait '
              'for the antibody result before changing anything.',
          InsightDomain.medicalReferral,
          SuggestionEffort.low,
          14,
        ),
      ],
    );
  },
);

final _b12Fatigue = Rule(
  id: 'b12-insufficiency',
  name: 'B12 insufficiency',
  evaluate: (context) {
    final b12 = context.biomarkers[BiomarkerCode.vitaminB12];
    if (b12 == null || !_isLowFlag(b12.flag)) return null;

    final energyDown = _isSuppressed(context, MetricKey.activeEnergy, -12);
    final stepsDown = _isSuppressed(context, MetricKey.steps, -12);
    if (!energyDown && !stepsDown) return null;

    final energy = context.metrics[MetricKey.activeEnergy]!;
    final steps = context.metrics[MetricKey.steps]!;

    return RuleOutput(
      title: 'B12 is low while your daily output has fallen',
      summary:
          'Vitamin B12 of ${b12.valueWithUnit} is '
          '${b12.flag == BiomarkerFlag.borderlineLow ? 'in the grey zone where symptoms are common despite a "normal" flag' : 'below the reference range'}. '
          'Your activity has dropped over the same window — active energy '
          '${_pct(energy.deltaPct)} and steps ${_pct(steps.deltaPct)} below '
          'baseline. B12 is required for erythropoiesis and myelin '
          'maintenance, and insufficiency presents as exertional fatigue long '
          'before anaemia appears on a blood count.',
      severity: b12.flag == BiomarkerFlag.criticalLow
          ? InsightSeverity.action
          : InsightSeverity.watch,
      domain: InsightDomain.nutrition,
      baseScore: b12.flag == BiomarkerFlag.criticalLow ? 80 : 60,
      biomarkerCodes: [
        BiomarkerCode.vitaminB12,
        if (context.biomarkers.containsKey(BiomarkerCode.folate))
          BiomarkerCode.folate,
      ],
      telemetryNote:
          'Active energy ${_pct(energy.deltaPct)} below baseline',
      correlations: _significant(
        context.correlate(MetricKey.activeEnergy, MetricKey.hrv, 1),
      ),
      citations: const [_Citations.b12],
      suggestions: [
        _suggestion(
          'b12-mma',
          'Ask for methylmalonic acid and homocysteine',
          'Serum B12 is an unreliable marker in the 200–400 pg/mL range. MMA '
              'and homocysteine tell you whether the deficiency is functional.',
          InsightDomain.medicalReferral,
          SuggestionEffort.low,
          21,
        ),
        _suggestion(
          'b12-dietary',
          'Prioritise animal-source B12 or a supplement',
          'Eggs, dairy, fish and meat are the only reliable dietary sources. On '
              'a plant-based diet, a 250 µg/day cyanocobalamin supplement is '
              'the standard baseline.',
          InsightDomain.nutrition,
          SuggestionEffort.low,
          60,
        ),
      ],
    );
  },
);

final _magnesiumSleep = Rule(
  id: 'magnesium-sleep-fragmentation',
  name: 'Magnesium and sleep fragmentation',
  evaluate: (context) {
    final mg = context.biomarkers[BiomarkerCode.magnesium];
    if (mg == null || !_isLowFlag(mg.flag)) return null;

    final efficiency = context.metrics[MetricKey.sleepEfficiency]!;
    final recent = efficiency.recentMean;
    if (recent == null || recent >= 88) return null;

    return RuleOutput(
      title: 'Low magnesium alongside fragmented sleep',
      summary:
          'RBC magnesium of ${mg.valueWithUnit} is below the optimal band and '
          'your sleep efficiency is averaging ${recent.round()}% — meaning '
          'roughly ${((100 - recent) * 0.6).round()} minutes awake for every 8 '
          'hours in bed. Magnesium is a cofactor for GABAergic transmission and '
          'NREM sleep continuity.',
      severity: InsightSeverity.watch,
      domain: InsightDomain.sleep,
      baseScore: 56,
      biomarkerCodes: const [BiomarkerCode.magnesium],
      telemetryNote:
          'Sleep efficiency averaging ${recent.round()}% over the last 7 nights',
      correlations: _significant(
        context.correlate(MetricKey.sleepEfficiency, MetricKey.hrv, 0),
      ),
      citations: const [_Citations.magnesium],
      suggestions: [
        _suggestion(
          'mg-dietary',
          'Add a magnesium-dense food daily',
          'A 30 g serving of pumpkin seeds, almonds or dark chocolate, or a cup '
              'of cooked spinach, each supply 20–40% of the daily requirement.',
          InsightDomain.nutrition,
          SuggestionEffort.low,
          42,
        ),
        _suggestion(
          'mg-glycinate',
          'Consider 200–300 mg magnesium glycinate in the evening',
          'Glycinate and threonate are better tolerated than oxide, which is '
              'poorly absorbed and mostly acts as a laxative.',
          InsightDomain.sleep,
          SuggestionEffort.low,
          28,
        ),
      ],
    );
  },
);

final _hepaticLoad = Rule(
  id: 'hepatic-enzyme-load',
  name: 'Liver enzymes with low activity',
  evaluate: (context) {
    final alt = context.biomarkers[BiomarkerCode.alt];
    final ggt = context.biomarkers[BiomarkerCode.ggt];
    final marker = alt ?? ggt;
    if (marker == null || !_isHighFlag(marker.flag)) return null;

    final steps = context.metrics[MetricKey.steps]!;
    final recent = steps.recentMean;
    if (recent == null || recent >= 8000) return null;

    return RuleOutput(
      title: 'Liver enzymes are raised and activity is low',
      summary:
          '${marker.displayName} of ${marker.valueWithUnit} is above range. '
          'Combined with ${_thousands(recent)} steps a day, the most common '
          'explanation in an otherwise well adult is hepatic fat accumulation, '
          'which is highly responsive to activity and weight change — and needs '
          'a clinical work-up to exclude other causes.',
      severity: marker.flag == BiomarkerFlag.criticalHigh
          ? InsightSeverity.urgent
          : InsightSeverity.action,
      domain: InsightDomain.medicalReferral,
      baseScore: marker.flag == BiomarkerFlag.criticalHigh ? 90 : 74,
      biomarkerCodes: [
        if (alt != null) BiomarkerCode.alt,
        if (ggt != null) BiomarkerCode.ggt,
        if (context.biomarkers.containsKey(BiomarkerCode.ast))
          BiomarkerCode.ast,
      ],
      telemetryNote: '${_thousands(recent)} steps/day average',
      citations: const [_Citations.liver],
      suggestions: [
        _suggestion(
          'liver-workup',
          'Ask for a hepatic work-up',
          'Viral hepatitis serology, a liver ultrasound and a repeat LFT in 8 '
              'weeks are the standard first steps. Mention any supplements or '
              'regular paracetamol use.',
          InsightDomain.medicalReferral,
          SuggestionEffort.medium,
          21,
        ),
        _suggestion(
          'liver-alcohol',
          'Stop alcohol for 8 weeks and re-test',
          'A GGT that falls sharply over an alcohol-free period is '
              'diagnostically useful in itself.',
          InsightDomain.nutrition,
          SuggestionEffort.high,
          56,
        ),
        _suggestion(
          'liver-activity',
          'Build to 250 minutes of moderate activity a week',
          'Hepatic fat responds to exercise volume even without weight loss. '
              'This is the highest-yield lifestyle lever for raised ALT.',
          InsightDomain.training,
          SuggestionEffort.high,
          84,
        ),
      ],
    );
  },
);

// --- Telemetry-only rules (fire without any lab report) ---------------------

final _overreaching = Rule(
  id: 'training-load-hrv-decoupling',
  name: 'Training load and HRV decoupling',
  evaluate: (context) {
    final hrv = context.metrics[MetricKey.hrv]!;
    final energy = context.metrics[MetricKey.activeEnergy]!;
    if (hrv.baselineDays < minBaselineDays) return null;

    final loadUp = _isElevated(context, MetricKey.activeEnergy, 15);
    final hrvDown = _isSuppressed(context, MetricKey.hrv, -8);
    if (!loadUp || !hrvDown) return null;

    final lagged = context.correlate(MetricKey.activeEnergy, MetricKey.hrv, 1);
    final citable =
        lagged != null && lagged.strength != CorrelationStrength.none;

    return RuleOutput(
      title: 'Training load is up while HRV is falling',
      summary:
          'Active energy is ${_pct(energy.deltaPct)} above your baseline while '
          'HRV is ${_pct(hrv.deltaPct)} below it. A rising load with a falling '
          'HRV is the classic functional-overreaching signature: you are '
          'accumulating stress faster than you are absorbing it.'
          '${citable ? ' In your own data, yesterday\'s load explains a measurable share of today\'s HRV (r = ${lagged.r}, n = ${lagged.n}).' : ''}',
      severity: InsightSeverity.action,
      domain: InsightDomain.training,
      baseScore: 76,
      telemetryNote:
          'Load ${_pct(energy.deltaPct)} up, HRV ${_pct(hrv.deltaPct)} down '
          'over 7 days',
      correlations: _significant(lagged),
      citations: const [_Citations.physicalActivity],
      suggestions: [
        _suggestion(
          'overreach-deload',
          'Take a 5–7 day deload',
          'Cut weekly volume by 40% and remove all high-intensity work. HRV '
              'typically rebounds above baseline within a week if this is '
              'overreaching rather than illness.',
          InsightDomain.training,
          SuggestionEffort.medium,
          7,
        ),
        _suggestion(
          'overreach-protein-sleep',
          'Protect sleep and protein first',
          'Aim for 8 hours in bed and 1.6 g/kg of protein daily through the '
              'deload. Both are more limiting than any training variable at '
              'this point.',
          InsightDomain.recovery,
          SuggestionEffort.medium,
          14,
        ),
      ],
    );
  },
);

final _chronicSleepDebt = Rule(
  id: 'chronic-sleep-debt',
  name: 'Chronic short sleep',
  evaluate: (context) {
    final sleep = context.metrics[MetricKey.sleepDuration]!;
    final recent = sleep.recentMean;
    if (recent == null || sleep.coverage < 0.5) return null;
    if (recent >= 7) return null;

    final hrv = context.metrics[MetricKey.hrv]!;
    final link = context.correlate(MetricKey.sleepDuration, MetricKey.hrv, 0);
    final citable = link != null && link.strength != CorrelationStrength.none;
    final debtPerNight = 7.5 - recent;

    return RuleOutput(
      title:
          'You are running a ${formatDuration(debtPerNight * 7)} sleep debt '
          'each week',
      summary:
          'Averaging ${formatDuration(recent)} asleep against a 7.5-hour '
          'target. '
          '${citable ? 'In your own data, sleep duration and next-day HRV move together (r = ${link.r} across ${link.n} nights) — this is not a generic recommendation, it is measurable in your telemetry.' : 'Short sleep suppresses HRV and raises resting heart rate within 2–3 nights.'}'
          '${hrv.deltaPct != null && hrv.deltaPct! < 0 ? ' HRV is currently ${_pct(hrv.deltaPct)} below baseline.' : ''}',
      severity: recent < 6 ? InsightSeverity.action : InsightSeverity.watch,
      domain: InsightDomain.sleep,
      baseScore: recent < 6 ? 84 : 66,
      telemetryNote:
          '${formatDuration(recent)} average across the last 7 nights',
      correlations: _significant(link),
      citations: const [_Citations.sleep],
      suggestions: [
        _suggestion(
          'sleep-anchor-wake',
          'Fix your wake time seven days a week',
          'A constant wake time is the single strongest circadian anchor. Let '
              'bedtime drift earlier on its own rather than forcing it.',
          InsightDomain.sleep,
          SuggestionEffort.medium,
          21,
        ),
        _suggestion(
          'sleep-caffeine-cutoff',
          'Last caffeine 10 hours before bed',
          'Caffeine has a 5–6 hour half-life; an afternoon coffee still has a '
              'quarter of its dose circulating at midnight, which measurably '
              'suppresses deep sleep.',
          InsightDomain.sleep,
          SuggestionEffort.low,
          14,
        ),
        _suggestion(
          'sleep-window',
          'Move bedtime ${(debtPerNight * 60).round()} minutes earlier',
          'Shift in 15-minute increments every three nights rather than all at '
              'once — an abrupt shift usually just adds time awake in bed.',
          InsightDomain.sleep,
          SuggestionEffort.medium,
          28,
        ),
      ],
    );
  },
);

final _circadianDrift = Rule(
  id: 'circadian-bedtime-variance',
  name: 'Irregular sleep timing',
  evaluate: (context) {
    final bedtimes = <double>[];
    final withBedtime = context.series
        .map((s) => s.sleep?.bedtime)
        .whereType<String>()
        .toList();

    for (final iso in withBedtime.skip(math.max(0, withBedtime.length - 14))) {
      final parsed = DateTime.tryParse(iso);
      if (parsed == null) continue;
      final local = parsed.toLocal();
      final hours = local.hour + local.minute / 60;
      // Wrap post-midnight bedtimes onto a continuous evening axis, so 11pm and
      // 1am read as two hours apart rather than twenty-two.
      bedtimes.add(hours < 12 ? hours + 24 : hours);
    }

    if (bedtimes.length < 7) return null;

    final average = mean(bedtimes);
    final sd = stdDev(bedtimes);
    if (!sd.isFinite || sd < 1.0) return null;

    return RuleOutput(
      title: 'Your bedtime moves by more than an hour night to night',
      summary:
          'Across the last ${bedtimes.length} nights your sleep onset varied by '
          '±${(sd * 60).round()} minutes. Sleep *regularity* is a stronger '
          'predictor of cardiometabolic outcomes than sleep duration — a '
          'consistent 7 hours beats an erratic 8.',
      severity: sd >= 1.75 ? InsightSeverity.action : InsightSeverity.watch,
      domain: InsightDomain.sleep,
      baseScore: sd >= 1.75 ? 70 : 54,
      telemetryNote:
          'Bedtime standard deviation ±${(sd * 60).round()} minutes over '
          '${bedtimes.length} nights',
      correlations: _significant(
        context.correlate(MetricKey.sleepEfficiency, MetricKey.hrv, 0),
      ),
      citations: const [_Citations.sleep],
      suggestions: [
        _suggestion(
          'circadian-window',
          'Pick a 30-minute bedtime window and defend it',
          'Your average onset is around ${_formatClock(average)}. Aim for that '
              '±15 minutes, including weekends.',
          InsightDomain.sleep,
          SuggestionEffort.medium,
          28,
        ),
        _suggestion(
          'circadian-light',
          'Dim overheads two hours before bed',
          'Evening light exposure delays melatonin onset by up to 90 minutes, '
              'which is usually what is actually moving your bedtime.',
          InsightDomain.sleep,
          SuggestionEffort.low,
          21,
        ),
      ],
    );
  },
);

/// Formats an hours-past-midnight float (possibly wrapped past 24) as a clock
/// time.
String _formatClock(double hoursFloat) {
  final wrapped = hoursFloat >= 24 ? hoursFloat - 24 : hoursFloat;
  var hour = wrapped.floor();
  var minute = ((wrapped - hour) * 60).round();
  if (minute == 60) {
    minute = 0;
    hour += 1;
  }
  hour %= 24;

  final suffix = hour < 12 ? 'am' : 'pm';
  final display = hour % 12 == 0 ? 12 : hour % 12;
  return '$display:${minute.toString().padLeft(2, '0')}$suffix';
}

/// Order is irrelevant — the engine sorts by severity then computed score.
final List<Rule> rules = [
  _ironDeficiencyRecovery,
  _inflammationRecovery,
  _vitaminDSleep,
  _glycemicActivity,
  _insulinResistancePattern,
  _thyroidReferral,
  _b12Fatigue,
  _magnesiumSleep,
  _hepaticLoad,
  _overreaching,
  _chronicSleepDebt,
  _circadianDrift,
];
