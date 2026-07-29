import type { Biomarker, LabReport } from '@/schemas/labs';
import { LabReportSchema } from '@/schemas/labs';
import type { HealthProfile } from '@/schemas/profile';
import type { MealEntry, MealSlot } from '@/schemas/nutrition';
import { MealEntrySchema, scaleMacros } from '@/schemas/nutrition';
import type { IsoDay } from '@/schemas/health';
import { addDays, toIsoDay } from '@/lib/date';
import { findFood } from '@/features/nutrition/food-database';
import { enrichBiomarker } from '@/features/labs/reference-ranges';
import { useProfileStore } from '@/store/profile.store';
import { useNutritionStore } from '@/store/nutrition.store';
import { useLabsStore } from '@/store/labs.store';
import { useSettingsStore } from '@/store/settings.store';
import { log } from '@/lib/logger';

/**
 * Demo persona.
 *
 * Seeds a coherent user — profile, blood work, a fortnight of food, hydration
 * and a cycle history — chosen so that every feature has something real to say
 * rather than an empty state. It is coherent on purpose: the low ferritin, the
 * suppressed HRV in the synthetic telemetry, the iron-poor week of eating and
 * the luteal phase all point at the same story, which is the story the product
 * exists to tell.
 *
 * Everything written here goes through the same schemas and stores as real
 * user data, and `source: 'seed'` on the meals means a demo log is always
 * distinguishable from a genuine one. `clearDemoPersona` removes it again.
 */

export const DEMO_PERSONA_NAME = 'Priya';

// ---------------------------------------------------------------------------
// Profile
// ---------------------------------------------------------------------------

const DEMO_PROFILE: Partial<HealthProfile> = {
  displayName: DEMO_PERSONA_NAME,
  goal: 'general-wellness',
  conditions: [],
  heightCm: 163,
  weightKg: 58,
  targetWeightKg: null,
  activityLevel: 'moderate',
  dietPattern: 'vegetarian',
  allergens: [],
  restrictions: [],
  // Ordered: the ranker treats position as preference weight, so South Indian
  // dishes surface ahead of North Indian ones, ahead of everything else.
  cuisines: ['south-indian', 'north-indian', 'mediterranean'],
  spiceTolerance: 'medium',
};

/**
 * Three logged periods ending 19 days ago puts the persona mid-luteal today
 * with a *measured* 29-day cycle — so the phase reads at high confidence rather
 * than falling back on the textbook 28.
 */
function demoCycle(now: Date) {
  const starts: IsoDay[] = [
    toIsoDay(addDays(now, -77)),
    toIsoDay(addDays(now, -48)),
    toIsoDay(addDays(now, -19)),
  ];

  return {
    tracks: true,
    periodStarts: starts,
    averageCycleDays: 29,
    averagePeriodDays: 5,
    hormonalContraception: false,
  };
}

// ---------------------------------------------------------------------------
// Blood work
// ---------------------------------------------------------------------------

interface SeedMarker {
  code: Biomarker['code'];
  rawName: string;
  displayName: string;
  category: Biomarker['category'];
  value: number;
  unit: string;
  low: number | null;
  high: number | null;
}

/**
 * A panel that is entirely "normal" on the printed report — which is the whole
 * point. Ferritin at 18 clears the lab's own floor of 15 and would be reported
 * without comment; against the optimal band, and alongside three weeks of
 * falling HRV, it is the most actionable number the user has.
 */
