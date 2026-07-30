import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/util/iso_day.dart';
import '../../data/health/healthkit_health_provider.dart';
import '../../data/health/synthetic_health_provider.dart';
import '../../domain/entities/health/daily_snapshot.dart';
import '../../domain/entities/health/metric_key.dart';
import '../../domain/entities/insights/readiness.dart';
import '../../features/correlation/engine.dart';
import '../../features/correlation/engine_context.dart';
import '../../features/correlation/readiness_calculator.dart';
import '../../features/health/aggregate.dart';
import '../../features/health/telemetry_samples.dart';
import 'labs_providers.dart';
import 'settings_providers.dart';

/// Mirrors `useHealthSeries` / `useInsights` in the React Native app: telemetry
/// in, day-aligned snapshots out, then the correlation engine on top.

/// Window the engine needs: 7 recent days + a 28-day baseline.
const int _windowDays = recentWindowDays + baselineWindowDays;

/// Ceiling on any single call into the platform health store.
///
/// HealthKit does not always answer. On the simulator there is no store behind
/// it, and on a real device a cold query can stall — either way an unbounded
/// `await` leaves every screen in a skeleton for ever, because the whole feed
/// hangs off this one future. Falling back to the synthetic series is always
/// better than an app that never finishes loading.
const Duration _healthCallTimeout = Duration(seconds: 4);

/// Runs a platform health call with a deadline, yielding [fallback] if it does
/// not answer in time or throws.
Future<T> _orFallback<T>(Future<T> Function() call, T fallback) async {
  try {
    return await call().timeout(_healthCallTimeout);
  } catch (error) {
    debugPrint('Health store call did not complete: $error');
    return fallback;
  }
}

/// Which telemetry source is actually feeding the screens.
enum TelemetrySource {
  /// Apple Health / Health Connect, with permission granted.
  platform,

  /// Deterministic synthetic series — simulator, web, CI, or permission denied.
  synthetic,
}

final telemetrySourceProvider = StateProvider<TelemetrySource>(
  (ref) => TelemetrySource.synthetic,
);

/// Resolves the platform provider when one is usable, and falls back to the
/// synthetic series otherwise.
///
/// The fallback is not a failure mode, it is the development path: the simulator
/// has no Health store worth reading, so a build that only worked on a paired
/// device would be undemoable. [telemetrySourceProvider] records which one won so
/// the UI can label synthetic data as sample data rather than implying a watch.
final healthProviderInstance = FutureProvider<HealthProvider>((ref) async {
  const synthetic = SyntheticHealthProvider();

  if (kIsWeb) return synthetic;

  final platform = HealthKitHealthProvider();
  if (!await _orFallback(platform.isAvailable, false)) return synthetic;

  final permission = await _orFallback(
    platform.getPermissionState,
    HealthPermissionState.unavailable,
  );
  // `undetermined` is the normal iOS answer even after a grant — it refuses to
  // reveal read authorization — so treat anything short of an outright denial as
  // worth attempting, and let the empty-series check below decide.
  if (permission == HealthPermissionState.denied ||
      permission == HealthPermissionState.unavailable) {
    return synthetic;
  }

  return platform;
});

/// Asks for Health permission, then re-resolves the provider.
///
/// Returns the state the user chose, so the connect screen can say what
/// happened rather than silently showing the same button.
Future<HealthPermissionState> requestHealthAccess(WidgetRef ref) async {
  final platform = HealthKitHealthProvider();
  if (!await platform.isAvailable()) {
    return HealthPermissionState.unavailable;
  }

  final result = await platform.requestAuthorization();
  ref.invalidate(healthProviderInstance);
  ref.invalidate(healthSeriesProvider);
  return result;
}

/// When the series in hand was fetched. Mirrors `lastSyncedAt` on the RN health
/// store — the Today header needs it to say whether these numbers are current.
final lastSyncedAtProvider = StateProvider<DateTime?>((ref) => null);

final healthSeriesProvider = FutureProvider<List<DailySnapshot>>((ref) async {
  final provider = await ref.watch(healthProviderInstance.future);
  final to = DateTime.now();
  final from = addDays(startOfLocalDay(to), -(_windowDays - 1));

  var series = aggregateDailySnapshots(
    // A store that never answers is treated exactly like an empty one: the
    // no-signal check below then falls through to the synthetic series.
    await _orFallback(() => provider.fetchRange(from, to), const RawTelemetry()),
    from,
    to,
  );
  var source = provider.id == 'synthetic'
      ? TelemetrySource.synthetic
      : TelemetrySource.platform;

  // A granted-but-empty Health store is the common case on a device that has
  // never worn a watch. Showing 35 blank days would suppress readiness, every
  // tile and the brief's recovery line all at once, so fall back rather than
  // present an app that looks broken.
  if (source == TelemetrySource.platform && !_hasAnySignal(series)) {
    const fallback = SyntheticHealthProvider();
    series = aggregateDailySnapshots(
      await fallback.fetchRange(from, to),
      from,
      to,
    );
    source = TelemetrySource.synthetic;
  }

  ref.read(telemetrySourceProvider.notifier).state = source;
  ref.read(lastSyncedAtProvider.notifier).state = DateTime.now();
  return series;
});

bool _hasAnySignal(List<DailySnapshot> series) => series.any(
  (day) =>
      day.hrv != null ||
      day.restingHeartRate != null ||
      day.sleep != null ||
      day.steps != null,
);

/// The single context every consumer reads — readiness, the metric tiles and the
/// correlation engine alike.
///
/// One provider rather than one per consumer, so a finding and the score beside
/// it can never be computed over different windows. Biomarkers are merged across
/// every report (latest value per analyte) rather than taken from the newest
/// panel alone.
final engineContextProvider = Provider<EngineContext?>((ref) {
  final series = ref.watch(healthSeriesProvider).valueOrNull;
  if (series == null || series.isEmpty) return null;

  final reports = ref.watch(labsProvider).reports;
  final latest = reports.isEmpty ? null : reports.first;

  return buildEngineContext(
    series: series,
    biomarkers: mergeBiomarkers(reports),
    labReportId: latest?.id,
    labCollectedAt: (latest?.collectedAt ?? latest?.uploadedAt)
        ?.toIso8601String(),
    // From Settings, not the profile: reference intervals are sex-specific, and
    // "prefer not to say" must resolve to the wider interval rather than a guess.
    sex: ref.watch(biologicalSexProvider),
  );
});

/// Null until there are [minBaselineDays] of data — a score invented from three
/// days of telemetry is worse than no score.
final readinessProvider = Provider<Readiness?>((ref) {
  final context = ref.watch(engineContextProvider);
  return context == null ? null : computeReadiness(context);
});

final metricStatsProvider = Provider<Map<MetricKey, MetricStats>?>((ref) {
  return ref.watch(engineContextProvider)?.metrics;
});

/// Freshness of the last sync, at minute granularity. The date alone does not
/// tell you whether the numbers below it are current, and "synced 4m ago" is
/// the difference between trusting a flat HRV reading and pulling to refresh.
String? syncLabel(DateTime? syncedAt, {DateTime? now}) {
  if (syncedAt == null) return null;
  final minutes = (now ?? DateTime.now()).difference(syncedAt).inMinutes;
  if (minutes < 0) return null;
  if (minutes < 1) return 'synced just now';
  if (minutes < 60) return 'synced ${minutes}m ago';
  final hours = minutes ~/ 60;
  if (hours < 24) return 'synced ${hours}h ago';
  return 'synced ${hours ~/ 24}d ago';
}
