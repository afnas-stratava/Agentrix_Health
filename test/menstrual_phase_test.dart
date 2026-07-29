import 'package:agentrix_health/core/util/iso_day.dart';
import 'package:agentrix_health/domain/entities/profile/cycle_profile.dart';
import 'package:agentrix_health/features/cycle/menstrual_phase.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ported from `__tests__/cycle-phase.test.ts`.
///
/// `now` is converted to local time up front: every date in these cases is
/// derived from it by local-day arithmetic, so the suite stays self-consistent
/// (and green) whatever timezone the runner sits in — which is exactly how the
/// Jest original behaved.
void main() {
  final now = DateTime.parse('2026-07-29T09:00:00+05:30').toLocal();

  CycleProfile cycle({
    bool tracks = true,
    List<IsoDay> periodStarts = const [],
    bool hormonalContraception = false,
  }) =>
      CycleProfile(
        tracks: tracks,
        periodStarts: periodStarts,
        hormonalContraception: hormonalContraception,
      );

  /// Period starts `daysAgo` before [now], as ISO days.
  List<IsoDay> startedDaysAgo(List<int> daysAgo) =>
      daysAgo.map((offset) => toIsoDay(addDays(now, -offset))).toList()..sort();

  group('computeMenstrualPhase', () {
    test('returns null when tracking is switched off', () {
      expect(
        computeMenstrualPhase(
          cycle(tracks: false, periodStarts: startedDaysAgo([3])),
          now,
        ),
        isNull,
      );
    });

    test('returns null with no logged period', () {
      expect(computeMenstrualPhase(cycle(), now), isNull);
    });

    test('places day 3 in the menstrual phase', () {
      final phase =
          computeMenstrualPhase(cycle(periodStarts: startedDaysAgo([2])), now);
      expect(phase?.name, MenstrualPhaseName.menstrual);
      expect(phase?.dayOfCycle, 3);
    });

    test('places day 10 of a 28-day cycle in the follicular phase', () {
      final phase =
          computeMenstrualPhase(cycle(periodStarts: startedDaysAgo([9])), now);
      expect(phase?.name, MenstrualPhaseName.follicular);
    });

    test('places ovulation at length minus 14, not at a fixed day 14', () {
      // A measured 34-day cycle ovulates around day 20.
      final long = cycle(periodStarts: startedDaysAgo([19, 53, 87]));
      final phase = computeMenstrualPhase(long, now);

      expect(phase?.cycleLengthDays, 34);
      expect(phase?.dayOfCycle, 20);
      expect(phase?.name, MenstrualPhaseName.ovulatory);
    });

    test('places the late cycle in the luteal phase', () {
      final phase =
          computeMenstrualPhase(cycle(periodStarts: startedDaysAgo([21])), now);
      expect(phase?.name, MenstrualPhaseName.luteal);
      expect(phase?.daysUntilNextPeriod, 7);
    });

    test('measures cycle length from history and marks it high confidence', () {
      final phase = computeMenstrualPhase(
        cycle(periodStarts: startedDaysAgo([5, 34, 63])),
        now,
      );
      expect(phase?.isMeasuredLength, isTrue);
      expect(phase?.cycleLengthDays, 29);
      expect(phase?.confidence, PhaseConfidence.high);
    });

    test('falls back to the declared length at moderate confidence', () {
      final phase =
          computeMenstrualPhase(cycle(periodStarts: startedDaysAgo([5])), now);
      expect(phase?.isMeasuredLength, isFalse);
      expect(phase?.confidence, PhaseConfidence.moderate);
    });

    test('takes the median gap so one skipped log cannot distort the model', () {
      // Gaps of 28, 56 (a missed log) and 28 → median 28, not the 37 mean.
      final phase = computeMenstrualPhase(
        cycle(periodStarts: startedDaysAgo([2, 30, 86, 114])),
        now,
      );
      expect(phase?.cycleLengthDays, 28);
    });

    test('stops rather than inventing a phase once a log goes stale', () {
      expect(
        computeMenstrualPhase(cycle(periodStarts: startedDaysAgo([45])), now),
        isNull,
      );
    });

    test('still reports a late period inside the grace window, at low confidence',
        () {
      final phase =
          computeMenstrualPhase(cycle(periodStarts: startedDaysAgo([31])), now);
      expect(phase?.name, MenstrualPhaseName.luteal);
      expect(phase?.daysUntilNextPeriod, -3);
      expect(phase?.confidence, PhaseConfidence.low);
    });

    test('downgrades confidence on hormonal contraception', () {
      final phase = computeMenstrualPhase(
        cycle(
          periodStarts: startedDaysAgo([5, 34, 63]),
          hormonalContraception: true,
        ),
        now,
      );
      expect(phase?.confidence, PhaseConfidence.low);
    });

    test('ignores a future-dated log rather than reporting a negative day', () {
      final future = cycle(periodStarts: [toIsoDay(addDays(now, 3))]);
      expect(computeMenstrualPhase(future, now), isNull);
    });
  });

  group('withPeriodStart', () {
    test('appends and keeps the list sorted', () {
      final next = withPeriodStart(
        cycle(periodStarts: const ['2026-05-02']),
        '2026-04-01',
      );
      expect(next.periodStarts, ['2026-04-01', '2026-05-02']);
    });

    test('is idempotent for the same day', () {
      final once = withPeriodStart(cycle(), '2026-07-01');
      expect(withPeriodStart(once, '2026-07-01').periodStarts, ['2026-07-01']);
    });
  });
}
