import type { Correlation, InsightDomain, InsightSeverity, Suggestion } from '@/schemas/insights';
import type { BiomarkerCode } from '@/schemas/labs';
import { formatDuration } from '@/lib/date';
import type { EngineContext } from './context';
import { MIN_BASELINE_DAYS } from './context';

/**
 * Rule catalogue.
 *
 * Each rule is a pure predicate over telemetry + biomarkers. A rule fires only
 * when BOTH sides agree — a lab value alone is a number on a page, and a
 * telemetry drift alone is a bad night's sleep. The intersection is the only
 * place this product has something to say that Apple Health does not.
 *
 * Nothing here diagnoses. Severity `urgent` never means "you have X"; it means
 * "take this printout to a clinician".
 *
 * Citations are curated links to standing clinical references (NIH ODS,
 * professional societies). They are fixed at authoring time and never
 * generated at runtime.
 */

export interface RuleOutput {
  title: string;
  summary: string;
  severity: InsightSeverity;
  domain: InsightDomain;
  /** 0–100 before the engine applies its recency and confidence multipliers. */
  baseScore: number;
  biomarkerCodes: BiomarkerCode[];
  telemetryNote: string | null;
  correlations: Correlation[];
  citations: Array<{ label: string; url: string }>;
  suggestions: Suggestion[];
}

export interface Rule {
  id: string;
  /** Short label used in the settings screen where rules can be muted. */
  name: string;
  evaluate(context: EngineContext): RuleOutput | null;
}

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

function suggestion(
  id: string,
  title: string,
  detail: string,
  domain: InsightDomain,
  effort: Suggestion['effort'],
  horizonDays: number,
): Suggestion {
  return { id, title, detail, domain, effort, horizonDays };
}

/** A metric is "suppressed" when the recent mean sits meaningfully below baseline. */
function isSuppressed(context: EngineContext, key: Parameters<EngineContext['correlate']>[0], pct = -8): boolean {
  const stats = context.metrics[key];
  if (stats.baselineDays < MIN_BASELINE_DAYS || stats.deltaPct == null) return false;
  return stats.deltaPct <= pct;
}

function isElevated(context: EngineContext, key: Parameters<EngineContext['correlate']>[0], pct = 5): boolean {
  const stats = context.metrics[key];
  if (stats.baselineDays < MIN_BASELINE_DAYS || stats.deltaPct == null) return false;
  return stats.deltaPct >= pct;
}

function pct(value: number | null): string {
  if (value == null) return '—';
  const rounded = Math.round(Math.abs(value));
  return `${rounded}%`;
}

function significant(correlation: Correlation | null): Correlation[] {
  return correlation && correlation.strength !== 'none' ? [correlation] : [];
}

const CITATIONS = {
  iron: {
    label: 'NIH Office of Dietary Supplements — Iron',
    url: 'https://ods.od.nih.gov/factsheets/Iron-HealthProfessional/',
  },
  vitaminD: {
    label: 'NIH Office of Dietary Supplements — Vitamin D',
    url: 'https://ods.od.nih.gov/factsheets/VitaminD-HealthProfessional/',
  },
  b12: {
    label: 'NIH Office of Dietary Supplements — Vitamin B12',
    url: 'https://ods.od.nih.gov/factsheets/VitaminB12-HealthProfessional/',
  },
  magnesium: {
    label: 'NIH Office of Dietary Supplements — Magnesium',
    url: 'https://ods.od.nih.gov/factsheets/Magnesium-HealthProfessional/',
  },
  cholesterol: {
    label: 'American Heart Association — Cholesterol',
    url: 'https://www.heart.org/en/health-topics/cholesterol',
  },
  prediabetes: {
    label: 'CDC — Prediabetes',
    url: 'https://www.cdc.gov/diabetes/prevention-type-2/prediabetes-risk-factors.html',
  },
  thyroid: {
    label: 'American Thyroid Association — Hypothyroidism',
    url: 'https://www.thyroid.org/hypothyroidism/',
  },
  sleep: {
    label: 'CDC — About Sleep',
    url: 'https://www.cdc.gov/sleep/about/index.html',
  },
  liver: {
    label: 'American Liver Foundation — NAFLD',
    url: 'https://liverfoundation.org/liver-diseases/fatty-liver-disease/nonalcoholic-fatty-liver-disease-nafld/',
  },
  physicalActivity: {
    label: 'WHO — Physical Activity Guidelines',
    url: 'https://www.who.int/news-room/fact-sheets/detail/physical-activity',
  },
} as const;

// ---------------------------------------------------------------------------
// Rules
// ---------------------------------------------------------------------------

