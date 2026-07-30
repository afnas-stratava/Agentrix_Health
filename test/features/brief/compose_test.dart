import 'package:agentrix_health/core/util/iso_day.dart';
import 'package:agentrix_health/domain/entities/brief/daily_brief.dart';
import 'package:agentrix_health/domain/entities/gender.dart';
import 'package:agentrix_health/domain/entities/health/daily_snapshot.dart';
import 'package:agentrix_health/domain/entities/insights/readiness.dart';
import 'package:agentrix_health/domain/entities/labs/biomarker.dart';
import 'package:agentrix_health/domain/entities/labs/lab_report.dart';
import 'package:agentrix_health/domain/entities/nutrition/food_definition.dart';
import 'package:agentrix_health/domain/entities/nutrition/nutrition_targets.dart';
import 'package:agentrix_health/domain/entities/profile/diet_pattern.dart';
import 'package:agentrix_health/domain/entities/user_profile.dart';
import 'package:agentrix_health/features/brief/compose.dart';
import 'package:agentrix_health/features/cycle/menstrual_phase.dart';
import 'package:agentrix_health/features/labs/reference_ranges.dart';
import 'package:agentrix_health/features/nutrition/patterns.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 7, 30, 7);

const _targets = NutritionTargets(
  calories: 2200,
  maintenanceCalories: 2200,
  energyBasis: EnergyBasis.estimated,
  macros: MacroTargets(proteinG: 130, carbsG: 250, fatG: 70, fibreG: 31),
  addedSugarCeilingG: 27,
  waterMl: 2700,
  stepTarget: 8000,
  sleepTargetMinutes: 480,
);

WeeklyNutritionSummary _emptyNutrition() => analyseWeek(
  meals: const [],
  hydration: const {},
  targets: _targets,
  now: _now,
);

Readiness _readiness(int score, ReadinessBand band) => Readiness(
  score: score,
  band: band,
  drivers: const [],
  baselineDays: 28,
  computedAt: '2026-07-30T07:00:00',
);

