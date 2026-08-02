import '../../core/util/iso_day.dart';
import '../../domain/entities/brief/daily_brief.dart';
import '../../domain/entities/health/daily_snapshot.dart';
import '../../domain/entities/insights/readiness.dart';
import '../../domain/entities/labs/biomarker.dart';
import '../../domain/entities/labs/lab_report.dart';
import '../../domain/entities/nutrition/food_definition.dart';
import '../../domain/entities/nutrition/nutrition_targets.dart';
import '../../domain/entities/user_profile.dart';
import '../cycle/menstrual_phase.dart';
import '../nutrition/food_database.dart';
import '../nutrition/patterns.dart';

/// The morning brief. Ported from `src/features/brief/compose.ts`.
///
/// One composed plan for the day, assembled from four inputs that no single
/// existing app holds together: circulating biochemistry (blood work), last
/// night's recovery (wearable), where the user is in their cycle, and what they
/// have actually been eating this week.
///
/// Every sentence below is *composed*, not generated — the same inputs always
/// produce the same brief, it works with the network off, and there is no way
/// for it to invent a biomarker the user does not have. The cost of that choice
/// is that the prose is assembled from clauses rather than written fresh; the
/// benefit is that it can be audited line by line, which for anything touching
/// blood results is the right trade.
///
/// Nothing here diagnoses. The strongest thing a brief will ever say is "this is
/// worth taking to a clinician".
class ComposeInput {
  const ComposeInput({
    required this.day,
    required this.now,
    required this.profile,
    required this.targets,
    required this.readiness,
    required this.nutrition,
    this.report,
    this.phase,
    this.lastNight,
    this.hasTelemetry = true,
  });

  final IsoDay day;
  final DateTime now;
  final UserProfile profile;
  final NutritionTargets targets;
  final Readiness? readiness;
  final WeeklyNutritionSummary nutrition;

  /// Most recent blood work on file, or null when none has been uploaded.
  final LabReport? report;

  final MenstrualPhase? phase;

  /// Most recent day of telemetry — "last night" for sleep purposes.
  final DailySnapshot? lastNight;

  final bool hasTelemetry;
}