const ironDeficiencyRecovery: Rule = {
  id: 'iron-deficiency-recovery-drag',
  name: 'Low iron stores suppressing recovery',
  evaluate(context) {
    const ferritin = context.biomarkers.get('ferritin');
    if (!ferritin) return null;
    if (!['low', 'critical-low', 'borderline-low'].includes(ferritin.flag)) return null;

    const hrvDown = isSuppressed(context, 'hrv', -6);
    const rhrUp = isElevated(context, 'restingHeartRate', 3);
    if (!hrvDown && !rhrUp) return null;

    const hrv = context.metrics.hrv;
    const rhr = context.metrics.restingHeartRate;
    const isCritical = ferritin.flag === 'critical-low';
    const isFrank = ferritin.flag !== 'borderline-low';

    const notes: string[] = [];
    if (hrvDown) notes.push(`HRV is down ${pct(hrv.deltaPct)} against your 28-day baseline`);
    if (rhrUp) notes.push(`resting heart rate is up ${pct(rhr.deltaPct)}`);

    return {
      title: isFrank ? 'Low iron stores are tracking with poor recovery' : 'Iron stores are on the low side of normal',
      summary: `Ferritin of ${ferritin.value} ${ferritin.unit} sits ${isFrank ? 'below' : 'at the bottom of'} the reference range, and over the same period ${notes.join(' and ')}. Reduced iron availability limits oxygen transport and mitochondrial output, which typically shows up first as depressed HRV and a drifting resting heart rate — well before you notice it as fatigue.`,
      severity: isCritical ? 'urgent' : isFrank ? 'action' : 'watch',
      domain: 'nutrition',
      baseScore: isCritical ? 96 : isFrank ? 88 : 68,
      biomarkerCodes: ['ferritin', ...(context.biomarkers.has('hemoglobin') ? (['hemoglobin'] as const) : [])],
      telemetryNote: notes.join('; '),
      correlations: significant(context.correlate('activeEnergy', 'hrv', 1)),
      citations: [CITATIONS.iron],
      suggestions: [
        suggestion(
          'iron-dietary',
          'Pair iron sources with vitamin C',
          'Add 85–110 g of red meat, liver, lentils or fortified cereal to two meals a day, each alongside a vitamin-C source (bell pepper, citrus, strawberries). Ascorbate can raise non-haem iron absorption several-fold.',
          'nutrition',
          'low',
          60,
        ),
        suggestion(
          'iron-inhibitors',
          'Move coffee and tea away from meals',
          'Keep tea, coffee and calcium supplements at least 60 minutes clear of iron-containing meals — polyphenols and calcium are the two strongest dietary inhibitors of iron uptake.',
          'nutrition',
          'low',
          45,
        ),
        suggestion(
          'iron-clinician',
          isCritical ? 'Book a clinician review this week' : 'Ask about a full iron panel',
          isCritical
            ? 'A ferritin this low warrants a clinical work-up to establish the cause before supplementing. Bring this report.'
            : 'Request transferrin saturation, TIBC and hs-CRP together — ferritin is an acute-phase reactant and can read falsely normal during inflammation.',
          'medical-referral',
          isCritical ? 'medium' : 'low',
          14,
        ),
        suggestion(
          'iron-load-management',
          'Cap intensity until HRV recovers',
          'Hold sessions at conversational intensity while HRV is below baseline. Training hard into low iron availability deepens the deficit rather than adapting to it.',
          'training',
          'medium',
          21,
        ),
      ],
    };
  },
};