DailySnapshot _lastNight({double asleepMinutes = 450}) => DailySnapshot(
  day: toIsoDay(_now),
  sleep: SleepSummary(
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
);

LabReport _report(List<Biomarker> markers) => LabReport(
  id: 'r1',
  source: LabSource.sample,
  status: ParseStatus.ready,
  collectedAt: addDays(_now, -9),
  uploadedAt: _now,
  biomarkers: markers,
);

Biomarker _marker(BiomarkerCode code, double value, String unit) =>
    enrichBiomarker(
      Biomarker(
        code: code,
        rawName: code.wireName,
        displayName: code.wireName,
        value: value,
        unit: unit,
        range: const ReferenceRange(low: null, high: null),
      ),
      Gender.male,
    );

MenstrualPhase _phase(MenstrualPhaseName name) => MenstrualPhase(
  name: name,
  label: phaseLabel[name]!,
  dayOfCycle: name == MenstrualPhaseName.menstrual ? 2 : 20,
  cycleLengthDays: 28,
  isMeasuredLength: true,
  daysUntilNextPeriod: 8,
  confidence: PhaseConfidence.high,
  summary: 'summary line',
);

DailyBrief _compose({
  UserProfile? profile,
  Readiness? readiness,
  LabReport? report,
  MenstrualPhase? phase,
  DailySnapshot? lastNight,
  WeeklyNutritionSummary? nutrition,
  bool hasTelemetry = true,
  NutritionTargets targets = _targets,
}) => composeBrief(
  ComposeInput(
    day: toIsoDay(_now),
    now: _now,
    profile: profile ?? UserProfile.initial().copyWith(
      heightCm: 178,
      weightKg: 78,
      age: '34',
    ),
    targets: targets,
    readiness: readiness,
    nutrition: nutrition ?? _emptyNutrition(),
    report: report,
    phase: phase,
    lastNight: lastNight,
    hasTelemetry: hasTelemetry,
  ),
);

void main() {
  group('determinism', () {
    test('the same inputs compose the same brief', () {
      final a = _compose(
        readiness: _readiness(72, ReadinessBand.moderate),
        report: _report([_marker(BiomarkerCode.ferritin, 21, 'ng/mL')]),
        lastNight: _lastNight(),
      );
      final b = _compose(
        readiness: _readiness(72, ReadinessBand.moderate),
        report: _report([_marker(BiomarkerCode.ferritin, 21, 'ng/mL')]),
        lastNight: _lastNight(),
      );

      expect(a.headline, b.headline);
      expect(a.narrative, b.narrative);
      expect(a.workout.intensity, b.workout.intensity);
      expect(a.foodFocus.title, b.foodFocus.title);
      expect(
        a.drivers.map((d) => d.id),
        orderedEquals(b.drivers.map((d) => d.id)),
      );
    });
  });

  group('training intensity', () {
    test('follows the readiness band', () {
      expect(
        _compose(readiness: _readiness(88, ReadinessBand.primed))
            .workout
            .intensity,
        WorkoutIntensity.hard,
      );
      expect(
        _compose(readiness: _readiness(30, ReadinessBand.compromised))
            .workout
            .intensity,
        WorkoutIntensity.rest,
      );
    });

    test('assumes a normal day with no readiness score', () {
      // Neither rest nor hard work should be prescribed on no evidence.
      expect(_compose().workout.intensity, WorkoutIntensity.moderate);
    });

    test('a short night caps intensity regardless of readiness', () {
      final brief = _compose(
        readiness: _readiness(90, ReadinessBand.primed),
        lastNight: _lastNight(asleepMinutes: 300),
      );

      expect(brief.workout.intensity, WorkoutIntensity.easy);
      expect(brief.drivers.map((d) => d.id), contains('sleep-short'));
    });

    test('a good night never raises intensity above readiness', () {
      final brief = _compose(
        readiness: _readiness(35, ReadinessBand.compromised),
        lastNight: _lastNight(asleepMinutes: 520),
      );

      expect(brief.workout.intensity, WorkoutIntensity.rest);
    });

    test('the menstrual phase caps intensity', () {
      final brief = _compose(
        readiness: _readiness(90, ReadinessBand.primed),
        phase: _phase(MenstrualPhaseName.menstrual),
      );

      expect(brief.workout.intensity, WorkoutIntensity.easy);
    });

    test('the luteal phase holds it at moderate', () {
      final brief = _compose(
        readiness: _readiness(90, ReadinessBand.primed),
        phase: _phase(MenstrualPhaseName.luteal),
      );

      expect(brief.workout.intensity, WorkoutIntensity.moderate);
    });

    test('the follicular phase does not lift a low readiness', () {
      final brief = _compose(
        readiness: _readiness(40, ReadinessBand.low),
        phase: _phase(MenstrualPhaseName.follicular),
      );

      expect(brief.workout.intensity, WorkoutIntensity.easy);
    });

    test('an out-of-range biomarker outranks a primed score', () {
      final brief = _compose(
        readiness: _readiness(92, ReadinessBand.primed),
        report: _report([
          // Well outside the lab interval, not merely below optimal.
          _marker(BiomarkerCode.hsCrp, 9, 'mg/L'),
        ]),
      );

      expect(brief.workout.intensity, WorkoutIntensity.easy);
      expect(
        brief.drivers.map((d) => d.id),
        contains('labs-out-of-range'),
      );
    });

    test('a merely-suboptimal biomarker does not cap training', () {
      final brief = _compose(
        readiness: _readiness(92, ReadinessBand.primed),
        // Normal on the report, below optimal — worth eating for, not a reason
        // to stop training.
        report: _report([_marker(BiomarkerCode.ferritin, 45, 'ng/mL')]),
      );

      expect(brief.workout.intensity, WorkoutIntensity.hard);
    });
  });

  group('food focus priority', () {
    test('a flagged iron marker wins', () {
      final brief = _compose(
        report: _report([_marker(BiomarkerCode.ferritin, 21, 'ng/mL')]),
      );

      expect(brief.foodFocus.title.toLowerCase(), contains('iron'));
      expect(brief.foodFocus.tags, contains(FoodTag.ironRich));
      expect(brief.foodFocus.tags, contains(FoodTag.vitaminCRich));
      expect(brief.drivers.map((d) => d.id), contains('labs-iron'));
    });

    test('quotes the actual value, never a generic phrase', () {
      final brief = _compose(
        report: _report([_marker(BiomarkerCode.ferritin, 21, 'ng/mL')]),
      );

      expect(brief.foodFocus.detail, contains('21 ng/mL'));
    });

    test('glucose beats a weekly pattern', () {
      final brief = _compose(
        report: _report([_marker(BiomarkerCode.hba1c, 6.0, '%')]),
      );

      expect(brief.foodFocus.tags, contains(FoodTag.lowCarb));
      expect(brief.drivers.map((d) => d.id), contains('labs-glucose'));
    });

    test('iron beats glucose when both are flagged', () {
      final brief = _compose(
        report: _report([
          _marker(BiomarkerCode.hba1c, 6.0, '%'),
          _marker(BiomarkerCode.ferritin, 21, 'ng/mL'),
        ]),
      );

      expect(brief.foodFocus.title.toLowerCase(), contains('iron'));
    });

    test('falls through to the cycle phase with no labs or patterns', () {
      final brief = _compose(phase: _phase(MenstrualPhaseName.luteal));

      expect(brief.foodFocus.title.toLowerCase(), contains('luteal'));
      expect(brief.foodFocus.tags, contains(FoodTag.highFibre));
    });

    test('phase tags are merged in even when labs set the headline', () {
      final brief = _compose(
        report: _report([_marker(BiomarkerCode.ferritin, 21, 'ng/mL')]),
        phase: _phase(MenstrualPhaseName.luteal),
      );

      expect(brief.foodFocus.title.toLowerCase(), contains('iron'));
      // Luteal guidance favours fibre; both concerns should be represented.
      expect(brief.foodFocus.tags, contains(FoodTag.ironRich));
    });

    test('examples honour the diet pattern', () {
      final brief = _compose(
        profile: UserProfile.initial().copyWith(
          heightCm: 178,
          weightKg: 78,
          age: '34',
          dietPattern: DietPattern.vegan,
        ),
        report: _report([_marker(BiomarkerCode.ferritin, 21, 'ng/mL')]),
      );

      expect(brief.foodFocus.examples, isNotEmpty);
      for (final example in brief.foodFocus.examples) {
        expect(
          ['palak-paneer', 'raita', 'greek-yoghurt'],
          isNot(contains(example.id)),
        );
      }
    });

    test('always offers at least one concrete example', () {
      expect(_compose().foodFocus.examples, isNotEmpty);
    });
  });

  group('targets', () {
    test('every target carries a basis', () {
      for (final target in _compose().targets) {
        expect(target.basis, isNotEmpty);
      }
    });

    test('labels a measured energy basis honestly', () {
      final brief = _compose(
        targets: const NutritionTargets(
          calories: 2400,
          maintenanceCalories: 2400,
          energyBasis: EnergyBasis.measured,
          macros: MacroTargets(
            proteinG: 130,
            carbsG: 250,
            fatG: 70,
            fibreG: 31,
          ),
          addedSugarCeilingG: 27,
          waterMl: 2700,
          stepTarget: 8000,
          sleepTargetMinutes: 480,
        ),
      );

      final calories = brief.targets.firstWhere(
        (t) => t.id == BriefTargetId.calories,
      );
      expect(calories.basis.toLowerCase(), contains('measured'));
    });

    test('formats a step target with a thousands separator', () {
      final steps = _compose().targets.firstWhere(
        (t) => t.id == BriefTargetId.steps,
      );
      expect(steps.value, '8,000');
    });
  });

  group('caveats', () {
    test('admits when there is no blood work', () {
      final brief = _compose();
      expect(
        brief.caveats.any((c) => c.contains('blood work')),
        isTrue,
      );
    });

    test('admits when there is no telemetry', () {
      final brief = _compose(hasTelemetry: false);
      expect(
        brief.caveats.any((c) => c.contains('wearable')),
        isTrue,
      );
    });

    test('admits a sparse food log', () {
      final brief = _compose();
      expect(
        brief.caveats.any((c) => c.contains('food logged')),
        isTrue,
      );
    });

    test('admits assumed body composition', () {
      final brief = _compose(profile: UserProfile.initial());
      expect(
        brief.caveats.any((c) => c.contains('Height and weight')),
        isTrue,
      );
    });

    test('admits a low-confidence cycle estimate', () {
      final brief = _compose(
        phase: MenstrualPhase(
          name: MenstrualPhaseName.luteal,
          label: 'Luteal phase',
          dayOfCycle: 20,
          cycleLengthDays: 28,
          isMeasuredLength: false,
          daysUntilNextPeriod: 8,
          confidence: PhaseConfidence.low,
          summary: 's',
        ),
      );

      expect(
        brief.caveats.any((c) => c.contains('low-confidence')),
        isTrue,
      );
    });

    test('a fully-informed brief has fewer caveats', () {
      final informed = _compose(
        readiness: _readiness(72, ReadinessBand.moderate),
        report: _report([_marker(BiomarkerCode.ferritin, 80, 'ng/mL')]),
        lastNight: _lastNight(),
      );

      expect(
        informed.caveats.length,
        lessThan(_compose(hasTelemetry: false).caveats.length),
      );
    });
  });

  group('narrative', () {
    test('quotes the readiness score', () {
      final brief = _compose(readiness: _readiness(72, ReadinessBand.moderate));
      expect(brief.narrative.first, contains('72'));
    });

    test('says so when readiness cannot be scored', () {
      final brief = _compose();
      expect(brief.headline, contains('baseline'));
    });

    test('quotes last night’s sleep stages', () {
      final brief = _compose(lastNight: _lastNight(asleepMinutes: 450));
      expect(
        brief.narrative.any((s) => s.contains('deep')),
        isTrue,
      );
    });

    test('surfaces the expected-telemetry note only when readiness is low', () {
      final low = _compose(
        readiness: _readiness(42, ReadinessBand.low),
        phase: _phase(MenstrualPhaseName.luteal),
      );
      final fine = _compose(
        readiness: _readiness(78, ReadinessBand.moderate),
        phase: _phase(MenstrualPhaseName.luteal),
      );

      bool mentionsExpected(DailyBrief b) => b.narrative.any(
        (s) => s.toLowerCase().contains('resting heart rate typically'),
      );

      expect(mentionsExpected(low), isTrue);
      expect(mentionsExpected(fine), isFalse);
    });
  });

  group('drivers', () {
    test('recovery and sleep come before food', () {
      final brief = _compose(
        readiness: _readiness(72, ReadinessBand.moderate),
        lastNight: _lastNight(),
        report: _report([_marker(BiomarkerCode.ferritin, 21, 'ng/mL')]),
      );

      final kinds = brief.drivers.map((d) => d.kind).toList();
      expect(kinds.first, BriefDriverKind.recovery);
      expect(
        kinds.indexOf(BriefDriverKind.sleep),
        lessThan(kinds.indexOf(BriefDriverKind.labs)),
      );
    });

    test('every driver explains itself', () {
      final brief = _compose(
        readiness: _readiness(72, ReadinessBand.moderate),
        lastNight: _lastNight(),
        phase: _phase(MenstrualPhaseName.luteal),
        report: _report([_marker(BiomarkerCode.ferritin, 21, 'ng/mL')]),
      );

      expect(brief.drivers, isNotEmpty);
      for (final driver in brief.drivers) {
        expect(driver.label, isNotEmpty);
        expect(driver.detail, isNotEmpty);
      }
    });

    test('driver ids are unique', () {
      final brief = _compose(
        readiness: _readiness(72, ReadinessBand.moderate),
        lastNight: _lastNight(),
        phase: _phase(MenstrualPhaseName.luteal),
        report: _report([
          _marker(BiomarkerCode.ferritin, 21, 'ng/mL'),
          _marker(BiomarkerCode.hsCrp, 9, 'mg/L'),
        ]),
      );

      final ids = brief.drivers.map((d) => d.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
    });
  });
}
