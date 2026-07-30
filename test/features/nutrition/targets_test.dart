import 'package:agentrix_health/core/util/iso_day.dart';
import 'package:agentrix_health/domain/entities/gender.dart';
import 'package:agentrix_health/domain/entities/health/daily_snapshot.dart';
import 'package:agentrix_health/domain/entities/health_goal.dart';
import 'package:agentrix_health/domain/entities/nutrition/nutrition_targets.dart';
import 'package:agentrix_health/domain/entities/profile/diet_pattern.dart';
import 'package:agentrix_health/domain/entities/user_profile.dart';
import 'package:agentrix_health/features/cycle/menstrual_phase.dart';
import 'package:agentrix_health/features/nutrition/targets.dart';
import 'package:flutter_test/flutter_test.dart';

UserProfile _profile({
  Gender gender = Gender.male,
  double? heightCm = 178,
  double? weightKg = 78,
  String age = '34',
  HealthGoal goal = HealthGoal.generalWellness,
  ActivityLevel activity = ActivityLevel.moderate,
  Set<Restriction> restrictions = const {},
  Set<Condition> conditions = const {},
}) {
  return UserProfile.initial().copyWith(
    gender: gender,
    heightCm: heightCm,
    weightKg: weightKg,
    age: age,
    goal: goal,
    activityLevel: activity,
    restrictions: restrictions,
    conditions: conditions,
  );
}

/// `days` snapshots ending today, each carrying the same active energy.
List<DailySnapshot> _series({
  required int days,
  double? activeEnergy,
  double? steps,
  double? asleepMinutes,
}) {
  final today = DateTime(2026, 7, 30, 9);
  return [
    for (var i = days - 1; i >= 0; i -= 1)
      DailySnapshot(
        day: toIsoDay(addDays(today, -i)),
        activeEnergy: activeEnergy,
        steps: steps,
        sleep: asleepMinutes == null
            ? null
            : SleepSummary(
                asleepMinutes: asleepMinutes,
                inBedMinutes: asleepMinutes + 30,
                deepMinutes: 70,
                remMinutes: 90,
                coreMinutes: asleepMinutes - 160,
                awakeMinutes: 20,
                unspecifiedMinutes: 0,
                efficiency: asleepMinutes / (asleepMinutes + 30),
                bedtime: null,
                wakeTime: null,
              ),
      ),
  ];
}