const inflammationRecovery: Rule = {
  id: 'inflammation-recovery-suppression',
  name: 'Systemic inflammation blunting recovery',
  evaluate(context) {
    const crp = context.biomarkers.get('hsCrp');
    if (!crp) return null;
    if (!['high', 'critical-high', 'borderline-high'].includes(crp.flag)) return null;

    const hrvDown = isSuppressed(context, 'hrv', -5);
    const sleepFragmented = isSuppressed(context, 'sleepEfficiency', -3);
    if (!hrvDown && !sleepFragmented) return null;

    const isHigh = crp.flag !== 'borderline-high';
    const hrv = context.metrics.hrv;

    return {
      title: isHigh ? 'Inflammation is showing up in your recovery data' : 'Low-grade inflammation worth watching',
      summary: `hs-CRP of ${crp.value} ${crp.unit} indicates ${isHigh ? 'meaningful' : 'low-grade'} systemic inflammation. Inflammatory cytokines shift autonomic balance toward sympathetic dominance, which is exactly the pattern in your recent telemetry${hrvDown ? ` — HRV down ${pct(hrv.deltaPct)}` : ''}${sleepFragmented ? ` and sleep efficiency down ${pct(context.metrics.sleepEfficiency.deltaPct)}` : ''}.`,
      severity: crp.flag === 'critical-high' ? 'urgent' : isHigh ? 'action' : 'watch',
      domain: 'recovery',
      baseScore: crp.flag === 'critical-high' ? 94 : isHigh ? 82 : 62,
      biomarkerCodes: ['hsCrp'],
      telemetryNote: hrvDown
        ? `HRV ${pct(hrv.deltaPct)} below baseline over the last 7 days`
        : 'Sleep efficiency below baseline over the last 7 days',
      correlations: significant(context.correlate('sleepDuration', 'hrv', 0)),
      citations: [CITATIONS.physicalActivity],
      suggestions: [
        suggestion(
          'crp-omega3',
          'Add oily fish twice a week',
          'Two 120 g servings of salmon, mackerel or sardines per week supplies roughly 2 g/day of EPA+DHA — the dose range associated with measurable CRP reduction.',
          'nutrition',
          'low',
          56,
        ),
        suggestion(
          'crp-recheck',
          'Re-test hs-CRP in 6–8 weeks',
          'A single elevated hs-CRP can reflect a transient infection. Repeat when you are symptom-free for at least two weeks; a persistently high value needs a clinical explanation.',
          'medical-referral',
          'low',
          56,
        ),
        suggestion(
          'crp-zone2',
          'Shift volume toward zone 2',
          'Replace one hard session a week with 45–60 minutes at conversational pace. Moderate aerobic volume lowers CRP; repeated high-intensity work on an inflamed baseline raises it.',
          'training',
          'medium',
          42,
        ),
      ],
    };
  },
};

const vitaminDSleep: Rule = {
  id: 'vitamin-d-sleep-quality',
  name: 'Vitamin D insufficiency and sleep',
  evaluate(context) {
    const vitD = context.biomarkers.get('vitaminD');
    if (!vitD) return null;
    if (!['low', 'critical-low', 'borderline-low'].includes(vitD.flag)) return null;

    const sleep = context.metrics.sleepDuration;
    const efficiency = context.metrics.sleepEfficiency;
    const poorSleep =
      (sleep.recentMean != null && sleep.recentMean < 7) ||
      (efficiency.recentMean != null && efficiency.recentMean < 85);
    if (!poorSleep) return null;

    const isDeficient = vitD.flag !== 'borderline-low';

    return {
      title: isDeficient ? 'Vitamin D deficiency alongside short sleep' : 'Vitamin D is below the optimal band',
      summary: `Your 25-OH vitamin D is ${vitD.value} ${vitD.unit}${isDeficient ? ', which meets the threshold for deficiency' : ', inside the lab range but below the 40–60 ng/mL band'}. You are averaging ${sleep.recentMean != null ? formatDuration(sleep.recentMean) : '—'} of sleep at ${efficiency.recentMean != null ? `${Math.round(efficiency.recentMean)}%` : '—'} efficiency. Vitamin D receptors are expressed in the brainstem regions that regulate sleep, and low status is consistently associated with shorter, more fragmented sleep.`,
      severity: isDeficient ? 'action' : 'watch',
      domain: 'sleep',
      baseScore: isDeficient ? 78 : 58,
      biomarkerCodes: ['vitaminD'],
      telemetryNote: `Averaging ${sleep.recentMean != null ? formatDuration(sleep.recentMean) : 'unknown'} asleep over the last 7 nights`,
      correlations: significant(context.correlate('sleepDuration', 'hrv', 0)),
      citations: [CITATIONS.vitaminD, CITATIONS.sleep],
      suggestions: [
        suggestion(
          'vitd-morning-light',
          'Get 15 minutes of outdoor light before 10am',
          'Morning sunlight both supports cutaneous synthesis and anchors your circadian phase — the second effect is the one that shows up in sleep efficiency within a fortnight.',
          'sleep',
          'low',
          14,
        ),
        suggestion(
          'vitd-supplement',
          'Discuss a repletion dose with your clinician',
          'Typical adult repletion is 2000–4000 IU/day of D3 taken with a fat-containing meal, followed by a re-test at 12 weeks. Dosing above this should be supervised.',
          'nutrition',
          'low',
          84,
        ),
        suggestion(
          'vitd-k2-magnesium',
          'Take D3 with a magnesium-rich meal',
          'Magnesium is a cofactor for the hydroxylation steps that activate vitamin D. Leafy greens, pumpkin seeds or almonds at the same meal is sufficient.',
          'nutrition',
          'low',
          84,
        ),
      ],
    };
  },
};

