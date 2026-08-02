import 'dart:math' as math;

import '../../core/util/iso_day.dart';
import '../../domain/entities/nutrition/food_definition.dart';
import '../../domain/entities/nutrition/macros.dart';
import '../../domain/entities/nutrition/meal_entry.dart';
import '../../domain/entities/nutrition/nutrition_targets.dart';

/// Weekly nutrition pattern analysis.
/// Ported from `src/features/nutrition/patterns.ts`.
///
/// Answers the question a daily calorie total cannot: *what keeps happening*.
/// "You went over your calories today" is noise; "added sugar was over your
/// ceiling on four of the last seven days" is a finding.
///
/// Findings are counted over days, never averaged, because averaging is what
/// hides the pattern — three clean days and four heavy ones average out to
/// "fine". Days with no log at all are excluded from denominators rather than
/// treated as zero-intake days.

class DayTotals {
  const DayTotals({
    required this.day,
    required this.macros,
    required this.mealCount,
    required this.lastMealHour,
    required this.hydrationMl,
  });

  final IsoDay day;
  final Macros macros;
  final int mealCount;

  /// Latest logged meal hour, for the late-eating check.
  final int? lastMealHour;

  final int hydrationMl;

  /// A day counts toward the analysis only if it looks genuinely logged. One
  /// banana is not a food diary, and letting it into the denominator makes
  /// every "under target" finding meaningless.
  bool get isLogged => mealCount >= 2 || macros.calories >= 800;
}

enum PatternTone {
  /// Worth acting on.
  concern,

  /// Worth reinforcing.
  win,

  neutral,
}

class NutritionPattern {
  const NutritionPattern({
    required this.id,
    required this.title,
    required this.detail,
    required this.daysAffected,
    required this.daysConsidered,
    required this.tone,
    required this.weight,
  });

  final String id;

  /// Short headline: "Added sugar over target 4 of 7 days".
  final String title;

  /// One sentence of specifics.
  final String detail;

  final int daysAffected;
  final int daysConsidered;
  final PatternTone tone;

  /// Ranking weight, 0–100.
  final int weight;
}

class WeeklyNutritionSummary {
  const WeeklyNutritionSummary({
    required this.days,
    required this.loggedDays,
    required this.averages,
    required this.patterns,
    required this.isSparse,
  });

  final List<DayTotals> days;

  /// Days in the window that carry at least one real meal.
  final int loggedDays;

  /// Mean over logged days only.
  final Macros averages;

  final List<NutritionPattern> patterns;

  /// True when there is too little logging to say anything honest.
  final bool isSparse;

  /// The single pattern most worth putting in the morning brief.
  NutritionPattern? get headline {
    for (final pattern in patterns) {
      if (pattern.tone == PatternTone.concern) return pattern;
    }
    return patterns.isEmpty ? null : patterns.first;
  }
}

/// Below this, the analyser reports sparseness instead of inventing findings.
const int minLoggedDays = 3;

List<DayTotals> totalsByDay({
  required List<MealEntry> meals,
  required Map<IsoDay, int> hydration,
  required int windowDays,
  DateTime? now,
}) {
  final today = now ?? DateTime.now();

  final byDay = <IsoDay, List<MealEntry>>{};
  for (final meal in meals) {
    byDay.putIfAbsent(meal.day, () => []).add(meal);
  }

  final out = <DayTotals>[];
  for (var offset = windowDays - 1; offset >= 0; offset -= 1) {
    final day = toIsoDay(addDays(today, -offset));
    final dayMeals = byDay[day] ?? const <MealEntry>[];
    final hours = dayMeals.map((meal) => meal.loggedAt.hour).toList();

    out.add(
      DayTotals(
        day: day,
        macros: dayMeals.isEmpty
            ? Macros.empty
            : sumMacros(dayMeals.map((m) => m.macros)),
        mealCount: dayMeals.length,
        lastMealHour: hours.isEmpty ? null : hours.reduce(math.max),
        hydrationMl: hydration[day] ?? 0,
      ),
    );
  }

  return out;
}

double _meanOf(Iterable<num> values) {
  final list = values.toList();
  if (list.isEmpty) return 0;
  return list.reduce((a, b) => a + b) / list.length;
}

