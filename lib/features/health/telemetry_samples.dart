import '../../domain/entities/health/metric_key.dart';

/// Ported from `src/features/health/types.ts`.

/// Normalised sample shape shared by every provider implementation.
class QuantitySample {
  const QuantitySample({
    required this.startDate,
    required this.endDate,
    required this.value,
    this.sourceName,
    this.sourceId,
  });

  final String startDate;
  final String endDate;
  final double value;
  final String? sourceName;
  final String? sourceId;
}

enum SleepStageValue {
  inBed('INBED'),
  asleep('ASLEEP'),
  awake('AWAKE'),
  core('CORE'),
  deep('DEEP'),
  rem('REM'),
  unspecified('UNSPECIFIED');

  const SleepStageValue(this.wireName);

  final String wireName;

  static SleepStageValue fromWireName(String value) =>
      SleepStageValue.values.firstWhere(
        (s) => s.wireName == value,
        orElse: () => SleepStageValue.unspecified,
      );
}

class SleepSample {
  const SleepSample({
    required this.startDate,
    required this.endDate,
    required this.value,
    this.sourceName,
    this.sourceId,
  });

  final String startDate;
  final String endDate;
  final SleepStageValue value;
  final String? sourceName;
  final String? sourceId;
}

class RawTelemetry {
  const RawTelemetry({
    this.hrv = const [],
    this.restingHeartRate = const [],
    this.sleep = const [],
    this.activeEnergy = const [],
    this.steps = const [],
  });

  final List<QuantitySample> hrv;
  final List<QuantitySample> restingHeartRate;
  final List<SleepSample> sleep;
  final List<QuantitySample> activeEnergy;
  final List<QuantitySample> steps;
}

/// Platform-agnostic contract. iOS binds this to HealthKit; the simulator and
/// Android bind it to the deterministic synthetic provider so every screen is
/// developable without a paired Apple Watch.
abstract class HealthProvider {
  String get id;

  Future<bool> isAvailable();

  Future<HealthPermissionState> requestAuthorization();

  Future<HealthPermissionState> getPermissionState();

  Future<RawTelemetry> fetchRange(DateTime from, DateTime to);

  /// Returns an unsubscribe callback; a no-op on providers without observers.
  void Function() subscribe(void Function() onChange);
}