const glycemicActivity: Rule = {
  id: 'glycemic-drift-low-activity',
  name: 'Glycaemic drift with low movement',
  evaluate(context) {
    const hba1c = context.biomarkers.get('hba1c');
    const glucose = context.biomarkers.get('fastingGlucose');
    const marker = hba1c ?? glucose;
    if (!marker) return null;
    if (!['high', 'critical-high', 'borderline-high'].includes(marker.flag)) return null;

    const steps = context.metrics.steps;
    const energy = context.metrics.activeEnergy;
    const lowMovement =
      (steps.recentMean != null && steps.recentMean < 7500) ||
      (energy.recentMean != null && energy.recentMean < 350);
    if (!lowMovement) return null;

    const isPrediabetic = marker.flag !== 'borderline-high';
    const codes: BiomarkerCode[] = [];
    if (hba1c) codes.push('hba1c');
    if (glucose) codes.push('fastingGlucose');
    if (context.biomarkers.has('triglycerides')) codes.push('triglycerides');

    return {
      title: isPrediabetic
        ? 'Glycaemic markers are elevated and movement is low'
        : 'Blood sugar is creeping toward the upper range',
      summary: `${marker.displayName} of ${marker.value} ${marker.unit} places you ${isPrediabetic ? 'in the pre-diabetic band' : 'above the optimal band'}. Over the same window you averaged ${steps.recentMean != null ? Math.round(steps.recentMean).toLocaleString() : '—'} steps and ${energy.recentMean != null ? Math.round(energy.recentMean) : '—'} kcal of active energy per day. Skeletal muscle contraction clears glucose independently of insulin, so movement volume is the fastest lever you have on this number.`,
      severity: isPrediabetic ? 'action' : 'watch',
      domain: 'nutrition',
      baseScore: isPrediabetic ? 86 : 64,
      biomarkerCodes: codes,
      telemetryNote: `${steps.recentMean != null ? Math.round(steps.recentMean).toLocaleString() : '—'} steps/day average over the last 7 days`,
      correlations: significant(context.correlate('steps', 'restingHeartRate', 1)),
      citations: [CITATIONS.prediabetes, CITATIONS.physicalActivity],
      suggestions: [
        suggestion(
          'glycemic-post-meal-walk',
          'Walk 10–15 minutes after your largest meal',
          'A short walk inside 30 minutes of eating blunts the post-prandial glucose peak more effectively than the same walk at any other time of day.',
          'nutrition',
          'low',
          30,
        ),
        suggestion(
          'glycemic-step-target',
          `Raise your daily floor to 8,000 steps`,
          `You are averaging ${steps.recentMean != null ? Math.round(steps.recentMean).toLocaleString() : 'fewer'} steps. Adding roughly ${steps.recentMean != null ? Math.max(500, Math.round((8000 - steps.recentMean) / 100) * 100).toLocaleString() : '1,500'} per day gets you to the band where insulin sensitivity improves measurably.`,
          'training',
          'medium',
          90,
        ),
        suggestion(
          'glycemic-resistance',
          'Add two resistance sessions a week',
          'Two full-body sessions per week build the muscle mass that acts as your glucose sink. Effects on HbA1c appear at the 10–12 week re-test, not sooner.',
          'training',
          'medium',
          84,
        ),
        suggestion(
          'glycemic-fibre',
          'Front-load 30 g of fibre a day',
          'Legumes, oats and intact whole grains slow gastric emptying and flatten the glucose curve. Increase gradually over two weeks to stay comfortable.',
          'nutrition',
          'medium',
          60,
        ),
      ],
    };
  },
};

