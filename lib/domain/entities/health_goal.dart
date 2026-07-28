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
}
