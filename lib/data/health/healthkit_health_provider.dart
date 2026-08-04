import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:health/health.dart' as hk;

import '../../core/util/iso_day.dart';
import '../../domain/entities/health/metric_key.dart' show HealthPermissionState;
import '../../features/health/telemetry_samples.dart';

/// Real platform telemetry, via HealthKit on iOS and Health Connect on Android.
/// The Dart counterpart of `src/features/health/healthkit.provider.ts`.
///
/// Binds the platform to the app's own [HealthProvider] interface, so every
/// screen above it is identical whether the numbers came from an Apple Watch or
/// from the deterministic synthetic provider. That boundary is what makes the
/// app developable on a simulator with no paired watch — and it is why swapping
/// providers is one line in `health_providers.dart`.
///
/// Requires, on iOS: the HealthKit capability, `NSHealthShareUsageDescription`
/// in `Info.plist`, and a physical device (the simulator has no Health store
/// worth reading). [isAvailable] returns false everywhere else, and the caller
/// falls back to synthetic rather than showing an error.
class HealthKitHealthProvider implements HealthProvider {
  HealthKitHealthProvider({hk.Health? health})
    : _health = health ?? hk.Health();

  final hk.Health _health;

  bool _configured = false;

  @override
  String get id => 'healthkit';

  /// Read-only: this app never writes to the user's health store.
  ///
  /// HRV and total-time-in-bed have no shared type across the two platforms:
  /// HealthKit only exposes SDNN and `SLEEP_IN_BED`, Health Connect only
  /// exposes RMSSD and has no in-bed concept at all. Requesting a type the
  /// current platform doesn't support throws before the permission dialog
  /// even shows, which silently reads as "denied" one layer up — so the list
  /// itself has to be platform-specific rather than a single shared one.
  static List<hk.HealthDataType> get _types => [
    Platform.isAndroid
        ? hk.HealthDataType.HEART_RATE_VARIABILITY_RMSSD
        : hk.HealthDataType.HEART_RATE_VARIABILITY_SDNN,
    hk.HealthDataType.RESTING_HEART_RATE,
    hk.HealthDataType.SLEEP_ASLEEP,
    hk.HealthDataType.SLEEP_DEEP,
    hk.HealthDataType.SLEEP_REM,
    hk.HealthDataType.SLEEP_LIGHT,
    hk.HealthDataType.SLEEP_AWAKE,
    if (!Platform.isAndroid) hk.HealthDataType.SLEEP_IN_BED,
    hk.HealthDataType.ACTIVE_ENERGY_BURNED,
    hk.HealthDataType.STEPS,
  ];

  /// Raw records pulled via [hk.Health.getHealthDataFromTypes]. STEPS is
  /// deliberately excluded here — see [fetchRange].
  static List<hk.HealthDataType> get _rawFetchTypes =>
      _types.where((t) => t != hk.HealthDataType.STEPS).toList();

  List<hk.HealthDataAccess> get _readOnly =>
      List.filled(_types.length, hk.HealthDataAccess.READ);

  Future<void>? _configureFuture;

  /// `configure()` does async native setup (device id lookup); every other
  /// call has to wait for it or it silently no-ops on Android, which reads as
  /// permanently-empty data one layer up.
  Future<void> _ensureConfigured() {
    if (_configured) return Future.value();
    return _configureFuture ??= _health.configure().then((_) {
      _configured = true;
    });
  }

  @override
  Future<bool> isAvailable() async {
    if (kIsWeb) return false;
    if (!Platform.isIOS && !Platform.isAndroid) return false;
    await _ensureConfigured();
    // Android needs Health Connect installed; iOS needs a real device.
    if (Platform.isAndroid) {
      return _health.isHealthConnectAvailable();
    }
    return true;
  }

  @override
  Future<HealthPermissionState> requestAuthorization() async {
    if (!await isAvailable()) return HealthPermissionState.unavailable;
    await _ensureConfigured();
    try {
      final granted = await _health.requestAuthorization(
        _types,
        permissions: _readOnly,
      );
      return granted
          ? HealthPermissionState.granted
          : HealthPermissionState.denied;
    } catch (error) {
      debugPrint('HealthKit authorization failed: $error');
      return HealthPermissionState.denied;
    }
  }

  @override
  Future<HealthPermissionState> getPermissionState() async {
    if (!await isAvailable()) return HealthPermissionState.unavailable;
    await _ensureConfigured();
    try {
      final granted = await _health.hasPermissions(
        _types,
        permissions: _readOnly,
      );
      return switch (granted) {
        true => HealthPermissionState.granted,
        false => HealthPermissionState.denied,
        // iOS deliberately refuses to reveal read authorization, to avoid
        // leaking that a user has no data for a type. Undetermined is the only
        // honest answer, and the caller resolves it by simply trying to read.
        null => HealthPermissionState.undetermined,
      };
    } catch (error) {
      debugPrint('HealthKit permission check failed: $error');
      return HealthPermissionState.undetermined;
    }
  }