const insulinResistancePattern: Rule = {
  id: 'triglyceride-hdl-ratio',
  name: 'Triglyceride/HDL ratio',
  evaluate(context) {
    const tg = context.biomarkers.get('triglycerides');
    const hdl = context.biomarkers.get('hdl');
    if (!tg || !hdl || hdl.value <= 0) return null;

    const ratio = tg.value / hdl.value;
    if (ratio < 2.5) return null;

    const energy = context.metrics.activeEnergy;

    return {
      title: 'Your triglyceride-to-HDL ratio suggests insulin resistance',
      summary: `Triglycerides ${tg.value} ${tg.unit} against HDL ${hdl.value} ${hdl.unit} gives a ratio of ${ratio.toFixed(1)}. Above 3.0 this ratio is one of the better cheap surrogates for insulin resistance — often flagging it years before fasting glucose moves. ${energy.recentMean != null ? `Your active energy is averaging ${Math.round(energy.recentMean)} kcal/day.` : ''}`,
      severity: ratio >= 3.5 ? 'action' : 'watch',
      domain: 'nutrition',
      baseScore: ratio >= 3.5 ? 80 : 62,
      biomarkerCodes: ['triglycerides', 'hdl', ...(context.biomarkers.has('hba1c') ? (['hba1c'] as const) : [])],
      telemetryNote: null,
      correlations: significant(context.correlate('activeEnergy', 'restingHeartRate', 2)),
      citations: [CITATIONS.cholesterol],
      suggestions: [
        suggestion(
          'tg-refined-carbs',
          'Cut liquid sugar and refined starch first',
          'Triglycerides respond faster to removing sugary drinks, juice and refined flour than to any other single dietary change — often within 4–6 weeks.',
          'nutrition',
          'medium',
          42,
        ),
        suggestion(
          'tg-alcohol',
          'Hold alcohol to a maximum of 3 units a week',
          'Ethanol is directly lipogenic in the liver. If your triglycerides are the outlier on this panel, alcohol is the first thing to test by removing it.',
          'nutrition',
          'medium',
          42,
        ),
        suggestion(
          'tg-zone2',
          'Build to 150 minutes of zone 2 a week',
          'Sustained aerobic work raises HDL and lowers triglycerides in parallel, which moves both sides of this ratio at once.',
          'training',
          'high',
          90,
        ),
      ],
    };
  },
};

const thyroidReferral: Rule = {
  id: 'subclinical-thyroid',
  name: 'Thyroid signal',
  evaluate(context) {
    const tsh = context.biomarkers.get('tsh');
    if (!tsh) return null;
    if (!['high', 'critical-high', 'borderline-high', 'low', 'critical-low'].includes(tsh.flag)) {
      return null;
    }

    const isHigh = tsh.flag.includes('high');
    const rhr = context.metrics.restingHeartRate;
    const energy = context.metrics.activeEnergy;

    // Hypothyroid physiology depresses heart rate and output; hyperthyroid lifts it.
    const consistent = isHigh
      ? isSuppressed(context, 'activeEnergy', -10) || (rhr.deltaPct != null && rhr.deltaPct < -3)
      : isElevated(context, 'restingHeartRate', 5);
    if (!consistent) return null;

    return {
      title: isHigh ? 'TSH is elevated and your output has dropped' : 'TSH is suppressed with an elevated heart rate',
      summary: `TSH of ${tsh.value} ${tsh.unit} is ${isHigh ? 'above' : 'below'} the reference interval. ${isHigh ? `Active energy is down ${pct(energy.deltaPct)} and resting heart rate has drifted ${rhr.deltaPct != null && rhr.deltaPct < 0 ? 'down' : 'up'} — both consistent with reduced thyroid drive.` : `Resting heart rate is up ${pct(rhr.deltaPct)}, consistent with increased thyroid drive.`} Thyroid status is a clinical diagnosis, not something this app can settle.`,
      severity: 'urgent',
      domain: 'medical-referral',
      baseScore: 92,
      biomarkerCodes: [
        'tsh',
        ...(context.biomarkers.has('freeT4') ? (['freeT4'] as const) : []),
        ...(context.biomarkers.has('freeT3') ? (['freeT3'] as const) : []),
      ],
      telemetryNote: `Resting heart rate ${pct(rhr.deltaPct)} ${rhr.deltaPct != null && rhr.deltaPct < 0 ? 'below' : 'above'} baseline`,
      correlations: [],
      citations: [CITATIONS.thyroid],
      suggestions: [
        suggestion(
          'thyroid-referral',
          'Take this panel to your GP',
          'Ask for free T4, free T3 and thyroid peroxidase antibodies. An isolated TSH cannot distinguish subclinical from overt thyroid disease.',
          'medical-referral',
          'medium',
          14,
        ),
        suggestion(
          'thyroid-no-self-supplement',
          'Do not start iodine on your own',
          'Iodine supplementation can worsen autoimmune thyroid disease. Wait for the antibody result before changing anything.',
          'medical-referral',
          'low',
          14,
        ),
      ],
    };
  },
};