({WorkoutIntensity intensity, List<BriefDriver> drivers}) _decideWorkout(
  ComposeInput input,
) {
  final drivers = <BriefDriver>[];

  // Start from recovery. With no readiness score, assume a normal day rather
  // than prescribing either rest or hard work on no evidence.
  var intensity = WorkoutIntensity.moderate;

  final readiness = input.readiness;
  if (readiness != null) {
    intensity = switch (readiness.band) {
      ReadinessBand.compromised => WorkoutIntensity.rest,
      ReadinessBand.low => WorkoutIntensity.easy,
      ReadinessBand.moderate => WorkoutIntensity.moderate,
      ReadinessBand.primed => WorkoutIntensity.hard,
    };
    final copy = readinessCopy[readiness.band]!;
    drivers.add(
      BriefDriver(
        id: 'readiness',
        kind: BriefDriverKind.recovery,
        label: 'Readiness ${readiness.score} — ${copy.label.toLowerCase()}',
        detail: copy.blurb,
      ),
    );
  }

  // Last night's sleep can only lower the ceiling, never raise it: one good
  // night does not undo a suppressed HRV.
  final asleep = input.lastNight?.sleep?.asleepMinutes;
  if (asleep != null) {
    if (asleep < 330) {
      intensity = intensity.cappedAt(WorkoutIntensity.easy);
      drivers.add(
        BriefDriver(
          id: 'sleep-short',
          kind: BriefDriverKind.sleep,
          label: '${formatDuration(asleep / 60)} of sleep last night',
          detail:
              'Under five and a half hours. Intensity today will cost more '
              'than it returns.',
        ),
      );
    } else if (asleep < 390) {
      intensity = intensity.cappedAt(WorkoutIntensity.moderate);
      drivers.add(
        BriefDriver(
          id: 'sleep-light',
          kind: BriefDriverKind.sleep,
          label: '${formatDuration(asleep / 60)} of sleep last night',
          detail:
              'A little short of your target — fine for steady work, not for a '
              'personal best.',
        ),
      );
    } else {
      drivers.add(
        BriefDriver(
          id: 'sleep-good',
          kind: BriefDriverKind.sleep,
          label: '${formatDuration(asleep / 60)} of sleep last night',
          detail:
              'A solid night. This is the single biggest input into today going '
              'well.',
        ),
      );
    }
  }

  // Cycle phase adjusts, and its guidance is a cap in the luteal and menstrual
  // phases rather than a licence to push in the follicular one.
  final phase = input.phase;
  if (phase != null) {
    final guidance = phaseGuidance[phase.name]!;
    if (guidance.trainingBias == TrainingBias.ease) {
      intensity = intensity.cappedAt(WorkoutIntensity.easy);
    }
    if (guidance.trainingBias == TrainingBias.maintain) {
      intensity = intensity.cappedAt(WorkoutIntensity.moderate);
    }

    drivers.add(
      BriefDriver(
        id: 'cycle',
        kind: BriefDriverKind.cycle,
        label: '${phase.label}, day ${phase.dayOfCycle}',
        detail: guidance.training,
      ),
    );
  }

  // A value outside the conventional lab interval outranks everything else on
  // this screen.
  final outOfRange = input.report?.biomarkers
      .where((b) => b.flag.isOutOfRange)
      .toList();
  if (outOfRange != null && outOfRange.isNotEmpty) {
    intensity = intensity.cappedAt(WorkoutIntensity.easy);
    final worst = outOfRange.reduce(
      (a, b) => b.flag.severity > a.flag.severity ? b : a,
    );
    drivers.add(
      BriefDriver(
        id: 'labs-out-of-range',
        kind: BriefDriverKind.labs,
        label:
            '${worst.displayName} ${worst.valueWithUnit} — '
            '${worst.flag.label.toLowerCase()}',
        detail:
            'Outside the lab’s own reference interval, so it is worth a '
            'clinician’s eyes. Keep training easy until you have had that '
            'conversation.',
      ),
    );
  }

  return (intensity: intensity, drivers: drivers);
}

