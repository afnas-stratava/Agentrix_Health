import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:health/health.dart' as hk;

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
  static const List<hk.HealthDataType> _types = [
    hk.HealthDataType.HEART_RATE_VARIABILITY_SDNN,
    hk.HealthDataType.RESTING_HEART_RATE,
    hk.HealthDataType.SLEEP_ASLEEP,
    hk.HealthDataType.SLEEP_DEEP,
    hk.HealthDataType.SLEEP_REM,
    hk.HealthDataType.SLEEP_LIGHT,
    hk.HealthDataType.SLEEP_AWAKE,
    hk.HealthDataType.SLEEP_IN_BED,
    hk.HealthDataType.ACTIVE_ENERGY_BURNED,
    hk.HealthDataType.STEPS,
  ];

  List<hk.HealthDataAccess> get _readOnly =>
      List.filled(_types.length, hk.HealthDataAccess.READ);

  void _ensureConfigured() {
    if (_configured) return;
    _health.configure();
    _configured = true;
  }

  @override
  Future<bool> isAvailable() async {
    if (kIsWeb) return false;
    if (!Platform.isIOS && !Platform.isAndroid) return false;
    _ensureConfigured();
    // Android needs Health Connect installed; iOS needs a real device.
    if (Platform.isAndroid) {
      return _health.isHealthConnectAvailable();
    }
    return true;
  }

  @override
  Future<HealthPermissionState> requestAuthorization() async {
    if (!await isAvailable()) return HealthPermissionState.unavailable;
    _ensureConfigured();
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
    _ensureConfigured();
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
    _ensureConfigured();

    final points = await _health.getHealthDataFromTypes(
      types: _types,
      startTime: from,
      endTime: to,
    );

    final hrv = <QuantitySample>[];
    final restingHeartRate = <QuantitySample>[];
    final activeEnergy = <QuantitySample>[];
    final steps = <QuantitySample>[];
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
        case hk.HealthDataType.RESTING_HEART_RATE:
          restingHeartRate.add(sample);
        case hk.HealthDataType.ACTIVE_ENERGY_BURNED:
          activeEnergy.add(sample);
        case hk.HealthDataType.STEPS:
          steps.add(sample);
        default:
          break;
      }
    }

    return RawTelemetry(
      hrv: hrv,
      restingHeartRate: restingHeartRate,
      sleep: sleep,
      activeEnergy: activeEnergy,
      steps: steps,
    );
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