const b12Fatigue: Rule = {
  id: 'b12-insufficiency',
  name: 'B12 insufficiency',
  evaluate(context) {
    const b12 = context.biomarkers.get('vitaminB12');
    if (!b12) return null;
    if (!['low', 'critical-low', 'borderline-low'].includes(b12.flag)) return null;

    const energyDown = isSuppressed(context, 'activeEnergy', -12);
    const stepsDown = isSuppressed(context, 'steps', -12);
    if (!energyDown && !stepsDown) return null;

    return {
      title: 'B12 is low while your daily output has fallen',
      summary: `Vitamin B12 of ${b12.value} ${b12.unit} is ${b12.flag === 'borderline-low' ? 'in the grey zone where symptoms are common despite a "normal" flag' : 'below the reference range'}. Your activity has dropped over the same window — active energy ${pct(context.metrics.activeEnergy.deltaPct)} and steps ${pct(context.metrics.steps.deltaPct)} below baseline. B12 is required for erythropoiesis and myelin maintenance, and insufficiency presents as exertional fatigue long before anaemia appears on a blood count.`,
      severity: b12.flag === 'critical-low' ? 'action' : 'watch',
      domain: 'nutrition',
      baseScore: b12.flag === 'critical-low' ? 80 : 60,
      biomarkerCodes: ['vitaminB12', ...(context.biomarkers.has('folate') ? (['folate'] as const) : [])],
      telemetryNote: `Active energy ${pct(context.metrics.activeEnergy.deltaPct)} below baseline`,
      correlations: significant(context.correlate('activeEnergy', 'hrv', 1)),
      citations: [CITATIONS.b12],
      suggestions: [
        suggestion(
          'b12-mma',
          'Ask for methylmalonic acid and homocysteine',
          'Serum B12 is an unreliable marker in the 200–400 pg/mL range. MMA and homocysteine tell you whether the deficiency is functional.',
          'medical-referral',
          'low',
          21,
        ),
        suggestion(
          'b12-dietary',
          'Prioritise animal-source B12 or a supplement',
          'Eggs, dairy, fish and meat are the only reliable dietary sources. On a plant-based diet, a 250 µg/day cyanocobalamin supplement is the standard baseline.',
          'nutrition',
          'low',
          60,
        ),
      ],
    };
  },
};

const magnesiumSleep: Rule = {
  id: 'magnesium-sleep-fragmentation',
  name: 'Magnesium and sleep fragmentation',
  evaluate(context) {
    const mg = context.biomarkers.get('magnesium');
    if (!mg) return null;
    if (!['low', 'critical-low', 'borderline-low'].includes(mg.flag)) return null;

    const efficiency = context.metrics.sleepEfficiency;
    if (efficiency.recentMean == null || efficiency.recentMean >= 88) return null;

    return {
      title: 'Low magnesium alongside fragmented sleep',
      summary: `RBC magnesium of ${mg.value} ${mg.unit} is below the optimal band and your sleep efficiency is averaging ${Math.round(efficiency.recentMean)}% — meaning roughly ${Math.round((100 - efficiency.recentMean) * 0.6)} minutes awake for every 8 hours in bed. Magnesium is a cofactor for GABAergic transmission and NREM sleep continuity.`,
      severity: 'watch',
      domain: 'sleep',
      baseScore: 56,
      biomarkerCodes: ['magnesium'],
      telemetryNote: `Sleep efficiency averaging ${Math.round(efficiency.recentMean)}% over the last 7 nights`,
      correlations: significant(context.correlate('sleepEfficiency', 'hrv', 0)),
      citations: [CITATIONS.magnesium],
      suggestions: [
        suggestion(
          'mg-dietary',
          'Add a magnesium-dense food daily',
          'A 30 g serving of pumpkin seeds, almonds or dark chocolate, or a cup of cooked spinach, each supply 20–40% of the daily requirement.',
          'nutrition',
          'low',
          42,
        ),
        suggestion(
          'mg-glycinate',
          'Consider 200–300 mg magnesium glycinate in the evening',
          'Glycinate and threonate are better tolerated than oxide, which is poorly absorbed and mostly acts as a laxative.',
          'sleep',
          'low',
          28,
        ),
      ],
    };
  },
};

