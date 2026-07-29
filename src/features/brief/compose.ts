import type { DailySnapshot, IsoDay } from '@/schemas/health';
import type { Insight, Readiness } from '@/schemas/insights';
import type { FoodTag, NutritionTargets } from '@/schemas/nutrition';
import type { ResolvedProfile } from '@/schemas/profile';
import { HEALTH_GOAL_META } from '@/schemas/profile';
import { formatDuration } from '@/lib/date';
import type { EngineContext } from '@/features/correlation/context';
import { READINESS_COPY } from '@/features/correlation/readiness';
import { PHASE_GUIDANCE, type CyclePhase } from '@/features/cycle/phase';
import type { WeeklyNutritionSummary } from '@/features/nutrition/patterns';
import { headlinePattern } from '@/features/nutrition/patterns';
import { FOOD_DATABASE, dietaryConflict } from '@/features/nutrition/food-database';
import { needsAttention } from '@/features/labs/reference-ranges';

/**
 * The morning brief.
 *
 * One composed plan for the day, assembled from four inputs that no single
 * existing app holds together: circulating biochemistry (blood work), last
 * night's recovery (wearable), where the user is in their cycle, and what they
 * have actually been eating this week.
 *
 * Every sentence below is *composed*, not generated — the same inputs always
 * produce the same brief, it works with the network off, and there is no way
 * for it to invent a biomarker the user does not have. The cost of that choice
 * is that the prose is assembled from clauses rather than written fresh; the
 * benefit is that it can be audited line by line, which for anything touching
 * blood results is the right trade.
 *
 * Nothing here diagnoses. The strongest thing a brief will ever say is "this is
 * worth taking to a clinician".
 */

export type WorkoutIntensity = 'rest' | 'easy' | 'moderate' | 'hard';

export interface BriefTarget {
  id: 'calories' | 'protein' | 'water' | 'steps' | 'sleep';
  label: string;
  value: string;
  /** Short justification — a target with no reason behind it gets ignored. */
  basis: string;
}

/** A signal that measurably shaped today's plan, listed for transparency. */
export interface BriefDriver {
  id: string;
  kind: 'recovery' | 'sleep' | 'cycle' | 'labs' | 'nutrition';
  label: string;
  detail: string;
}

export interface DailyBrief {
  day: IsoDay;
  generatedAt: string;
  /** One line, the thing to read if nothing else. */
  headline: string;
  /** Two to four composed sentences explaining the day. */
  narrative: string[];
  targets: BriefTarget[];
  workout: {
    intensity: WorkoutIntensity;
    title: string;
    detail: string;
  };
  foodFocus: {
    title: string;
    detail: string;
    tags: FoodTag[];
    /** Concrete, diet-compatible examples from the food table. */
    examples: Array<{ id: string; name: string; portionLabel: string }>;
  };
  drivers: BriefDriver[];
  /** Honest limits on what the brief could see. */
  caveats: string[];
  /** Underlying numeric targets, for the progress rings. */
  raw: NutritionTargets;
}

export interface ComposeInput {
  day: IsoDay;
  now: string;
  profile: ResolvedProfile;
  targets: NutritionTargets;
  context: EngineContext | null;
  readiness: Readiness | null;
  insights: Insight[];
  phase: CyclePhase | null;
  nutrition: WeeklyNutritionSummary;
  /** Most recent day of telemetry — "last night" for sleep purposes. */
  lastNight: DailySnapshot | null;
}

const INTENSITY_COPY: Record<WorkoutIntensity, { title: string; detail: string }> = {
  rest: {
    title: 'Rest or a walk',
    detail: 'Nothing that raises your heart rate for long. A 20–30 minute walk is ideal.',
  },
  easy: {
    title: 'Easy aerobic, 30–40 min',
    detail: 'Zone 2 — you should be able to hold a conversation the whole way through.',
  },
  moderate: {
    title: 'Moderate session, 45 min',
    detail: 'A normal training day: strength work at your usual loads, or a steady run.',
  },
  hard: {
    title: 'Hard session — take it',
    detail: 'Intervals or a heavy strength day. Your markers say you can absorb it.',
  },
};

