/// Ported from `DietPatternSchema` in `src/schemas/profile.ts`.
///
/// A hard constraint on what can be recommended. Unlike a preference,
/// violating one of these is a bug — the dish ranker filters on it rather than
/// scoring it.
enum DietPattern {
  omnivore('omnivore', 'No restrictions', 'Everything is on the table'),
  vegetarian('vegetarian', 'Vegetarian', 'No meat or fish; dairy is fine'),
  eggetarian('eggetarian', 'Eggetarian', 'Vegetarian plus eggs'),
  vegan('vegan', 'Vegan', 'No animal products at all'),
  pescatarian('pescatarian', 'Pescatarian', 'Fish and seafood, no other meat'),
  halal('halal', 'Halal', 'Halal meat only, no pork or alcohol'),
  jain('jain', 'Jain', 'No meat, eggs, root vegetables, onion or garlic');

  const DietPattern(this.wireName, this.label, this.hint);

  final String wireName;
  final String label;
  final String hint;

  static DietPattern? fromWireName(String value) {
    for (final pattern in DietPattern.values) {
      if (pattern.wireName == value) return pattern;
    }
    return null;
  }
}

/// Ported from `RestrictionSchema`. Softer than an allergy — down-ranks a dish
/// rather than excluding it.
enum Restriction {
  lowSodium('low-sodium', 'Low sodium'),
  lowCarb('low-carb', 'Low carb'),
  noAddedSugar('no-added-sugar', 'No added sugar'),
  lowFodmap('low-fodmap', 'Low FODMAP'),
  noAlcohol('no-alcohol', 'No alcohol'),
  noFried('no-fried', 'Nothing deep-fried');

  const Restriction(this.wireName, this.label);

  final String wireName;
  final String label;

  static Restriction? fromWireName(String value) {
    for (final restriction in Restriction.values) {
      if (restriction.wireName == value) return restriction;
    }
    return null;
  }
}

/// Ported from `ConditionSchema`. Shapes calorie, carbohydrate and added-sugar
/// targets, and is why "manage a condition" is a real goal rather than a label.
enum Condition {
  prediabetes('prediabetes', 'Prediabetes'),
  type2Diabetes('type2-diabetes', 'Type 2 diabetes'),
  hypertension('hypertension', 'High blood pressure'),
  highCholesterol('high-cholesterol', 'High cholesterol'),
  pcos('pcos', 'PCOS'),
  hypothyroidism('hypothyroidism', 'Hypothyroidism'),
  anaemia('anaemia', 'Anaemia'),
  fattyLiver('fatty-liver', 'Fatty liver');

  const Condition(this.wireName, this.label);

  final String wireName;
  final String label;

  static Condition? fromWireName(String value) {
    for (final condition in Condition.values) {
      if (condition.wireName == value) return condition;
    }
    return null;
  }
}

/// Ported from `ActivityLevelSchema` + `ACTIVITY_META`.
///
/// Physical-activity multipliers applied to basal metabolic rate. These are the
/// conventional Mifflin/Harris–Benedict factors; the targets calculator prefers
/// measured active energy from HealthKit when a wearable is attached and only
/// falls back to these when it is not.
enum ActivityLevel {
  sedentary(
    'sedentary',
    'Sedentary',
    'Desk job, little deliberate exercise',
    1.2,
  ),
  light(
    'light',
    'Lightly active',
    'Walks most days, 1–2 workouts a week',
    1.375,
  ),
  moderate('moderate', 'Moderately active', '3–4 workouts a week', 1.55),
  active('active', 'Active', '5–6 workouts a week', 1.725),
  veryActive(
    'very-active',
    'Very active',
    'Daily training or a physical job',
    1.9,
  );

  const ActivityLevel(this.wireName, this.label, this.hint, this.multiplier);

  final String wireName;
  final String label;
  final String hint;
  final double multiplier;

  static ActivityLevel? fromWireName(String value) {
    for (final level in ActivityLevel.values) {
      if (level.wireName == value) return level;
    }
    return null;
  }
}
