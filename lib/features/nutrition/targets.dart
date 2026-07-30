import 'dart:math' as math;

import '../../domain/entities/gender.dart';
import '../../domain/entities/health/daily_snapshot.dart';
import '../../domain/entities/nutrition/nutrition_targets.dart';
import '../../domain/entities/profile/diet_pattern.dart';
import '../../domain/entities/user_profile.dart';
import '../cycle/menstrual_phase.dart';

/// Daily energy, macro, hydration and movement targets.
/// Ported from `src/features/nutrition/targets.ts`.
///
/// Every number here is derived from published equations rather than generated,
/// so the same profile always produces the same targets and the brief can be
/// regenerated offline. Where a wearable can measure something we would
/// otherwise estimate — total energy expenditure, in practice — the measurement
/// wins and the activity multiplier is only a fallback.

/// Mifflin–St Jeor, the best-validated BMR estimator for the general adult
/// population.
double? basalMetabolicRate(UserProfile profile) {
  final weight = profile.weightKg;
  final height = profile.heightCm;
  final age = profile.ageYears;
  if (weight == null || height == null || age == null) return null;

  final base = 10 * weight + 6.25 * height - 5 * age;

  return switch (profile.gender) {
    Gender.male => base + 5,
    Gender.female => base - 161,
  };
}

/// Median active energy across the trailing week, in kcal.
///
/// HealthKit reports *active* energy (above resting), which is exactly the term
/// the activity multiplier is standing in for. Fewer than four days is too
/// sparse to read as a habit.
double? _measuredActiveEnergy(List<DailySnapshot> series) {
  final values = series
      .skip(math.max(0, series.length - 7))
      .map((day) => day.activeEnergy)
      .whereType<double>()
      .where((value) => value > 0)
      .toList();

  if (values.length < 4) return null;

  values.sort();
  final mid = values.length ~/ 2;
  return values.length.isEven
      ? (values[mid - 1] + values[mid]) / 2
      : values[mid];
}

MacroTargets _macroSplit(UserProfile profile, int calories, double weightKg) {
  final proteinG = (profile.goal.proteinPerKg * weightKg).round();

  // Carbohydrate share, before the protein and fat floors are honoured.
  var carbShare = 0.45;
  if (profile.restrictions.contains(Restriction.lowCarb)) carbShare = 0.25;
  if (profile.conditions.contains(Condition.type2Diabetes) ||
      profile.conditions.contains(Condition.prediabetes)) {
    carbShare = math.min(carbShare, 0.35);
  }
  if (profile.conditions.contains(Condition.pcos)) {
    carbShare = math.min(carbShare, 0.35);
  }

  final carbsG = (calories * carbShare / 4).round();
  // Fat takes the remainder, with a 0.5 g/kg floor for hormone synthesis.
  final remainingKcal = calories - proteinG * 4 - carbsG * 4;
  final fatG = math.max((weightKg * 0.5).round(), (remainingKcal / 9).round());

  // Fibre: 14 g per 1000 kcal, the Institute of Medicine's adequate intake.
  final fibreG = (calories / 1000 * 14).round();

  return MacroTargets(
    proteinG: proteinG,
    carbsG: carbsG,
    fatG: fatG,
    fibreG: fibreG,
  );
}

/// Added-sugar ceiling in grams.
///
/// The WHO conditional recommendation is under 5% of energy; the AHA caps are
/// 25 g (women) and 36 g (men). We take the stricter of the two so the number is
/// defensible either way.
int _addedSugarCeiling(UserProfile profile, int calories) {
  final fivePercent = (calories * 0.05 / 4).round();
  final ahaCap = profile.gender == Gender.male ? 36 : 25;
  final base = math.min(fivePercent, ahaCap);

  if (profile.conditions.contains(Condition.type2Diabetes) ||
      profile.conditions.contains(Condition.prediabetes) ||
      profile.conditions.contains(Condition.fattyLiver)) {
    return (base * 0.6).round();
  }
  return base;
}