/** Ranks intensity so the several inputs that cap it can be combined by `min`. */
const INTENSITY_ORDER: WorkoutIntensity[] = ['rest', 'easy', 'moderate', 'hard'];

function capIntensity(a: WorkoutIntensity, b: WorkoutIntensity): WorkoutIntensity {
  return INTENSITY_ORDER.indexOf(a) <= INTENSITY_ORDER.indexOf(b) ? a : b;
}

function decideWorkout(input: ComposeInput): {
  intensity: WorkoutIntensity;
  drivers: BriefDriver[];
} {
  const drivers: BriefDriver[] = [];

  // Start from recovery. With no readiness score, assume a normal day rather
  // than prescribing either rest or hard work on no evidence.
  let intensity: WorkoutIntensity = 'moderate';

  if (input.readiness) {
    switch (input.readiness.band) {
      case 'compromised':
        intensity = 'rest';
        break;
      case 'low':
        intensity = 'easy';
        break;
      case 'moderate':
        intensity = 'moderate';
        break;
      case 'primed':
        intensity = 'hard';
        break;
    }
    drivers.push({
      id: 'readiness',
      kind: 'recovery',
      label: `Readiness ${input.readiness.score} — ${READINESS_COPY[input.readiness.band].label.toLowerCase()}`,
      detail: READINESS_COPY[input.readiness.band].blurb,
    });
  }

  // Last night's sleep can only lower the ceiling, never raise it: one good
  // night does not undo a suppressed HRV.
  const asleep = input.lastNight?.sleep?.asleepMinutes ?? null;
  if (asleep != null) {
    if (asleep < 330) {
      intensity = capIntensity(intensity, 'easy');
      drivers.push({
        id: 'sleep-short',
        kind: 'sleep',
        label: `${formatDuration(asleep / 60)} of sleep last night`,
        detail: 'Under five and a half hours. Intensity today will cost more than it returns.',
      });
    } else if (asleep < 390) {
      intensity = capIntensity(intensity, 'moderate');
      drivers.push({
        id: 'sleep-light',
        kind: 'sleep',
        label: `${formatDuration(asleep / 60)} of sleep last night`,
        detail: 'A little short of your target — fine for steady work, not for a personal best.',
      });
    } else {
      drivers.push({
        id: 'sleep-good',
        kind: 'sleep',
        label: `${formatDuration(asleep / 60)} of sleep last night`,
        detail: 'A solid night. This is the single biggest input into today going well.',
      });
    }
  }

  // Cycle phase adjusts, and its guidance is a cap in the luteal and menstrual
  // phases rather than a licence to push in the follicular one.
  if (input.phase) {
    const guidance = PHASE_GUIDANCE[input.phase.name];
    if (guidance.trainingBias === 'ease') intensity = capIntensity(intensity, 'easy');
    if (guidance.trainingBias === 'maintain') intensity = capIntensity(intensity, 'moderate');

    drivers.push({
      id: 'cycle',
      kind: 'cycle',
      label: `${input.phase.label}, day ${input.phase.dayOfCycle}`,
      detail: guidance.training,
    });
  }

  // An urgent lab finding outranks everything else on this screen.
  const urgent = input.insights.find((insight) => insight.severity === 'urgent');
  if (urgent) {
    intensity = capIntensity(intensity, 'easy');
    drivers.push({
      id: `insight-${urgent.id}`,
      kind: 'labs',
      label: urgent.title,
      detail: 'Worth a clinician’s eyes. Keep training easy until you have had that conversation.',
    });
  }

  return { intensity, drivers };
}

/**
 * What the user should actually eat today, in priority order:
 * a flagged biomarker beats a weekly pattern, which beats cycle phase, which
 * beats the standing goal.
 */
