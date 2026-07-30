import '../../core/util/iso_day.dart';
import '../../domain/entities/nutrition/food_definition.dart';
import '../../domain/entities/profile/cycle_profile.dart';

/// Menstrual-cycle phase model. Ported from `src/features/cycle/phase.ts`.
///
/// Phase is inferred from logged period start dates — HealthKit's menstrual-flow
/// category was not exposed to the React Native build, so iOS could not supply
/// this even though it records it natively. Everything here is calendar
/// arithmetic over the user's own history; no cycle is predicted from
/// telemetry, because HRV-based ovulation detection is not reliable enough to
/// put in front of someone as fact.
///
/// Boundaries follow the standard four-phase model with a fixed 14-day luteal
/// length (the luteal phase is the stable part of the cycle; variation lives
/// almost entirely in the follicular phase). For a 28-day cycle this reproduces
/// the textbook day numbers, and for a 34-day cycle it correctly places
/// ovulation at day 20 rather than day 14.
///
/// Named `MenstrualPhase` rather than `CyclePhase` so it coexists with the
/// pre-existing `lib/domain/entities/cycle_phase.dart` in this app.

enum MenstrualPhaseName { menstrual, follicular, ovulatory, luteal }

const Map<MenstrualPhaseName, String> phaseLabel = {
  MenstrualPhaseName.menstrual: 'Menstrual phase',
  MenstrualPhaseName.follicular: 'Follicular phase',
  MenstrualPhaseName.ovulatory: 'Ovulatory phase',
  MenstrualPhaseName.luteal: 'Luteal phase',
};

/// Days from ovulation to the next period. Physiologically near-constant.
const int _lutealLengthDays = 14;

enum PhaseConfidence { high, moderate, low }

class MenstrualPhase {
  const MenstrualPhase({
    required this.name,
    required this.label,
    required this.dayOfCycle,
    required this.cycleLengthDays,
    required this.isMeasuredLength,
    required this.daysUntilNextPeriod,
    required this.confidence,
    required this.summary,
  });

  final MenstrualPhaseName name;
  final String label;

  /// 1-indexed day of the current cycle.
  final int dayOfCycle;

  /// Cycle length used for the maths, measured where possible.
  final int cycleLengthDays;

  /// True when the length came from the user's logged history.
  final bool isMeasuredLength;

  /// Negative once the expected date has passed.
  final int daysUntilNextPeriod;

  /// Confidence in the phase call. Drops when only one period has been logged,
  /// when the last log is stale, or when hormonal contraception makes the
  /// underlying hormonal cycle absent regardless of bleeding pattern.
  final PhaseConfidence confidence;

  /// One line the brief can quote directly.
  final String summary;

  /// 1-indexed day of the cycle on which ovulation is expected.
  ///
  /// Derived rather than stored, from the same fixed luteal length the phase
  /// boundaries use — so the ring, the countdown and the phase call can never
  /// disagree about when ovulation is.
  int get ovulationDay => cycleLengthDays - _lutealLengthDays;

  /// Days until [ovulationDay]; negative once it has passed.
  int get daysUntilOvulation => ovulationDay - dayOfCycle;
}

/// Median gap between consecutive logged periods. Median rather than mean
/// because one skipped log doubles a gap and would drag a mean badly.
int? _measuredCycleLength(List<IsoDay> periodStarts) {
  if (periodStarts.length < 2) return null;

  final sorted = [...periodStarts]..sort();
  final gaps = <int>[];
  for (var i = 1; i < sorted.length; i += 1) {
    final gap = daysBetween(fromIsoDay(sorted[i - 1]), fromIsoDay(sorted[i]));
    // Reject implausible gaps rather than letting a mis-log distort the model.
    if (gap >= 18 && gap <= 60) gaps.add(gap);
  }

  if (gaps.isEmpty) return null;

  final sortedGaps = [...gaps]..sort();
  final mid = sortedGaps.length ~/ 2;
  final median = sortedGaps.length.isEven
      ? (sortedGaps[mid - 1] + sortedGaps[mid]) / 2
      : sortedGaps[mid].toDouble();

  return median.round();
}

IsoDay? latestPeriodStart(CycleProfile cycle) {
  if (cycle.periodStarts.isEmpty) return null;
  return ([...cycle.periodStarts]..sort()).last;
}

MenstrualPhase? computeMenstrualPhase(CycleProfile cycle, [DateTime? now]) {
  if (!cycle.tracks) return null;

  final lastStart = latestPeriodStart(cycle);
  if (lastStart == null) return null;

  final measured = _measuredCycleLength(cycle.periodStarts);
  final cycleLengthDays = measured ?? cycle.averageCycleDays;

  final elapsed = daysBetween(fromIsoDay(lastStart), now ?? DateTime.now());
  // A log from the future is a data-entry error, not a phase.
  if (elapsed < 0) return null;

  // Past one full cycle with no new log, the phase is genuinely unknown: the
  // user may be late, pregnant, or simply not logging. Rolling the day number
  // over with a modulo would invent a phase we cannot support, so the model
  // stops instead — but only after a generous grace window, so someone two
  // days late still sees a sensible late-luteal reading.
  if (elapsed > cycleLengthDays + 10) return null;

  final dayOfCycle = elapsed + 1;
  final ovulationDay = cycleLengthDays - _lutealLengthDays;

  final MenstrualPhaseName name;
  if (dayOfCycle <= cycle.averagePeriodDays) {
    name = MenstrualPhaseName.menstrual;
  } else if (dayOfCycle < ovulationDay - 1) {
    name = MenstrualPhaseName.follicular;
  } else if (dayOfCycle <= ovulationDay + 1) {
    name = MenstrualPhaseName.ovulatory;
  } else {
    name = MenstrualPhaseName.luteal;
  }

  var confidence = measured != null
      ? PhaseConfidence.high
      : PhaseConfidence.moderate;
  if (cycle.hormonalContraception) confidence = PhaseConfidence.low;
  if (elapsed > cycleLengthDays) confidence = PhaseConfidence.low;

  final daysUntilNextPeriod = cycleLengthDays - elapsed;

  return MenstrualPhase(
    name: name,
    label: phaseLabel[name]!,
    dayOfCycle: dayOfCycle,
    cycleLengthDays: cycleLengthDays,
    isMeasuredLength: measured != null,
    daysUntilNextPeriod: daysUntilNextPeriod,
    confidence: confidence,
    summary: _phaseSummary(name, dayOfCycle, daysUntilNextPeriod),
  );
}