const DEMO_MARKERS: SeedMarker[] = [
  { code: 'ferritin', rawName: 'Ferritin, Serum', displayName: 'Ferritin', category: 'iron', value: 18, unit: 'ng/mL', low: 15, high: 200 },
  { code: 'hemoglobin', rawName: 'Haemoglobin', displayName: 'Haemoglobin', category: 'iron', value: 12.4, unit: 'g/dL', low: 12, high: 15.5 },
  { code: 'vitaminD', rawName: '25-OH Vitamin D', displayName: 'Vitamin D', category: 'micronutrient', value: 21, unit: 'ng/mL', low: 20, high: 100 },
  { code: 'vitaminB12', rawName: 'Vitamin B12', displayName: 'Vitamin B12', category: 'micronutrient', value: 232, unit: 'pg/mL', low: 200, high: 900 },
  { code: 'hsCrp', rawName: 'hs-CRP', displayName: 'hs-CRP', category: 'inflammation', value: 2.4, unit: 'mg/L', low: 0, high: 3 },
  { code: 'tsh', rawName: 'TSH, Ultrasensitive', displayName: 'TSH', category: 'thyroid', value: 2.8, unit: 'µIU/mL', low: 0.4, high: 4.5 },
  { code: 'hba1c', rawName: 'HbA1c', displayName: 'HbA1c', category: 'glycemic', value: 5.3, unit: '%', low: 4, high: 5.7 },
  { code: 'ldl', rawName: 'LDL Cholesterol', displayName: 'LDL', category: 'lipids', value: 104, unit: 'mg/dL', low: 0, high: 130 },
  { code: 'hdl', rawName: 'HDL Cholesterol', displayName: 'HDL', category: 'lipids', value: 58, unit: 'mg/dL', low: 50, high: 90 },
  { code: 'triglycerides', rawName: 'Triglycerides', displayName: 'Triglycerides', category: 'lipids', value: 96, unit: 'mg/dL', low: 0, high: 150 },
];

function demoReport(now: Date, sex: 'male' | 'female' | 'unspecified'): LabReport {
  const collectedAt = addDays(now, -9);

  const biomarkers = DEMO_MARKERS.map((marker) =>
    enrichBiomarker(
      {
        code: marker.code,
        rawName: marker.rawName,
        displayName: marker.displayName,
        category: marker.category,
        value: marker.value,
        unit: marker.unit,
        range: {
          low: marker.low,
          high: marker.high,
          optimalLow: null,
          optimalHigh: null,
          source: 'lab' as const,
        },
        flag: 'unknown' as const,
        confidence: 0.97,
        sourcePage: 1,
      },
      sex,
    ),
  );

  return LabReportSchema.parse({
    id: 'demo-report-1',
    source: 'pdf',
    status: 'ready',
    collectedAt: collectedAt.toISOString(),
    uploadedAt: addDays(now, -8).toISOString(),
    labName: 'Demo Diagnostics',
    panelName: 'Comprehensive Wellness Panel',
    biomarkers,
    fileUri: null,
    fileName: 'wellness-panel.pdf',
    fileSizeBytes: 428_000,
    error: null,
  });
}

// ---------------------------------------------------------------------------
// Food log
// ---------------------------------------------------------------------------

/**
 * Fourteen days of vegetarian eating with a specific, findable shape: protein
 * consistently short of target, added sugar over on four days, and fibre fine.
 * That is what makes the weekly pattern card say something worth reading rather
 * than "nothing to flag".
 */
const DAY_PLANS: Array<Array<[MealSlot, string, number, number]>> = [
  // [slot, foodId, portions, hour]
  [['breakfast', 'idli', 2, 8], ['breakfast', 'coconut-chutney', 1, 8], ['lunch', 'plain-rice', 1, 13], ['lunch', 'sambar', 1, 13], ['dinner', 'roti', 2, 20], ['dinner', 'mixed-sabzi', 1, 20], ['snack', 'masala-chai', 2, 16]],
  [['breakfast', 'masala-dosa', 1, 9], ['lunch', 'curd-rice', 1, 13], ['dinner', 'roti', 3, 21], ['dinner', 'dal-tadka', 1, 21], ['snack', 'chocolate-bar', 1, 17]],
  [['breakfast', 'upma', 1, 8], ['lunch', 'plain-rice', 1, 13], ['lunch', 'rasam', 1, 13], ['dinner', 'palak-paneer', 1, 20], ['dinner', 'roti', 2, 20]],
  [['breakfast', 'oats-porridge', 1, 8], ['lunch', 'chole', 1, 13], ['lunch', 'roti', 2, 13], ['dinner', 'plain-dosa', 2, 21], ['snack', 'gulab-jamun', 1, 18], ['snack', 'masala-chai', 2, 16]],
  [['breakfast', 'idli', 3, 8], ['lunch', 'curd-rice', 1, 14], ['dinner', 'mixed-sabzi', 1, 20], ['dinner', 'roti', 2, 20], ['snack', 'banana', 1, 11]],
  [['breakfast', 'aloo-paratha', 1, 9], ['lunch', 'rajma', 1, 13], ['lunch', 'plain-rice', 1, 13], ['dinner', 'paneer-tikka', 1, 21], ['snack', 'sweet-lassi', 1, 17]],
  [['breakfast', 'ven-pongal', 1, 8], ['lunch', 'sambar', 1, 13], ['lunch', 'plain-rice', 1, 13], ['dinner', 'roti', 2, 20], ['dinner', 'dal-makhani', 1, 20], ['snack', 'ice-cream', 1, 22]],
];