/// What the user should actually eat today, in priority order: a flagged
/// biomarker beats a weekly pattern, which beats cycle phase, which beats the
/// standing goal.
({FoodFocus focus, List<BriefDriver> drivers}) _decideFoodFocus(
  ComposeInput input,
) {
  final drivers = <BriefDriver>[];
  var title = 'Eat for your goal';
  var detail = input.profile.goal.hint;
  var tags = <FoodTag>[FoodTag.highProtein, FoodTag.highFibre];

  // --- 1. Blood work ---------------------------------------------------------
  final flagged = input.report?.flagged ?? const <Biomarker>[];

  Biomarker? find(List<BiomarkerCode> codes) {
    for (final biomarker in flagged) {
      if (biomarker.code != null && codes.contains(biomarker.code)) {
        return biomarker;
      }
    }
    return null;
  }

  final iron = find([BiomarkerCode.ferritin, BiomarkerCode.hemoglobin]);
  final glucose = find([
    BiomarkerCode.hba1c,
    BiomarkerCode.fastingGlucose,
    BiomarkerCode.fastingInsulin,
  ]);
  final lipids = find([
    BiomarkerCode.ldl,
    BiomarkerCode.triglycerides,
    BiomarkerCode.totalCholesterol,
  ]);
  final vitaminD = find([BiomarkerCode.vitaminD]);
  final b12 = find([BiomarkerCode.vitaminB12]);

  if (iron != null) {
    title = 'Iron, with vitamin C alongside it';
    detail =
        'Your ${iron.displayName.toLowerCase()} came back at '
        '${iron.valueWithUnit}. Pair an iron source with something high in '
        'vitamin C in the same meal, and keep tea or coffee an hour clear of '
        'it — that alone can double how much you absorb.';
    tags = [FoodTag.ironRich, FoodTag.vitaminCRich, FoodTag.leafyGreen];
    drivers.add(
      BriefDriver(
        id: 'labs-iron',
        kind: BriefDriverKind.labs,
        label: '${iron.displayName} ${iron.valueWithUnit}',
        detail:
            'Iron status is the limiter on oxygen transport, and it shows up in '
            'HRV before it shows up in how you feel.',
      ),
    );
  } else if (glucose != null) {
    title = 'Protein and fibre first, starch second';
    detail =
        'Your ${glucose.displayName.toLowerCase()} is '
        '${glucose.valueWithUnit}. Eating the protein and vegetables on the '
        'plate before the rice or bread measurably flattens the glucose '
        'response to the same meal.';
    tags = [FoodTag.highProtein, FoodTag.highFibre, FoodTag.lowCarb];
    drivers.add(
      BriefDriver(
        id: 'labs-glucose',
        kind: BriefDriverKind.labs,
        label: '${glucose.displayName} ${glucose.valueWithUnit}',
        detail:
            'Meal order and fibre do more for post-meal glucose than cutting '
            'total carbohydrate does.',
      ),
    );
  } else if (lipids != null) {
    title = 'Soluble fibre and unsaturated fat';
    detail =
        'Your ${lipids.displayName.toLowerCase()} is ${lipids.valueWithUnit}. '
        'Oats, beans, lentils and nuts move this; swapping fried food for grilled '
        'moves it faster.';
    tags = [FoodTag.highFibre, FoodTag.wholegrain, FoodTag.omega3Rich];
    drivers.add(
      BriefDriver(
        id: 'labs-lipids',
        kind: BriefDriverKind.labs,
        label: '${lipids.displayName} ${lipids.valueWithUnit}',
        detail:
            'Soluble fibre binds bile acids, which is the mechanism behind most '
            'diet-driven LDL reduction.',
      ),
    );
  } else if (b12 != null || vitaminD != null) {
    final marker = b12 ?? vitaminD!;
    title = b12 != null ? 'B12-dense food today' : 'Get outside, and eat oily fish';
    detail = b12 != null
        ? 'Your B12 is ${marker.valueWithUnit}. Dairy, eggs and fortified '
              'foods help, but a plant-based diet almost always needs a '
              'supplement to fix this properly.'
        : 'Your vitamin D is ${marker.valueWithUnit}. Sunlight does most of '
              'the work here; oily fish and fortified dairy do the rest.';
    tags = b12 != null
        ? [FoodTag.highProtein, FoodTag.calciumRich]
        : [FoodTag.omega3Rich, FoodTag.calciumRich];
    drivers.add(
      BriefDriver(
        id: 'labs-vitamin',
        kind: BriefDriverKind.labs,
        label: '${marker.displayName} ${marker.valueWithUnit}',
        detail:
            'Both of these track with fatigue and low mood long before they '
            'reach a clinical deficiency.',
      ),
    );
  } else {
    // --- 2. Weekly pattern ---------------------------------------------------
    final pattern = input.nutrition.headline;
    if (pattern != null && pattern.tone == PatternTone.concern) {
      switch (pattern.id) {
        case 'protein-short':
          title = 'Get protein into every meal';
          tags = [FoodTag.highProtein];
        case 'sugar-over':
          title = 'Keep added sugar off the plate today';
          tags = [FoodTag.highFibre, FoodTag.highProtein];
        case 'fibre-short':
          title = 'Fibre at every meal';
          tags = [FoodTag.highFibre, FoodTag.wholegrain];
        case 'sodium-high':
          title = 'Cook at home today if you can';
          tags = [FoodTag.highFibre, FoodTag.highProtein];
        default:
          title = 'Steady, home-cooked day';
          tags = [FoodTag.highProtein, FoodTag.highFibre];
      }
      detail = pattern.detail;
      drivers.add(
        BriefDriver(
          id: 'nutrition-${pattern.id}',
          kind: BriefDriverKind.nutrition,
          label: pattern.title,
          detail: pattern.detail,
        ),
      );
    } else if (input.phase != null) {
      // --- 3. Cycle phase ----------------------------------------------------
      final guidance = phaseGuidance[input.phase!.name]!;
      title = 'Eat for your ${input.phase!.name.name} phase';
      detail = guidance.nutrition;
      tags = [...guidance.favourTags];
    }
  }

  // Merge in the phase's preferred tags even when the headline came from labs —
  // the two rarely conflict and the ranking benefits from both.
  if (input.phase != null) {
    for (final tag in phaseGuidance[input.phase!.name]!.favourTags) {
      if (!tags.contains(tag)) tags.add(tag);
    }
  }

  final dietPattern = input.profile.effectiveDietPattern;
  final allergens = input.profile.allergies;
  final cuisineRank = input.profile.rankedCuisines;

  final candidates =
      foodDatabase
          .where(
            (item) =>
                item.tags.any(tags.contains) &&
                dietaryConflict(
                      item,
                      dietPattern: dietPattern,
                      allergens: allergens,
                    ) ==
                    null,
          )
          .toList()
        // Prefer the user's own cuisines, so "iron-rich" surfaces a turkey
        // chili or pot roast rather than a spinach salad they will never eat.
        ..sort((a, b) {
          int rank(FoodDefinition item) {
            if (item.cuisine == null) return 99;
            final index = cuisineRank.indexOf(item.cuisine!);
            return index >= 0 ? index : 98;
          }

          return rank(a).compareTo(rank(b));
        });

  final examples = candidates
      .take(4)
      .map(
        (item) => FoodFocusExample(
          id: item.id,
          name: item.name,
          portionLabel: item.portionLabel,
        ),
      )
      .toList();

  return (
    focus: FoodFocus(
      title: title,
      detail: detail,
      tags: tags.take(4).toList(),
      examples: examples,
    ),
    drivers: drivers,
  );
}

