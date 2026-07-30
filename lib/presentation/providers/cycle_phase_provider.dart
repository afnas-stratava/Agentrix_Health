import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/stats/stats.dart';
import '../../core/util/iso_day.dart';
import '../../domain/entities/profile/cycle_profile.dart';
import '../../features/cycle/menstrual_phase.dart';
import 'user_profile_provider.dart';

/// Surfaces the ported cycle model to the UI.
///
/// `computeMenstrualPhase` already existed and is the only thing allowed to
/// decide what phase today is — the screen derives everything from its output
/// rather than doing its own calendar arithmetic, so the ring, the countdowns
/// and the phase copy cannot drift apart.

/// Demo seed used when the user has not logged any periods.
///
/// The same choice `SyntheticHealthProvider` makes for telemetry: without it
/// every cycle screen is an empty state and undevelopable. A real profile with
/// `tracks: true` always wins over this.
CycleProfile demoCycleProfile([DateTime? now]) {
  final today = startOfLocalDay(now ?? DateTime.now());
  // Four logged periods with gaps of 30, 27 and 29 days. Deliberately uneven:
  // equal gaps compute to a flat 100% regularity, which looks like a stubbed
  // value rather than a measurement, and it never exercises the spread maths.
  // The median of those gaps is 29, so cycle length reads as *measured*.
  return CycleProfile(
    tracks: true,
    periodStarts: [
      toIsoDay(addDays(today, -99)),
      toIsoDay(addDays(today, -69)),
      toIsoDay(addDays(today, -42)),
      toIsoDay(addDays(today, -13)),
    ],
    averageCycleDays: 28,
    averagePeriodDays: 5,
  );
}

/// The profile the cycle screens read. Falls back to [demoCycleProfile] until
/// the user logs a period of their own.
final effectiveCycleProfileProvider = Provider<CycleProfile>((ref) {
  final cycle = ref.watch(userProfileProvider.select((p) => p.cycle));
  final hasOwnData = cycle.tracks && cycle.periodStarts.isNotEmpty;
  return hasOwnData ? cycle : demoCycleProfile();
});

/// Null when the model declines to make a call — no logs, a log from the
/// future, or more than a full cycle since the last one. The screen shows an
/// empty state rather than inventing a day number.
final menstrualPhaseProvider = Provider<MenstrualPhase?>((ref) {
  return computeMenstrualPhase(ref.watch(effectiveCycleProfileProvider));
});

/// Phase-specific training and nutrition guidance, or null when there is no
/// phase to guide. Read by the brief composer and the dish ranker, so all three
/// surfaces agree about what this phase asks for.
final phaseGuidanceProvider = Provider<PhaseGuidance?>((ref) {
  final phase = ref.watch(menstrualPhaseProvider);
  return phase == null ? null : phaseGuidance[phase.name];
});

/// Whether the user has switched cycle tracking on themselves, as opposed to
/// looking at the demo profile.
final cycleTrackingProvider = Provider<bool>(
  (ref) => ref.watch(userProfileProvider.select((p) => p.cycle.tracks)),
);

/// Records a period start and switches tracking on.
///
/// Turning tracking on as a side effect is deliberate: a user who has just told
/// us when their period started has unambiguously opted in, and making them find
/// a second switch before they can see the result is a dead end.
Future<void> logPeriodStart(WidgetRef ref, {IsoDay? day}) async {
  final profile = ref.read(userProfileProvider);
  final updated = withPeriodStart(
    // Starts from the user's own profile, never the demo one — appending to the
    // demo history would silently adopt four periods they never logged.
    profile.cycle,
    day ?? toIsoDay(DateTime.now()),
  );
  await ref
      .read(userProfileProvider.notifier)
      .updateCycle(updated.copyWith(tracks: true));
}

/// How consistent the logged cycles are, 0–100.
///
/// Expressed as the spread of cycle lengths relative to their mean, inverted —
/// a user whose cycles are 27/28/29 reads as highly regular, one whose cycles
/// are 24/31/38 does not. Null under two logged gaps, where there is no spread
/// to measure and any number would be invented.
final cycleRegularityProvider = Provider<int?>((ref) {
  final starts = ref.watch(effectiveCycleProfileProvider).periodStarts;
  if (starts.length < 3) return null;

  final sorted = [...starts]..sort();
  final gaps = <double>[];
  for (var i = 1; i < sorted.length; i += 1) {
    gaps.add(
      daysBetween(
        fromIsoDay(sorted[i - 1]),
        fromIsoDay(sorted[i]),
      ).toDouble(),
    );
  }
  if (gaps.length < 2) return null;

  final average = mean(gaps);
  final spread = stdDev(gaps);
  if (!average.isFinite || !spread.isFinite || average <= 0) return null;

  // A coefficient of variation of 0 is perfectly regular; 20% or worse reads
  // as irregular. Scaled so the number lands in a range people recognise.
  final cv = spread / average;
  return (100 - cv * 500).clamp(0, 100).round();
});