function demoMeals(now: Date): MealEntry[] {
  const out: MealEntry[] = [];

  for (let offset = 13; offset >= 0; offset -= 1) {
    const date = addDays(now, -offset);
    const day = toIsoDay(date);
    const plan = DAY_PLANS[offset % DAY_PLANS.length];
    if (plan == null) continue;

    // Today is deliberately part-logged — breakfast only — so the "remaining
    // calories" number on the demo is a real one with room in it.
    const entries = offset === 0 ? plan.filter(([slot]) => slot === 'breakfast') : plan;

    for (const [slot, foodId, portions, hour] of entries) {
      const definition = findFood(foodId);
      if (definition == null) {
        log.warn('nutrition', `Demo persona references an unknown food: ${foodId}`);
        continue;
      }

      const loggedAt = new Date(date);
      loggedAt.setHours(hour, (foodId.length * 7) % 60, 0, 0);

      out.push(
        MealEntrySchema.parse({
          id: `demo-meal-${day}-${slot}-${foodId}`,
          day,
          loggedAt: loggedAt.toISOString(),
          slot,
          source: 'seed',
          photoUri: null,
          foods: [
            {
              foodId: definition.id,
              name: definition.name,
              portions,
              macros: scaleMacros(definition.macros, portions),
              tags: definition.tags,
            },
          ],
          confidence: 1,
          note: null,
        }),
      );
    }
  }

  return out;
}

function demoHydration(now: Date): Record<string, number> {
  const out: Record<string, number> = {};
  for (let offset = 13; offset >= 0; offset -= 1) {
    const day = toIsoDay(addDays(now, -offset));
    // Consistently a little under target — enough for the hydration pattern to
    // fire without looking like the persona never drinks.
    out[day] = offset === 0 ? 750 : 1250 + ((offset * 137) % 500);
  }
  return out;
}

// ---------------------------------------------------------------------------
// Apply / clear
// ---------------------------------------------------------------------------

export function applyDemoPersona(now: Date = new Date()): void {
  const settings = useSettingsStore.getState();

  // The persona is female — the cycle half of the demo depends on it, and the
  // lab reference intervals for ferritin and haemoglobin differ by sex.
  settings.setSex('female');
  settings.setBirthYear(now.getFullYear() - 31);

  useProfileStore.getState().hydrate({ ...DEMO_PROFILE, cycle: demoCycle(now) });
  useLabsStore.getState().upsertReport(demoReport(now, 'female'));
  useNutritionStore.getState().hydrate({
    meals: demoMeals(now),
    hydration: demoHydration(now),
    cheatDays: [],
  });

  log.info('store', 'Demo persona applied');
}

export function clearDemoPersona(): void {
  useNutritionStore.getState().clear();
  useLabsStore.getState().removeReport('demo-report-1');
  useProfileStore.getState().reset();
  log.info('store', 'Demo persona cleared');
}

/** True when the seeded report is present — drives the settings toggle. */
export function isDemoPersonaActive(): boolean {
  return useLabsStore.getState().reports.some((report) => report.id === 'demo-report-1');
}