  @override
  Future<RawTelemetry> fetchRange(DateTime from, DateTime to) async {
    await _ensureConfigured();

    final points = await _health.getHealthDataFromTypes(
      types: _rawFetchTypes,
      startTime: from,
      endTime: to,
    );

    final hrv = <QuantitySample>[];
    final restingHeartRate = <QuantitySample>[];
    final activeEnergy = <QuantitySample>[];
    final sleep = <SleepSample>[];

    for (final point in _health.removeDuplicates(points)) {
      final start = point.dateFrom.toIso8601String();
      final end = point.dateTo.toIso8601String();
      final source = point.sourceName;

      final stage = _sleepStageFor(point.type);
      if (stage != null) {
        sleep.add(
          SleepSample(
            startDate: start,
            endDate: end,
            value: stage,
            sourceName: source,
          ),
        );
        continue;
      }

      final value = _numericValue(point.value);
      if (value == null) continue;

      final sample = QuantitySample(
        startDate: start,
        endDate: end,
        value: value,
        sourceName: source,
      );

      switch (point.type) {
        case hk.HealthDataType.HEART_RATE_VARIABILITY_SDNN:
          // HealthKit stores SDNN in seconds on some source devices and
          // milliseconds on others. Anything under 1 is unambiguously seconds —
          // a 0.045 ms HRV does not exist — so normalise rather than trust it.
          hrv.add(
            value < 1
                ? QuantitySample(
                    startDate: start,
                    endDate: end,
                    value: value * 1000,
                    sourceName: source,
                  )
                : sample,
          );
        // Health Connect's RMSSD record is always milliseconds — no unit
        // ambiguity to normalise, unlike HealthKit's SDNN above.
        case hk.HealthDataType.HEART_RATE_VARIABILITY_RMSSD:
          hrv.add(sample);
        case hk.HealthDataType.RESTING_HEART_RATE:
          restingHeartRate.add(sample);
        case hk.HealthDataType.ACTIVE_ENERGY_BURNED:
          activeEnergy.add(sample);
        default:
          break;
      }
    }

    return RawTelemetry(
      hrv: hrv,
      restingHeartRate: restingHeartRate,
      sleep: sleep,
      activeEnergy: activeEnergy,
      steps: await _fetchDailySteps(from, to),
    );
  }

  /// Health Connect aggregates steps across every contributing source itself
  /// (phone sensor, watch, a manually-logged workout app); summing raw STEPS
  /// records the way every other type here is summed double-counts whenever
  /// more than one source logs the same walk, inflating the daily total.
  /// [hk.Health.getTotalStepsInInterval] is the plugin's own de-duplicated
  /// aggregate, so it is used instead — one sample per calendar day.
  Future<List<QuantitySample>> _fetchDailySteps(
    DateTime from,
    DateTime to,
  ) async {
    // One channel call per day — fired concurrently rather than awaited in
    // sequence, since a 90-day window at ~100ms/call serially would blow past
    // the caller's fixed timeout on the whole fetch and force a fallback to
    // synthetic data even though every other metric fetched fine.
    final ranges = enumerateDays(from, to)
        .map((day) {
          final dayStart = fromIsoDay(day);
          final dayEnd = dayStart.add(const Duration(days: 1));
          final rangeStart = dayStart.isBefore(from) ? from : dayStart;
          final rangeEnd = dayEnd.isAfter(to) ? to : dayEnd;
          return (start: rangeStart, end: rangeEnd);
        })
        .where((r) => r.start.isBefore(r.end))
        .toList();

    final totals = await Future.wait(
      ranges.map((r) => _health.getTotalStepsInInterval(r.start, r.end)),
    );

    final steps = <QuantitySample>[];
    for (var i = 0; i < ranges.length; i += 1) {
      final total = totals[i];
      if (total == null || total <= 0) continue;
      steps.add(
        QuantitySample(
          startDate: ranges[i].start.toIso8601String(),
          endDate: ranges[i].end.toIso8601String(),
          value: total.toDouble(),
          sourceName: id,
        ),
      );
    }
    return steps;
  }

  @override
  void Function() subscribe(void Function() onChange) {
    // HealthKit observer queries are not exposed by the `health` plugin; the
    // Today screen refreshes on pull and on foreground instead.
    return () {};
  }

  static double? _numericValue(hk.HealthValue value) {
    if (value is hk.NumericHealthValue) {
      return value.numericValue.toDouble();
    }
    return null;
  }

  static SleepStageValue? _sleepStageFor(hk.HealthDataType type) =>
      switch (type) {
        hk.HealthDataType.SLEEP_DEEP => SleepStageValue.deep,
        hk.HealthDataType.SLEEP_REM => SleepStageValue.rem,
        hk.HealthDataType.SLEEP_LIGHT => SleepStageValue.core,
        hk.HealthDataType.SLEEP_AWAKE => SleepStageValue.awake,
        hk.HealthDataType.SLEEP_IN_BED => SleepStageValue.inBed,
        hk.HealthDataType.SLEEP_ASLEEP => SleepStageValue.asleep,
        _ => null,
      };
}