String _phaseSummary(MenstrualPhaseName name, int dayOfCycle, int daysUntil) {
  switch (name) {
    case MenstrualPhaseName.menstrual:
      return 'Day $dayOfCycle — iron demand is at its highest point of the month.';
    case MenstrualPhaseName.follicular:
      return 'Day $dayOfCycle — rising oestrogen, the best window for hard training.';
    case MenstrualPhaseName.ovulatory:
      return 'Day $dayOfCycle — peak strength and power, and peak injury risk.';
    case MenstrualPhaseName.luteal:
      if (daysUntil >= 0) {
        final plural = daysUntil == 1 ? '' : 's';
        return 'Day $dayOfCycle — $daysUntil day$plural until your next period; '
            'resting heart rate normally runs higher here.';
      }
      final late = daysUntil.abs();
      final plural = late == 1 ? '' : 's';
      return 'Day $dayOfCycle — your period is $late day$plural later than your '
          'average cycle.';
  }
}

// ---------------------------------------------------------------------------
// Phase-aware guidance
// ---------------------------------------------------------------------------

/// Multiplier applied to the training-intensity recommendation.
enum TrainingBias { push, maintain, ease }

class PhaseGuidance {
  const PhaseGuidance({
    required this.trainingBias,
    required this.training,
    required this.nutrition,
    required this.favourTags,
    required this.expectedTelemetryNote,
  });

  final TrainingBias trainingBias;
  final String training;
  final String nutrition;

  /// Food tags to float up in dish and restaurant ranking during this phase.
  final List<FoodTag> favourTags;

  /// Telemetry the user should expect to look worse, so it is not read as
  /// illness.
  final String? expectedTelemetryNote;
}

const Map<MenstrualPhaseName, PhaseGuidance> phaseGuidance = {
  MenstrualPhaseName.menstrual: PhaseGuidance(
    trainingBias: TrainingBias.ease,
    training:
        'Keep it easy — walking, mobility or a light session. Match effort to how you feel rather than to the plan.',
    nutrition:
        'Iron losses peak now. Pair an iron source with vitamin C at the same meal, and keep caffeine away from it by an hour or so — both change how much you actually absorb.',
    favourTags: [FoodTag.ironRich, FoodTag.vitaminCRich, FoodTag.highProtein],
    expectedTelemetryNote:
        'A slightly lower HRV and higher resting heart rate during your period is normal and not a sign of overtraining.',
  ),
  MenstrualPhaseName.follicular: PhaseGuidance(
    trainingBias: TrainingBias.push,
    training:
        'Rising oestrogen improves carbohydrate use and recovery. This is the window for your hardest sessions and any strength progression.',
    nutrition:
        'Carbohydrate tolerance is at its best — put your bigger, starchier meals around training here rather than later in the month.',
    favourTags: [FoodTag.wholegrain, FoodTag.highProtein],
    expectedTelemetryNote: null,
  ),
  MenstrualPhaseName.ovulatory: PhaseGuidance(
    trainingBias: TrainingBias.push,
    training:
        'Peak strength and power. Worth a heavy session — with a proper warm-up, since ligament laxity is also at its highest.',
    nutrition:
        'Keep protein high to make use of the recovery window, and hydrate deliberately.',
    favourTags: [FoodTag.highProtein, FoodTag.leafyGreen],
    expectedTelemetryNote: null,
  ),
  MenstrualPhaseName.luteal: PhaseGuidance(
    trainingBias: TrainingBias.maintain,
    training:
        'Hold volume, drop intensity a notch. Core temperature runs higher, so the same session will feel harder than it did two weeks ago.',
    nutrition:
        'Resting expenditure is genuinely higher — roughly 5% — so a slightly larger appetite is physiology, not a lapse. Magnesium and fibre help with the bloating and the cravings.',
    favourTags: [FoodTag.highFibre, FoodTag.calciumRich, FoodTag.omega3Rich],
    expectedTelemetryNote:
        'Resting heart rate typically sits a few beats higher and HRV a little lower across the luteal phase.',
  ),
};

/// Convenience for the brief: the phase's day-count position as a fraction.
double cycleProgress(MenstrualPhase phase) {
  final raw = phase.dayOfCycle / phase.cycleLengthDays;
  return raw < 0 ? 0 : (raw > 1 ? 1 : raw);
}

/// Records a new period start, keeping the list sorted and de-duplicated.
CycleProfile withPeriodStart(CycleProfile cycle, IsoDay day) {
  final next = {...cycle.periodStarts, day}.toList()..sort();
  return cycle.copyWith(periodStarts: next);
}

IsoDay todayIsoDay([DateTime? now]) => toIsoDay(now ?? DateTime.now());
