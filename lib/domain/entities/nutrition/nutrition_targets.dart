/// Ported from `NutritionTargetsSchema` in `src/schemas/nutrition.ts`.
library;

class MacroTargets {
  const MacroTargets({
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.fibreG,
  });

  final int proteinG;
  final int carbsG;
  final int fatG;
  final int fibreG;
}

/// Whether total expenditure came from wearable active energy or from the
/// declared activity multiplier.
///
/// Surfaced in the UI — a user should know when a number is measured and when
/// it is a guess.
enum EnergyBasis { measured, estimated }

class NutritionTargets {
  const NutritionTargets({
    required this.calories,
    required this.maintenanceCalories,
    required this.energyBasis,
    required this.macros,
    required this.addedSugarCeilingG,
    required this.waterMl,
    required this.stepTarget,
    required this.sleepTargetMinutes,
    this.isCheatDay = false,
  });

  final int calories;

  /// What the user would eat to hold weight, before the goal offset.
  final int maintenanceCalories;

  final EnergyBasis energyBasis;
  final MacroTargets macros;
  final int addedSugarCeilingG;
  final int waterMl;
  final int stepTarget;
  final int sleepTargetMinutes;
  final bool isCheatDay;
}