List<BriefTarget> _buildTargets(ComposeInput input) {
  final targets = input.targets;

  return [
    BriefTarget(
      id: BriefTargetId.calories,
      label: 'Calories',
      value: '${targets.calories}',
      basis: targets.energyBasis == EnergyBasis.measured
          ? 'From your measured burn this week'
          : 'Estimated from your '
                '${input.profile.activityLevel.label.toLowerCase()} level',
    ),
    BriefTarget(
      id: BriefTargetId.protein,
      label: 'Protein',
      value: '${targets.macros.proteinG} g',
      basis: input.profile.goal.calorieOffset < 0
          ? 'Held high to protect lean mass in a deficit'
          : 'Set per kilo of bodyweight for your goal',
    ),
    BriefTarget(
      id: BriefTargetId.water,
      label: 'Water',
      value: '${(targets.waterMl / 1000).toStringAsFixed(1)} L',
      basis: 'Baseline plus replacement for yesterday’s activity',
    ),
    BriefTarget(
      id: BriefTargetId.steps,
      label: 'Steps',
      value: _thousands(targets.stepTarget),
      basis: 'A nudge above your own two-week average',
    ),
    BriefTarget(
      id: BriefTargetId.sleep,
      label: 'Sleep',
      value: formatDuration(targets.sleepTargetMinutes / 60),
      basis: targets.sleepTargetMinutes > 480
          ? 'Extended to repay this week’s debt'
          : 'Standard adult target',
    ),
  ];
}

String _thousands(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i += 1) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

