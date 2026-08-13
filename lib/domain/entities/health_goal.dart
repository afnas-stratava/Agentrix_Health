/// Ported from `HealthGoalSchema` + `HEALTH_GOAL_META` in
/// `src/schemas/profile.ts`.
enum HealthGoal {
  loseWeight,
  buildMuscle,
  manageCondition,
  generalWellness;

  String get label => switch (this) {
    HealthGoal.loseWeight => 'Lose weight',
    HealthGoal.buildMuscle => 'Build muscle',
    HealthGoal.manageCondition => 'Manage a condition',
    HealthGoal.generalWellness => 'General wellness',
  };

  String get hint => switch (this) {
    HealthGoal.loseWeight => 'A moderate deficit — about 1 lb a week',
    HealthGoal.buildMuscle => 'A small surplus with a high protein floor',
    HealthGoal.manageCondition => 'Targets shaped around the conditions you log',
    HealthGoal.generalWellness => 'Maintain weight, optimise sleep and energy',
  };

  /// Kilocalories added to maintenance to serve this goal.
  ///
  /// −500 is the largest deficit that reliably preserves lean mass without
  /// wrecking recovery, which is the metric this app watches.
  int get calorieOffset => switch (this) {
    HealthGoal.loseWeight => -500,
    HealthGoal.buildMuscle => 250,
    HealthGoal.manageCondition => 0,
    HealthGoal.generalWellness => 0,
  };

  /// Protein floor in g/kg of bodyweight.
  ///
  /// The RDA (0.8 g/kg) is a deficiency-prevention floor, not an optimum.
  /// These are the figures used in the resistance-training and sarcopenia
  /// literature. In a deficit protein goes *up*, because it is what protects
  /// lean mass while total energy comes down.
  double get proteinPerKg => switch (this) {
    HealthGoal.buildMuscle => 1.8,
    HealthGoal.loseWeight => 1.6,
    HealthGoal.manageCondition => 1.2,
    HealthGoal.generalWellness => 1.2,
  };
}