function decideFoodFocus(input: ComposeInput): {
  focus: DailyBrief['foodFocus'];
  drivers: BriefDriver[];
} {
  const drivers: BriefDriver[] = [];
  let title = 'Eat for your goal';
  let detail = HEALTH_GOAL_META[input.profile.goal].hint;
  let tags: FoodTag[] = ['high-protein', 'high-fibre'];

  // --- 1. Blood work ------------------------------------------------------
  const flagged = input.context
    ? [...input.context.biomarkers.values()].filter((b) => needsAttention(b.flag))
    : [];

  const ferritin = flagged.find((b) => b.code === 'ferritin' || b.code === 'hemoglobin');
  const glucose = flagged.find(
    (b) => b.code === 'hba1c' || b.code === 'fastingGlucose' || b.code === 'fastingInsulin',
  );
  const lipids = flagged.find(
    (b) => b.code === 'ldl' || b.code === 'triglycerides' || b.code === 'totalCholesterol',
  );
  const vitaminD = flagged.find((b) => b.code === 'vitaminD');
  const b12 = flagged.find((b) => b.code === 'vitaminB12');

  if (ferritin) {
    title = 'Iron, with vitamin C alongside it';
    detail = `Your ${ferritin.displayName.toLowerCase()} came back at ${ferritin.value} ${ferritin.unit}. Pair an iron source with something high in vitamin C in the same meal, and keep tea or coffee an hour clear of it — that alone can double how much you absorb.`;
    tags = ['iron-rich', 'vitamin-c-rich', 'leafy-green'];
    drivers.push({
      id: 'labs-iron',
      kind: 'labs',
      label: `${ferritin.displayName} ${ferritin.value} ${ferritin.unit}`,
      detail: 'Iron status is the limiter on oxygen transport, and it shows up in HRV before it shows up in how you feel.',
    });
  } else if (glucose) {
    title = 'Protein and fibre first, starch second';
    detail = `Your ${glucose.displayName.toLowerCase()} is ${glucose.value} ${glucose.unit}. Eating the protein and vegetables on the plate before the rice or roti measurably flattens the glucose response to the same meal.`;
    tags = ['high-protein', 'high-fibre', 'low-carb'];
    drivers.push({
      id: 'labs-glucose',
      kind: 'labs',
      label: `${glucose.displayName} ${glucose.value} ${glucose.unit}`,
      detail: 'Meal order and fibre do more for post-meal glucose than cutting total carbohydrate does.',
    });
  } else if (lipids) {
    title = 'Soluble fibre and unsaturated fat';
    detail = `Your ${lipids.displayName.toLowerCase()} is ${lipids.value} ${lipids.unit}. Oats, dal, chana and nuts move this; swapping fried food for grilled moves it faster.`;
    tags = ['high-fibre', 'wholegrain', 'omega3-rich'];
    drivers.push({
      id: 'labs-lipids',
      kind: 'labs',
      label: `${lipids.displayName} ${lipids.value} ${lipids.unit}`,
      detail: 'Soluble fibre binds bile acids, which is the mechanism behind most diet-driven LDL reduction.',
    });
  } else if (b12 || vitaminD) {
    const marker = b12 ?? vitaminD;
    title = b12 ? 'B12-dense food today' : 'Get outside, and eat oily fish';
    detail = b12
      ? `Your B12 is ${marker?.value} ${marker?.unit}. Dairy, eggs and fortified foods help, but a plant-based diet almost always needs a supplement to fix this properly.`
      : `Your vitamin D is ${marker?.value} ${marker?.unit}. Sunlight does most of the work here; oily fish and fortified dairy do the rest.`;
    tags = b12 ? ['high-protein', 'calcium-rich'] : ['omega3-rich', 'calcium-rich'];
    drivers.push({
      id: 'labs-vitamin',
      kind: 'labs',
      label: `${marker?.displayName} ${marker?.value} ${marker?.unit}`,
      detail: 'Both of these track with fatigue and low mood long before they reach a clinical deficiency.',
    });
  } else {
    // --- 2. Weekly pattern ------------------------------------------------
    const pattern = headlinePattern(input.nutrition);
    if (pattern && pattern.tone === 'concern') {
      switch (pattern.id) {
        case 'protein-short':
          title = 'Get protein into every meal';
          tags = ['high-protein'];
          break;
        case 'sugar-over':
          title = 'Keep added sugar off the plate today';
          tags = ['high-fibre', 'high-protein'];
          break;
        case 'fibre-short':
          title = 'Fibre at every meal';
          tags = ['high-fibre', 'wholegrain'];
          break;
        case 'sodium-high':
          title = 'Cook at home today if you can';
          tags = ['high-fibre', 'high-protein'];
          break;
        default:
          title = 'Steady, home-cooked day';
          tags = ['high-protein', 'high-fibre'];
          break;
      }
      detail = pattern.detail;
      drivers.push({
        id: `nutrition-${pattern.id}`,
        kind: 'nutrition',
        label: pattern.title,
        detail: pattern.detail,
      });
    } else if (input.phase) {
      // --- 3. Cycle phase -------------------------------------------------
      const guidance = PHASE_GUIDANCE[input.phase.name];
      title = `Eat for your ${input.phase.name} phase`;
      detail = guidance.nutrition;
      tags = guidance.favourTags;
    }
  }

  // Merge in the phase's preferred tags even when the headline came from labs —
  // the two rarely conflict and the ranking benefits from both.
  if (input.phase) {
    for (const tag of PHASE_GUIDANCE[input.phase.name].favourTags) {
      if (!tags.includes(tag)) tags.push(tag);
    }
  }

  const examples = FOOD_DATABASE.filter(
    (item) =>
      item.tags.some((tag) => tags.includes(tag)) &&
      dietaryConflict(item, {
        dietPattern: input.profile.dietPattern,
        allergens: input.profile.allergens,
      }) == null,
  )
    // Prefer the user's own cuisines, so "iron-rich" surfaces palak paneer
    // rather than a spinach salad they will never eat.
    .sort((a, b) => {
      const rank = (cuisine: typeof a.cuisine) =>
        cuisine == null ? 99 : (input.profile.cuisines.indexOf(cuisine) + 1 || 98);
      return rank(a.cuisine) - rank(b.cuisine);
    })
    .slice(0, 4)
    .map((item) => ({ id: item.id, name: item.name, portionLabel: item.portionLabel }));

  return { focus: { title, detail, tags: tags.slice(0, 4), examples }, drivers };
}