/// Returns null when the profile is missing height, weight or age — inventing a
/// calorie target from a guessed bodyweight is worse than showing none.
NutritionTargets? computeTargets({
  required UserProfile profile,

  /// Trailing telemetry, newest last. Used to measure rather than estimate.
  required List<DailySnapshot> series,

  /// Null when the user does not track a cycle.
  MenstrualPhase? phase,

  /// Cheat days lift the calorie ceiling and relax the sugar cap.
  bool isCheatDay = false,
}) {
  final bmr = basalMetabolicRate(profile);
  final weightKg = profile.weightKg;
  if (bmr == null || weightKg == null) return null;

  final measured = _measuredActiveEnergy(series);
  final maintenance = measured != null
      // Resting expenditure (BMR plus the thermic effect of food, ~10%) plus
      // what the watch actually saw the user burn.
      ? (bmr * 1.1 + measured).round()
      : (bmr * profile.activityLevel.multiplier).round();

  var calories = maintenance + profile.goal.calorieOffset;

  // Luteal-phase resting expenditure runs measurably higher — the reported
  // range is 2–12%; 5% is the conservative middle. Not applying it is why
  // generic trackers tell people they overate in the week before their period.
  if (phase?.name == MenstrualPhaseName.luteal) {
    calories = (calories * 1.05).round();
  }

  // Never prescribe below the floor at which micronutrient adequacy becomes
  // hard, regardless of what the deficit maths says.
  final floor = profile.gender == Gender.male ? 1500 : 1200;
  calories = math.max(floor, calories);

  if (isCheatDay) calories = (calories * 1.15).round();

  final macros = _macroSplit(profile, calories, weightKg);

  // Hydration: 35 mL/kg baseline, plus replacement for measured sweat loss
  // approximated at 500 mL per 500 kcal of active energy.
  final activeToday =
      (series.isNotEmpty ? series.last.activeEnergy : null) ?? measured ?? 0;
  final waterMl = ((weightKg * 35 + activeToday) / 50).round() * 50;

  // Step target: nudge from the trailing baseline rather than prescribing a
  // round 10,000 to someone who averages 4,000. Capped so a rest day after a
  // heavy week is not framed as a failure.
  final recentSteps = series
      .skip(math.max(0, series.length - 14))
      .map((d) => d.steps)
      .whereType<double>()
      .toList();
  final stepBaseline = recentSteps.isNotEmpty
      ? recentSteps.reduce((a, b) => a + b) / recentSteps.length
      : 6000.0;
  final stepTarget = math.min(14000, (stepBaseline * 1.08 / 250).round() * 250);

  // Sleep target: 8 h for adults, extended when the trailing week ran a debt.
  // Anything above 9 h stops being a target and becomes a symptom.
  final recentSleep = series
      .skip(math.max(0, series.length - 7))
      .map((d) => d.sleep?.asleepMinutes)
      .whereType<double>()
      .toList();
  final sleepMean = recentSleep.isNotEmpty
      ? recentSleep.reduce((a, b) => a + b) / recentSleep.length
      : 450.0;
  final sleepTargetMinutes = math.min(
    540,
    math.max(450, ((480 + (480 - sleepMean) * 0.5) / 15).round() * 15),
  );

  return NutritionTargets(
    calories: calories,
    maintenanceCalories: maintenance,
    energyBasis: measured != null
        ? EnergyBasis.measured
        : EnergyBasis.estimated,
    macros: macros,
    addedSugarCeilingG: _addedSugarCeiling(profile, calories),
    waterMl: waterMl,
    stepTarget: stepTarget,
    sleepTargetMinutes: sleepTargetMinutes,
    isCheatDay: isCheatDay,
  );
}

/// Population-typical body composition, used only to keep the demo and the
/// first-run experience showing real arithmetic before the user has entered
/// their height and weight.
///
/// Anything derived from this is labelled as estimated in the UI: the point is
/// to show the mechanism, never to pass a default off as a measurement.
UserProfile withAssumedBodyComposition(UserProfile profile) {
  if (profile.heightCm != null && profile.weightKg != null) return profile;
  return profile.copyWith(
    heightCm: profile.heightCm ?? (profile.gender == Gender.male ? 175 : 162),
    weightKg: profile.weightKg ?? (profile.gender == Gender.male ? 75 : 63),
  );
}