const hepaticLoad: Rule = {
  id: 'hepatic-enzyme-load',
  name: 'Liver enzymes with low activity',
  evaluate(context) {
    const alt = context.biomarkers.get('alt');
    const ggt = context.biomarkers.get('ggt');
    const marker = alt ?? ggt;
    if (!marker) return null;
    if (!['high', 'critical-high', 'borderline-high'].includes(marker.flag)) return null;

    const steps = context.metrics.steps;
    if (steps.recentMean == null || steps.recentMean >= 8000) return null;

    const codes: BiomarkerCode[] = [];
    if (alt) codes.push('alt');
    if (ggt) codes.push('ggt');
    if (context.biomarkers.has('ast')) codes.push('ast');

    return {
      title: 'Liver enzymes are raised and activity is low',
      summary: `${marker.displayName} of ${marker.value} ${marker.unit} is above range. Combined with ${Math.round(steps.recentMean).toLocaleString()} steps a day, the most common explanation in an otherwise well adult is hepatic fat accumulation, which is highly responsive to activity and weight change — and needs a clinical work-up to exclude other causes.`,
      severity: marker.flag === 'critical-high' ? 'urgent' : 'action',
      domain: 'medical-referral',
      baseScore: marker.flag === 'critical-high' ? 90 : 74,
      biomarkerCodes: codes,
      telemetryNote: `${Math.round(steps.recentMean).toLocaleString()} steps/day average`,
      correlations: [],
      citations: [CITATIONS.liver],
      suggestions: [
        suggestion(
          'liver-workup',
          'Ask for a hepatic work-up',
          'Viral hepatitis serology, a liver ultrasound and a repeat LFT in 8 weeks are the standard first steps. Mention any supplements or regular paracetamol use.',
          'medical-referral',
          'medium',
          21,
        ),
        suggestion(
          'liver-alcohol',
          'Stop alcohol for 8 weeks and re-test',
          'A GGT that falls sharply over an alcohol-free period is diagnostically useful in itself.',
          'nutrition',
          'high',
          56,
        ),
        suggestion(
          'liver-activity',
          'Build to 250 minutes of moderate activity a week',
          'Hepatic fat responds to exercise volume even without weight loss. This is the highest-yield lifestyle lever for raised ALT.',
          'training',
          'high',
          84,
        ),
      ],
    };
  },
};

// --- Telemetry-only rules (fire without any lab report) ---------------------

const overreaching: Rule = {
  id: 'training-load-hrv-decoupling',
  name: 'Training load and HRV decoupling',
  evaluate(context) {
    const hrv = context.metrics.hrv;
    const energy = context.metrics.activeEnergy;
    if (hrv.baselineDays < MIN_BASELINE_DAYS) return null;

    const loadUp = isElevated(context, 'activeEnergy', 15);
    const hrvDown = isSuppressed(context, 'hrv', -8);
    if (!loadUp || !hrvDown) return null;

    const lagged = context.correlate('activeEnergy', 'hrv', 1);

    return {
      title: 'Training load is up while HRV is falling',
      summary: `Active energy is ${pct(energy.deltaPct)} above your baseline while HRV is ${pct(hrv.deltaPct)} below it. A rising load with a falling HRV is the classic functional-overreaching signature: you are accumulating stress faster than you are absorbing it.${lagged && lagged.strength !== 'none' ? ` In your own data, yesterday's load explains a measurable share of today's HRV (r = ${lagged.r}, n = ${lagged.n}).` : ''}`,
      severity: 'action',
      domain: 'training',
      baseScore: 76,
      biomarkerCodes: [],
      telemetryNote: `Load ${pct(energy.deltaPct)} up, HRV ${pct(hrv.deltaPct)} down over 7 days`,
      correlations: significant(lagged),
      citations: [CITATIONS.physicalActivity],
      suggestions: [
        suggestion(
          'overreach-deload',
          'Take a 5–7 day deload',
          'Cut weekly volume by 40% and remove all high-intensity work. HRV typically rebounds above baseline within a week if this is overreaching rather than illness.',
          'training',
          'medium',
          7,
        ),
        suggestion(
          'overreach-protein-sleep',
          'Protect sleep and protein first',
          'Aim for 8 hours in bed and 1.6 g/kg of protein daily through the deload. Both are more limiting than any training variable at this point.',
          'recovery',
          'medium',
          14,
        ),
      ],
    };
  },
};