({String headline, List<String> narrative}) _buildNarrative(
  ComposeInput input,
  FoodFocus focus,
) {
  final sentences = <String>[];

  // Sentence 1 — where the body is this morning.
  final String headline;
  final readiness = input.readiness;
  if (readiness != null) {
    final copy = readinessCopy[readiness.band]!;
    headline = switch (readiness.band) {
      ReadinessBand.primed => 'Your body is ready for a hard day.',
      ReadinessBand.moderate => 'A normal day — train as planned.',
      ReadinessBand.low => 'Recovery is down. Keep today light.',
      ReadinessBand.compromised => 'Your markers say rest today.',
    };
    sentences.add(
      'Readiness is ${readiness.score} out of 100. ${copy.blurb}',
    );
  } else {
    headline = 'Building your baseline.';
    sentences.add(
      'There is not yet enough wearable history to score your recovery — a '
      'week of consistent wear unlocks it.',
    );
  }

  // Sentence 2 — last night, specifically.
  final sleep = input.lastNight?.sleep;
  if (sleep != null) {
    final efficiency = sleep.efficiency;
    final efficiencyClause = efficiency == null
        ? ''
        : ' at ${(efficiency * 100).round()}% efficiency';
    sentences.add(
      'You slept ${formatDuration(sleep.asleepMinutes / 60)}$efficiencyClause, '
      'with ${sleep.deepMinutes.round()} minutes of deep and '
      '${sleep.remMinutes.round()} of REM.',
    );
  }

  // Sentence 3 — the cycle, when tracked.
  final phase = input.phase;
  if (phase != null) {
    sentences.add(phase.summary);
    final expected = phaseGuidance[phase.name]!.expectedTelemetryNote;
    if (expected != null && readiness != null && readiness.score < 50) {
      sentences.add(expected);
    }
  }

  // Sentence 4 — the week's eating, and today's focus.
  final pattern = input.nutrition.headline;
  if (input.nutrition.isSparse) {
    sentences.add(
      'Log a few meals and this brief starts folding your eating patterns into '
      'the plan as well.',
    );
  } else if (pattern != null) {
    sentences.add('${pattern.title}. ${focus.title.toLowerCase()} today.');
  }

  return (headline: headline, narrative: sentences);
}

List<String> _buildCaveats(ComposeInput input) {
  final caveats = <String>[];

  if (!input.hasTelemetry) {
    caveats.add(
      'No wearable data yet — targets are estimated from your profile alone.',
    );
  } else if (input.readiness == null) {
    caveats.add(
      'Readiness needs seven days of baseline before it can be scored.',
    );
  }

  if (input.report == null) {
    caveats.add(
      'No blood work on file, so nothing here is informed by your biochemistry '
      'yet.',
    );
  }

  if (input.nutrition.isSparse) {
    final days = input.nutrition.loggedDays;
    caveats.add(
      'Only $days ${days == 1 ? 'day' : 'days'} of food logged this week.',
    );
  }

  if (input.phase?.confidence == PhaseConfidence.low) {
    caveats.add(
      'Cycle phase is a low-confidence estimate — log your next period start to '
      'sharpen it.',
    );
  }

  if (!input.profile.canComputeTargets) {
    caveats.add(
      'Height and weight are assumed population defaults — add yours in Profile '
      'and every target below sharpens.',
    );
  }

  if (input.targets.isCheatDay) {
    caveats.add(
      'Cheat day is on: calories are 15% higher and the sugar ceiling is '
      'relaxed.',
    );
  }

  return caveats;
}

DailyBrief composeBrief(ComposeInput input) {
  final workout = _decideWorkout(input);
  final food = _decideFoodFocus(input);
  final narrative = _buildNarrative(input, food.focus);

  return DailyBrief(
    day: input.day,
    generatedAt: input.now,
    headline: narrative.headline,
    narrative: narrative.narrative,
    targets: _buildTargets(input),
    workout: WorkoutPlan(intensity: workout.intensity),
    foodFocus: food.focus,
    // Recovery and sleep first — they are what changed since yesterday.
    drivers: [...workout.drivers, ...food.drivers],
    caveats: _buildCaveats(input),
    raw: input.targets,
  );
}