void main() {
  group('basalMetabolicRate', () {
    test('applies the Mifflin–St Jeor sex constant', () {
      // 10*78 + 6.25*178 - 5*34 = 780 + 1112.5 - 170 = 1722.5
      expect(basalMetabolicRate(_profile()), closeTo(1722.5 + 5, 0.01));
      expect(
        basalMetabolicRate(_profile(gender: Gender.female)),
        closeTo(1722.5 - 161, 0.01),
      );
    });

    test('is null when the profile is incomplete', () {
      expect(basalMetabolicRate(_profile(weightKg: null)), isNull);
      expect(basalMetabolicRate(_profile(heightCm: null)), isNull);
      expect(basalMetabolicRate(_profile(age: '')), isNull);
    });
  });

  group('computeTargets', () {
    test('returns null rather than guessing a bodyweight', () {
      expect(
        computeTargets(profile: _profile(weightKg: null), series: const []),
        isNull,
      );
    });

    test('estimates from the activity multiplier with no telemetry', () {
      final targets = computeTargets(profile: _profile(), series: const [])!;

      expect(targets.energyBasis, EnergyBasis.estimated);
      expect(
        targets.maintenanceCalories,
        (basalMetabolicRate(_profile())! * ActivityLevel.moderate.multiplier)
            .round(),
      );
    });

    test('prefers measured active energy once four days exist', () {
      final targets = computeTargets(
        profile: _profile(),
        series: _series(days: 7, activeEnergy: 600),
      )!;

      expect(targets.energyBasis, EnergyBasis.measured);
      // Resting (BMR + 10% TEF) plus what the watch actually saw.
      expect(
        targets.maintenanceCalories,
        (basalMetabolicRate(_profile())! * 1.1 + 600).round(),
      );
    });

    test('falls back to estimation when telemetry is too sparse', () {
      final targets = computeTargets(
        profile: _profile(),
        series: _series(days: 3, activeEnergy: 600),
      )!;

      expect(targets.energyBasis, EnergyBasis.estimated);
    });

    test('scales protein per kilo of bodyweight for the goal', () {
      final cut = computeTargets(
        profile: _profile(goal: HealthGoal.loseWeight),
        series: const [],
      )!;

      expect(
        cut.macros.proteinG,
        (HealthGoal.loseWeight.proteinPerKg * 78).round(),
      );
      // A deficit must not also cut protein — that is what costs lean mass.
      expect(cut.macros.proteinG, greaterThan(78));
    });

    test('lifts calories 5% in the luteal phase', () {
      final follicular = computeTargets(
        profile: _profile(gender: Gender.female),
        series: const [],
        phase: _phase(MenstrualPhaseName.follicular),
      )!;
      final luteal = computeTargets(
        profile: _profile(gender: Gender.female),
        series: const [],
        phase: _phase(MenstrualPhaseName.luteal),
      )!;

      expect(luteal.calories, (follicular.calories * 1.05).round());
    });

    test('never prescribes below the micronutrient-adequacy floor', () {
      final targets = computeTargets(
        // A small, sedentary profile on an aggressive deficit would otherwise
        // compute under 1,200 kcal.
        profile: _profile(
          gender: Gender.female,
          heightCm: 150,
          weightKg: 45,
          age: '62',
          goal: HealthGoal.loseWeight,
          activity: ActivityLevel.sedentary,
        ),
        series: const [],
      )!;

      expect(targets.calories, greaterThanOrEqualTo(1200));
    });

    test('caps carbohydrate share for a diabetic profile', () {
      final standard = computeTargets(profile: _profile(), series: const [])!;
      final diabetic = computeTargets(
        profile: _profile(conditions: {Condition.type2Diabetes}),
        series: const [],
      )!;

      expect(diabetic.macros.carbsG, lessThan(standard.macros.carbsG));
    });

    test('tightens the sugar ceiling for a metabolic condition', () {
      final standard = computeTargets(profile: _profile(), series: const [])!;
      final fattyLiver = computeTargets(
        profile: _profile(conditions: {Condition.fattyLiver}),
        series: const [],
      )!;

      expect(
        fattyLiver.addedSugarCeilingG,
        (standard.addedSugarCeilingG * 0.6).round(),
      );
    });

    test('applies the stricter of the WHO and AHA sugar caps', () {
      final targets = computeTargets(profile: _profile(), series: const [])!;
      final fivePercent = (targets.calories * 0.05 / 4).round();

      expect(targets.addedSugarCeilingG, lessThanOrEqualTo(36));
      expect(targets.addedSugarCeilingG, lessThanOrEqualTo(fivePercent));
    });

    test('nudges steps from the user’s own baseline, not a round 10,000', () {
      final targets = computeTargets(
        profile: _profile(),
        series: _series(days: 14, steps: 4000),
      )!;

      expect(targets.stepTarget, greaterThan(4000));
      expect(targets.stepTarget, lessThan(5000));
    });

    test('caps the step target so a heavy week cannot demand the impossible', () {
      final targets = computeTargets(
        profile: _profile(),
        series: _series(days: 14, steps: 30000),
      )!;

      expect(targets.stepTarget, 14000);
    });

    test('extends the sleep target after a week of debt', () {
      final rested = computeTargets(
        profile: _profile(),
        series: _series(days: 7, asleepMinutes: 480),
      )!;
      final short = computeTargets(
        profile: _profile(),
        series: _series(days: 7, asleepMinutes: 360),
      )!;

      expect(rested.sleepTargetMinutes, 480);
      expect(short.sleepTargetMinutes, greaterThan(480));
      // Above nine hours a "target" stops being one.
      expect(short.sleepTargetMinutes, lessThanOrEqualTo(540));
    });

    test('adds hydration for measured activity', () {
      final still = computeTargets(
        profile: _profile(),
        series: _series(days: 7, activeEnergy: 0),
      )!;
      final active = computeTargets(
        profile: _profile(),
        series: _series(days: 7, activeEnergy: 800),
      )!;

      expect(active.waterMl, greaterThan(still.waterMl));
    });

    test('a cheat day lifts calories 15%', () {
      final normal = computeTargets(profile: _profile(), series: const [])!;
      final cheat = computeTargets(
        profile: _profile(),
        series: const [],
        isCheatDay: true,
      )!;

      expect(cheat.calories, (normal.calories * 1.15).round());
      expect(cheat.isCheatDay, isTrue);
    });
  });

  group('withAssumedBodyComposition', () {
    test('fills only the missing fields', () {
      final partial = _profile(heightCm: 165, weightKg: null);
      final filled = withAssumedBodyComposition(partial);

      expect(filled.heightCm, 165);
      expect(filled.weightKg, isNotNull);
    });

    test('leaves a complete profile untouched', () {
      final complete = _profile();
      expect(withAssumedBodyComposition(complete), same(complete));
    });
  });
}

MenstrualPhase _phase(MenstrualPhaseName name) => MenstrualPhase(
  name: name,
  label: phaseLabel[name]!,
  dayOfCycle: 20,
  cycleLengthDays: 28,
  isMeasuredLength: true,
  daysUntilNextPeriod: 8,
  confidence: PhaseConfidence.high,
  summary: 'test',
);