function buildTargets(input: ComposeInput): BriefTarget[] {
  const { targets } = input;

  return [
    {
      id: 'calories',
      label: 'Calories',
      value: `${targets.calories}`,
      basis:
        targets.energyBasis === 'measured'
          ? 'From your measured burn this week'
          : `Estimated from your ${input.profile.activityLevel.replace('-', ' ')} activity level`,
    },
    {
      id: 'protein',
      label: 'Protein',
      value: `${targets.macros.proteinG} g`,
      basis:
        input.profile.goal === 'weight-loss'
          ? 'Held high to protect lean mass in a deficit'
          : 'Set per kilo of bodyweight for your goal',
    },
    {
      id: 'water',
      label: 'Water',
      value: `${(targets.waterMl / 1000).toFixed(1)} L`,
      basis: 'Baseline plus replacement for yesterday’s activity',
    },
    {
      id: 'steps',
      label: 'Steps',
      value: targets.stepTarget.toLocaleString(),
      basis: 'A nudge above your own two-week average',
    },
    {
      id: 'sleep',
      label: 'Sleep',
      value: formatDuration(targets.sleepTargetMinutes / 60),
      basis:
        targets.sleepTargetMinutes > 480
          ? 'Extended to repay this week’s debt'
          : 'Standard adult target',
    },
  ];
}

