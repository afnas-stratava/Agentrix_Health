import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/util/iso_day.dart';
import '../../domain/entities/brief/daily_brief.dart';
import '../../features/brief/compose.dart';
import 'cycle_phase_provider.dart';
import 'health_providers.dart';
import 'labs_providers.dart';
import 'nutrition_providers.dart';
import 'user_profile_provider.dart';

/// The morning brief, composed from every input the app holds.
///
/// This is a plain `Provider`, not a notifier with a "regenerate" button: the
/// brief is a pure function of the day's data, so the same inputs must always
/// produce the same plan. "Regenerating" a deterministic composition would
/// either change nothing or reveal that something in it was arbitrary. What the
/// UI offers instead is a refresh of the *inputs* (pull-to-refresh on telemetry),
/// after which this recomputes on its own.
final dailyBriefProvider = Provider<DailyBrief?>((ref) {
  final targets = ref.watch(nutritionTargetsProvider);
  if (targets == null) return null;

  final series = ref.watch(healthSeriesProvider).valueOrNull ?? const [];

  return composeBrief(
    ComposeInput(
      day: ref.watch(todayIsoDayProvider),
      now: DateTime.now(),
      profile: ref.watch(userProfileProvider),
      targets: targets,
      readiness: ref.watch(readinessProvider),
      nutrition: ref.watch(weeklyNutritionProvider),
      report: ref.watch(latestLabReportProvider),
      phase: ref.watch(menstrualPhaseProvider),
      lastNight: series.isEmpty ? null : series.last,
      hasTelemetry: series.isNotEmpty,
    ),
  );
});

/// The single line Home shows. Falls back to a truthful holding message rather
/// than an empty card while targets are still being computed.
final briefTeaserProvider = Provider<String>((ref) {
  final brief = ref.watch(dailyBriefProvider);
  if (brief == null) return 'Building your plan for today…';
  return brief.headline;
});

/// Progress against today's headline targets, for the rings on the brief screen.
class TargetProgress {
  const TargetProgress({
    required this.calories,
    required this.protein,
    required this.water,
    required this.steps,
  });

  /// Each 0–1, clamped.
  final double calories;
  final double protein;
  final double water;
  final double steps;
}

final targetProgressProvider = Provider<TargetProgress?>((ref) {
  final targets = ref.watch(nutritionTargetsProvider);
  if (targets == null) return null;

  final consumed = ref.watch(consumedTodayProvider);
  final water = ref.watch(hydrationTodayProvider);
  final series = ref.watch(healthSeriesProvider).valueOrNull;
  final stepsToday = series == null || series.isEmpty
      ? 0.0
      : (series.last.steps ?? 0);

  double ratio(num actual, num target) =>
      target <= 0 ? 0 : (actual / target).clamp(0.0, 1.0).toDouble();

  return TargetProgress(
    calories: ratio(consumed.calories, targets.calories),
    protein: ratio(consumed.proteinG, targets.macros.proteinG),
    water: ratio(water, targets.waterMl),
    steps: ratio(stepsToday, targets.stepTarget),
  );
});

/// Kept for the Profile screen's notification-time row: the brief is composed
/// locally, so the only thing a time setting can drive is a local notification.
final briefDayProvider = Provider<IsoDay>(
  (ref) => ref.watch(todayIsoDayProvider),
);
