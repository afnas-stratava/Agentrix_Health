import '../../../core/util/iso_day.dart';
import '../nutrition/food_definition.dart';
import '../nutrition/nutrition_targets.dart';

/// Ported from the `DailyBrief` half of `src/features/brief/compose.ts`.

enum WorkoutIntensity {
  rest,
  easy,
  moderate,
  hard;

  /// Ranks intensity so the several inputs that cap it can be combined by a
  /// `min` — sleep and cycle phase may lower the ceiling, never raise it.
  int get rank => index;

  WorkoutIntensity cappedAt(WorkoutIntensity ceiling) =>
      rank <= ceiling.rank ? this : ceiling;

  String get title => switch (this) {
    WorkoutIntensity.rest => 'Rest or a walk',
    WorkoutIntensity.easy => 'Easy aerobic, 30–40 min',
    WorkoutIntensity.moderate => 'Moderate session, 45 min',
    WorkoutIntensity.hard => 'Hard session — take it',
  };

  String get detail => switch (this) {
    WorkoutIntensity.rest =>
      'Nothing that raises your heart rate for long. A 20–30 minute walk is '
          'ideal.',
    WorkoutIntensity.easy =>
      'Zone 2 — you should be able to hold a conversation the whole way '
          'through.',
    WorkoutIntensity.moderate =>
      'A normal training day: strength work at your usual loads, or a steady '
          'run.',
    WorkoutIntensity.hard =>
      'Intervals or a heavy strength day. Your markers say you can absorb it.',
  };
}

enum BriefTargetId { calories, protein, water, steps, sleep }

class BriefTarget {
  const BriefTarget({
    required this.id,
    required this.label,
    required this.value,
    required this.basis,
  });

  final BriefTargetId id;
  final String label;
  final String value;

  /// Short justification — a target with no reason behind it gets ignored.
  final String basis;
}

enum BriefDriverKind {
  recovery,
  sleep,
  cycle,
  labs,
  nutrition;

  String get label => switch (this) {
    BriefDriverKind.recovery => 'Recovery',
    BriefDriverKind.sleep => 'Sleep',
    BriefDriverKind.cycle => 'Cycle',
    BriefDriverKind.labs => 'Blood work',
    BriefDriverKind.nutrition => 'Nutrition',
  };
}

/// A signal that measurably shaped today's plan, listed for transparency.
class BriefDriver {
  const BriefDriver({
    required this.id,
    required this.kind,
    required this.label,
    required this.detail,
  });

  final String id;
  final BriefDriverKind kind;
  final String label;
  final String detail;
}

class FoodFocusExample {
  const FoodFocusExample({
    required this.id,
    required this.name,
    required this.portionLabel,
  });

  final String id;
  final String name;
  final String portionLabel;
}

class FoodFocus {
  const FoodFocus({
    required this.title,
    required this.detail,
    required this.tags,
    required this.examples,
  });

  final String title;
  final String detail;
  final List<FoodTag> tags;

  /// Concrete, diet-compatible examples from the food table.
  final List<FoodFocusExample> examples;
}

class WorkoutPlan {
  const WorkoutPlan({required this.intensity});

  final WorkoutIntensity intensity;

  String get title => intensity.title;
  String get detail => intensity.detail;
}

class DailyBrief {
  const DailyBrief({
    required this.day,
    required this.generatedAt,
    required this.headline,
    required this.narrative,
    required this.targets,
    required this.workout,
    required this.foodFocus,
    required this.drivers,
    required this.caveats,
    required this.raw,
  });

  final IsoDay day;
  final DateTime generatedAt;

  /// One line, the thing to read if nothing else.
  final String headline;

  /// Two to four composed sentences explaining the day.
  final List<String> narrative;

  final List<BriefTarget> targets;
  final WorkoutPlan workout;
  final FoodFocus foodFocus;
  final List<BriefDriver> drivers;

  /// Honest limits on what the brief could see.
  final List<String> caveats;

  /// Underlying numeric targets, for the progress rings.
  final NutritionTargets raw;
}