function buildNarrative(
  input: ComposeInput,
  focus: DailyBrief['foodFocus'],
): { headline: string; narrative: string[] } {
  const sentences: string[] = [];

  // Sentence 1 — where the body is this morning.
  let headline: string;
  if (input.readiness) {
    const copy = READINESS_COPY[input.readiness.band];
    headline =
      input.readiness.band === 'primed'
        ? 'Your body is ready for a hard day.'
        : input.readiness.band === 'moderate'
          ? 'A normal day — train as planned.'
          : input.readiness.band === 'low'
            ? 'Recovery is down. Keep today light.'
            : 'Your markers say rest today.';
    sentences.push(`Readiness is ${input.readiness.score} out of 100. ${copy.blurb}`);
  } else {
    headline = 'Building your baseline.';
    sentences.push(
      'There is not yet enough wearable history to score your recovery — a week of consistent wear unlocks it.',
    );
  }

  // Sentence 2 — last night, specifically.
  const sleep = input.lastNight?.sleep;
  if (sleep) {
    const efficiency = sleep.efficiency != null ? ` at ${Math.round(sleep.efficiency * 100)}% efficiency` : '';
    sentences.push(
      `You slept ${formatDuration(sleep.asleepMinutes / 60)}${efficiency}, with ${Math.round(sleep.deepMinutes)} minutes of deep and ${Math.round(sleep.remMinutes)} of REM.`,
    );
  }

  // Sentence 3 — the cycle, when tracked.
  if (input.phase) {
    sentences.push(input.phase.summary);
    const expected = PHASE_GUIDANCE[input.phase.name].expectedTelemetryNote;
    if (expected != null && input.readiness != null && input.readiness.score < 50) {
      sentences.push(expected);
    }
  }

  // Sentence 4 — the week's eating, and today's focus.
  const pattern = headlinePattern(input.nutrition);
  if (input.nutrition.isSparse) {
    sentences.push(
      'Log a few meals and this brief starts folding your eating patterns into the plan as well.',
    );
  } else if (pattern) {
    sentences.push(`${pattern.title}. ${focus.title.toLowerCase()} today.`);
  }

  return { headline, narrative: sentences };
}

function buildCaveats(input: ComposeInput): string[] {
  const caveats: string[] = [];

  if (input.context == null || input.context.series.length === 0) {
    caveats.push('No wearable data yet — targets are estimated from your profile alone.');
  } else if (input.readiness == null) {
    caveats.push('Readiness needs seven days of baseline before it can be scored.');
  }

  if ((input.context?.biomarkers.size ?? 0) === 0) {
    caveats.push('No blood work on file, so nothing here is informed by your biochemistry yet.');
  }

  if (input.nutrition.isSparse) {
    caveats.push(`Only ${input.nutrition.loggedDays} day(s) of food logged this week.`);
  }

  if (input.phase?.confidence === 'low') {
    caveats.push('Cycle phase is a low-confidence estimate — log your next period start to sharpen it.');
  }

  if (input.targets.isCheatDay) {
    caveats.push('Cheat day is on: calories are 15% higher and the sugar ceiling is relaxed.');
  }

  return caveats;
}

export function composeBrief(input: ComposeInput): DailyBrief {
  const { intensity, drivers: workoutDrivers } = decideWorkout(input);
  const { focus, drivers: foodDrivers } = decideFoodFocus(input);
  const { headline, narrative } = buildNarrative(input, focus);

  return {
    day: input.day,
    generatedAt: input.now,
    headline,
    narrative,
    targets: buildTargets(input),
    workout: { intensity, ...INTENSITY_COPY[intensity] },
    foodFocus: focus,
    // Recovery and sleep first — they are what changed since yesterday.
    drivers: [...workoutDrivers, ...foodDrivers],
    caveats: buildCaveats(input),
    raw: input.targets,
  };
}