WeeklyNutritionSummary analyseWeek({
  required List<MealEntry> meals,
  required Map<IsoDay, int> hydration,
  required NutritionTargets? targets,
  int windowDays = 7,
  DateTime? now,
}) {
  final days = totalsByDay(
    meals: meals,
    hydration: hydration,
    windowDays: windowDays,
    now: now,
  );
  final logged = days.where((d) => d.isLogged).toList();

  final averages = Macros(
    calories: _meanOf(logged.map((d) => d.macros.calories)).round(),
    proteinG: _meanOf(logged.map((d) => d.macros.proteinG)).roundToDouble(),
    carbsG: _meanOf(logged.map((d) => d.macros.carbsG)).roundToDouble(),
    fatG: _meanOf(logged.map((d) => d.macros.fatG)).roundToDouble(),
    fibreG: _meanOf(logged.map((d) => d.macros.fibreG)).roundToDouble(),
    addedSugarG: _meanOf(
      logged.map((d) => d.macros.addedSugarG),
    ).roundToDouble(),
    sodiumMg: _meanOf(logged.map((d) => d.macros.sodiumMg)).round(),
  );

  final isSparse = logged.length < minLoggedDays;

  if (isSparse || targets == null) {
    return WeeklyNutritionSummary(
      days: days,
      loggedDays: logged.length,
      averages: averages,
      patterns: const [],
      isSparse: isSparse,
    );
  }

  final patterns = <NutritionPattern>[];
  final n = logged.length;
  String plural(int count) => count == 1 ? 'day' : 'days';

  // --- Added sugar -----------------------------------------------------------
  final sugarDays = logged
      .where((d) => d.macros.addedSugarG > targets.addedSugarCeilingG)
      .toList();
  if (sugarDays.length >= 2) {
    final worst = sugarDays
        .map((d) => d.macros.addedSugarG)
        .reduce(math.max)
        .round();
    patterns.add(
      NutritionPattern(
        id: 'sugar-over',
        title:
            'Added sugar over target ${sugarDays.length} of $n ${plural(n)}',
        detail:
            'Your ceiling is ${targets.addedSugarCeilingG} g. The heaviest day '
            'hit $worst g — roughly ${(worst / 4).round()} teaspoons.',
        daysAffected: sugarDays.length,
        daysConsidered: n,
        tone: PatternTone.concern,
        weight: 60 + sugarDays.length * 6,
      ),
    );
  }

  // --- Protein ---------------------------------------------------------------
  final proteinFloor = targets.macros.proteinG * 0.85;
  final lowProteinDays = logged
      .where((d) => d.macros.proteinG < proteinFloor)
      .toList();
  if (lowProteinDays.length >= 3) {
    final gap = (targets.macros.proteinG - averages.proteinG).round();
    patterns.add(
      NutritionPattern(
        id: 'protein-short',
        title: 'Protein short on ${lowProteinDays.length} of $n ${plural(n)}',
        detail:
            'You averaged ${averages.proteinG.round()} g against a '
            '${targets.macros.proteinG} g target. The gap is about $gap g a '
            'day — one more protein-led meal or a shake closes it.',
        daysAffected: lowProteinDays.length,
        daysConsidered: n,
        tone: PatternTone.concern,
        weight: 58 + lowProteinDays.length * 4,
      ),
    );
  } else if (lowProteinDays.isEmpty) {
    patterns.add(
      NutritionPattern(
        id: 'protein-consistent',
        title: 'Protein target hit every logged day',
        detail:
            'You averaged ${averages.proteinG.round()} g against a '
            '${targets.macros.proteinG} g target. This is the habit that '
            'protects lean mass — keep it.',
        daysAffected: n,
        daysConsidered: n,
        tone: PatternTone.win,
        weight: 40,
      ),
    );
  }

  // --- Fibre -----------------------------------------------------------------
  final lowFibreDays = logged
      .where((d) => d.macros.fibreG < targets.macros.fibreG * 0.7)
      .toList();
  if (lowFibreDays.length >= 3) {
    patterns.add(
      NutritionPattern(
        id: 'fibre-short',
        title: 'Fibre low on ${lowFibreDays.length} of $n ${plural(n)}',
        detail:
            '${averages.fibreG.round()} g a day against a '
            '${targets.macros.fibreG} g target. Beans, lentils, or swapping '
            'white rice for brown moves this fastest.',
        daysAffected: lowFibreDays.length,
        daysConsidered: n,
        tone: PatternTone.concern,
        weight: 50 + lowFibreDays.length * 3,
      ),
    );
  }

  // --- Energy balance --------------------------------------------------------
  final overDays = logged
      .where((d) => d.macros.calories > targets.calories * 1.12)
      .toList();
  final underDays = logged
      .where((d) => d.macros.calories < targets.calories * 0.75)
      .toList();
  if (overDays.length >= 3) {
    patterns.add(
      NutritionPattern(
        id: 'calories-over',
        title:
            'Over your calorie target ${overDays.length} of $n ${plural(n)}',
        detail:
            'Averaging ${averages.calories} kcal against ${targets.calories}. '
            'At this margin the weight trend will flatten rather than move.',
        daysAffected: overDays.length,
        daysConsidered: n,
        tone: PatternTone.concern,
        weight: 62,
      ),
    );
  } else if (underDays.length >= 3) {
    patterns.add(
      NutritionPattern(
        id: 'calories-under',
        title: 'Well under target ${underDays.length} of $n ${plural(n)}',
        detail:
            'Averaging ${averages.calories} kcal against ${targets.calories}. '
            'Under-eating this consistently is the most common reason HRV and '
            'sleep quality stall.',
        daysAffected: underDays.length,
        daysConsidered: n,
        tone: PatternTone.concern,
        weight: 64,
      ),
    );
  }

  // --- Ultra-processed and fried --------------------------------------------
  final friedDays = logged
      .where(
        (day) => meals.any(
          (meal) =>
              meal.day == day.day &&
              meal.foods.any(
                (f) =>
                    f.tags.contains(FoodTag.fried) ||
                    f.tags.contains(FoodTag.ultraProcessed),
              ),
        ),
      )
      .toList();
  if (friedDays.length >= 3) {
    patterns.add(
      NutritionPattern(
        id: 'processed-frequency',
        title:
            'Fried or ultra-processed food on ${friedDays.length} of $n '
            '${plural(n)}',
        detail:
            'Not a reason to panic on any single day, but at this frequency it '
            'is the main driver of your sodium and your saturated fat.',
        daysAffected: friedDays.length,
        daysConsidered: n,
        tone: PatternTone.concern,
        weight: 48,
      ),
    );
  }

  // --- Sodium ----------------------------------------------------------------
  // WHO recommends under 2000 mg of sodium a day.
  final highSodiumDays = logged.where((d) => d.macros.sodiumMg > 2300).toList();
  if (highSodiumDays.length >= 3) {
    patterns.add(
      NutritionPattern(
        id: 'sodium-high',
        title:
            'Sodium above 2.3 g on ${highSodiumDays.length} of $n ${plural(n)}',
        detail:
            'Averaging ${(averages.sodiumMg / 1000).toStringAsFixed(1)} g. '
            'Restaurant and packaged food, not your salt shaker, is almost '
            'always where this comes from.',
        daysAffected: highSodiumDays.length,
        daysConsidered: n,
        tone: PatternTone.concern,
        weight: 46,
      ),
    );
  }

  // --- Hydration -------------------------------------------------------------
  final dryDays = logged
      .where(
        (d) => d.hydrationMl > 0 && d.hydrationMl < targets.waterMl * 0.7,
      )
      .toList();
  if (dryDays.length >= 3) {
    patterns.add(
      NutritionPattern(
        id: 'hydration-short',
        title: 'Under your water target ${dryDays.length} of $n ${plural(n)}',
        detail:
            'Target is ${(targets.waterMl / 1000).toStringAsFixed(1)} L. Mild '
            'dehydration alone lifts resting heart rate a few beats, which then '
            'reads as poor recovery.',
        daysAffected: dryDays.length,
        daysConsidered: n,
        tone: PatternTone.concern,
        weight: 42,
      ),
    );
  }

  // --- Late eating -----------------------------------------------------------
  final lateDays = logged
      .where((d) => d.lastMealHour != null && d.lastMealHour! >= 22)
      .toList();
  if (lateDays.length >= 3) {
    patterns.add(
      NutritionPattern(
        id: 'late-eating',
        title: 'Last meal after 10pm on ${lateDays.length} of $n ${plural(n)}',
        detail:
            'Eating close to bedtime raises overnight heart rate and cuts deep '
            'sleep, which shows up as a low readiness score the next morning.',
        daysAffected: lateDays.length,
        daysConsidered: n,
        tone: PatternTone.concern,
        weight: 54,
      ),
    );
  }

  patterns.sort((a, b) => b.weight.compareTo(a.weight));

  return WeeklyNutritionSummary(
    days: days,
    loggedDays: logged.length,
    averages: averages,
    patterns: patterns,
    isSparse: false,
  );
}