const chronicSleepDebt: Rule = {
  id: 'chronic-sleep-debt',
  name: 'Chronic short sleep',
  evaluate(context) {
    const sleep = context.metrics.sleepDuration;
    if (sleep.recentMean == null || sleep.coverage < 0.5) return null;
    if (sleep.recentMean >= 7) return null;

    const hrv = context.metrics.hrv;
    const link = context.correlate('sleepDuration', 'hrv', 0);
    const debtPerNight = 7.5 - sleep.recentMean;

    return {
      title: `You are running a ${formatDuration(debtPerNight * 7)} sleep debt each week`,
      summary: `Averaging ${formatDuration(sleep.recentMean)} asleep against a 7.5-hour target. ${link && link.strength !== 'none' ? `In your own data, sleep duration and next-day HRV move together (r = ${link.r} across ${link.n} nights) — this is not a generic recommendation, it is measurable in your telemetry.` : `Short sleep suppresses HRV and raises resting heart rate within 2–3 nights.`}${hrv.deltaPct != null && hrv.deltaPct < 0 ? ` HRV is currently ${pct(hrv.deltaPct)} below baseline.` : ''}`,
      severity: sleep.recentMean < 6 ? 'action' : 'watch',
      domain: 'sleep',
      baseScore: sleep.recentMean < 6 ? 84 : 66,
      biomarkerCodes: [],
      telemetryNote: `${formatDuration(sleep.recentMean)} average across the last 7 nights`,
      correlations: significant(link),
      citations: [CITATIONS.sleep],
      suggestions: [
        suggestion(
          'sleep-anchor-wake',
          'Fix your wake time seven days a week',
          'A constant wake time is the single strongest circadian anchor. Let bedtime drift earlier on its own rather than forcing it.',
          'sleep',
          'medium',
          21,
        ),
        suggestion(
          'sleep-caffeine-cutoff',
          'Last caffeine 10 hours before bed',
          'Caffeine has a 5–6 hour half-life; an afternoon coffee still has a quarter of its dose circulating at midnight, which measurably suppresses deep sleep.',
          'sleep',
          'low',
          14,
        ),
        suggestion(
          'sleep-window',
          `Move bedtime ${Math.round(debtPerNight * 60)} minutes earlier`,
          'Shift in 15-minute increments every three nights rather than all at once — an abrupt shift usually just adds time awake in bed.',
          'sleep',
          'medium',
          28,
        ),
      ],
    };
  },
};

const circadianDrift: Rule = {
  id: 'circadian-bedtime-variance',
  name: 'Irregular sleep timing',
  evaluate(context) {
    const bedtimes = context.series
      .map((s) => s.sleep?.bedtime)
      .filter((b): b is string => b != null)
      .slice(-14)
      .map((iso) => {
        const date = new Date(iso);
        const hours = date.getHours() + date.getMinutes() / 60;
        // Wrap post-midnight bedtimes onto a continuous evening axis.
        return hours < 12 ? hours + 24 : hours;
      });

    if (bedtimes.length < 7) return null;

    const avg = bedtimes.reduce((sum, v) => sum + v, 0) / bedtimes.length;
    const variance = bedtimes.reduce((sum, v) => sum + (v - avg) ** 2, 0) / (bedtimes.length - 1);
    const sd = Math.sqrt(variance);
    if (sd < 1.0) return null;

    return {
      title: 'Your bedtime moves by more than an hour night to night',
      summary: `Across the last ${bedtimes.length} nights your sleep onset varied by ±${Math.round(sd * 60)} minutes. Sleep *regularity* is a stronger predictor of cardiometabolic outcomes than sleep duration — a consistent 7 hours beats an erratic 8.`,
      severity: sd >= 1.75 ? 'action' : 'watch',
      domain: 'sleep',
      baseScore: sd >= 1.75 ? 70 : 54,
      biomarkerCodes: [],
      telemetryNote: `Bedtime standard deviation ±${Math.round(sd * 60)} minutes over ${bedtimes.length} nights`,
      correlations: significant(context.correlate('sleepEfficiency', 'hrv', 0)),
      citations: [CITATIONS.sleep],
      suggestions: [
        suggestion(
          'circadian-window',
          'Pick a 30-minute bedtime window and defend it',
          `Your average onset is around ${formatClock(avg)}. Aim for that ±15 minutes, including weekends.`,
          'sleep',
          'medium',
          28,
        ),
        suggestion(
          'circadian-light',
          'Dim overheads two hours before bed',
          'Evening light exposure delays melatonin onset by up to 90 minutes, which is usually what is actually moving your bedtime.',
          'sleep',
          'low',
          21,
        ),
      ],
    };
  },
};

function formatClock(hoursFloat: number): string {
  const wrapped = hoursFloat >= 24 ? hoursFloat - 24 : hoursFloat;
  const h = Math.floor(wrapped);
  const m = Math.round((wrapped - h) * 60);
  const date = new Date();
  date.setHours(h, m, 0, 0);
  return date.toLocaleTimeString(undefined, { hour: 'numeric', minute: '2-digit' });
}

/** Order is irrelevant — the engine sorts by computed score. */
export const RULES: readonly Rule[] = [
  ironDeficiencyRecovery,
  inflammationRecovery,
  vitaminDSleep,
  glycemicActivity,
  insulinResistancePattern,
  thyroidReferral,
  b12Fatigue,
  magnesiumSleep,
  hepaticLoad,
  overreaching,
  chronicSleepDebt,
  circadianDrift,
];
