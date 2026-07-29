import '../../../core/util/iso_day.dart';
import 'metric_key.dart';

/// Ported from `src/schemas/health.ts`.
///
/// Every numeric field is nullable because HealthKit legitimately returns
/// nothing for a day the user did not wear the watch — `0` and `null` mean very
/// different things to the correlation engine and must never be conflated.
/// Dart's sound null safety enforces at compile time what zod only checked at
/// the boundary, which is the one place this port is stricter than the original.

class SleepStages {
  const SleepStages({
    required this.deepMinutes,
    required this.remMinutes,
    required this.coreMinutes,
    required this.awakeMinutes,
    required this.unspecifiedMinutes,
  });

  /// Minutes in `HKCategoryValueSleepAnalysisAsleepDeep`.
  final double deepMinutes;

  /// Minutes in `...AsleepREM`.
  final double remMinutes;

  /// Minutes in `...AsleepCore` (light).
  final double coreMinutes;

  /// Minutes in bed but classified awake.
  final double awakeMinutes;

  /// Minutes with only `...AsleepUnspecified` — non-Apple-Watch sources.
  final double unspecifiedMinutes;
}

class SleepSummary extends SleepStages {
  const SleepSummary({
    required super.deepMinutes,
    required super.remMinutes,
    required super.coreMinutes,
    required super.awakeMinutes,
    required super.unspecifiedMinutes,
    required this.asleepMinutes,
    required this.inBedMinutes,
    required this.efficiency,
    required this.bedtime,
    required this.wakeTime,
  });

  /// Total asleep minutes (deep + rem + core + unspecified).
  final double asleepMinutes;

  /// Asleep + awake-in-bed.
  final double inBedMinutes;

  /// asleepMinutes / inBedMinutes, 0–1. Null when inBed is unknown.
  final double? efficiency;

  /// ISO datetime of sleep onset, used for circadian-drift detection.
  final String? bedtime;
  final String? wakeTime;

  factory SleepSummary.fromJson(Map<String, dynamic> json) => SleepSummary(
        deepMinutes: (json['deepMinutes'] as num).toDouble(),
        remMinutes: (json['remMinutes'] as num).toDouble(),
        coreMinutes: (json['coreMinutes'] as num).toDouble(),
        awakeMinutes: (json['awakeMinutes'] as num).toDouble(),
        unspecifiedMinutes: (json['unspecifiedMinutes'] as num).toDouble(),
        asleepMinutes: (json['asleepMinutes'] as num).toDouble(),
        inBedMinutes: (json['inBedMinutes'] as num).toDouble(),
        efficiency: (json['efficiency'] as num?)?.toDouble(),
        bedtime: json['bedtime'] as String?,
        wakeTime: json['wakeTime'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'deepMinutes': deepMinutes,
        'remMinutes': remMinutes,
        'coreMinutes': coreMinutes,
        'awakeMinutes': awakeMinutes,
        'unspecifiedMinutes': unspecifiedMinutes,
        'asleepMinutes': asleepMinutes,
        'inBedMinutes': inBedMinutes,
        'efficiency': efficiency,
        'bedtime': bedtime,
        'wakeTime': wakeTime,
      };
}

/// One calendar day of aggregated telemetry.
class DailySnapshot {
  const DailySnapshot({
    required this.day,
    this.hrv,
    this.restingHeartRate,
    this.sleep,
    this.activeEnergy,
    this.steps,
    this.hasWearableSource = false,
  });

  final IsoDay day;

  /// SDNN in milliseconds, from `HKQuantityTypeIdentifierHeartRateVariabilitySDNN`.
  final double? hrv;

  /// Beats per minute.
  final double? restingHeartRate;

  final SleepSummary? sleep;

  /// Kilocalories from `HKQuantityTypeIdentifierActiveEnergyBurned`.
  final double? activeEnergy;

  final double? steps;

  /// True when at least one sample in the day came from an Apple Watch.
  final bool hasWearableSource;

  factory DailySnapshot.fromJson(Map<String, dynamic> json) => DailySnapshot(
        day: json['day'] as String,
        hrv: (json['hrv'] as num?)?.toDouble(),
        restingHeartRate: (json['restingHeartRate'] as num?)?.toDouble(),
        sleep: json['sleep'] == null
            ? null
            : SleepSummary.fromJson(json['sleep'] as Map<String, dynamic>),
        activeEnergy: (json['activeEnergy'] as num?)?.toDouble(),
        steps: (json['steps'] as num?)?.toDouble(),
        hasWearableSource: json['hasWearableSource'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'day': day,
        'hrv': hrv,
        'restingHeartRate': restingHeartRate,
        'sleep': sleep?.toJson(),
        'activeEnergy': activeEnergy,
        'steps': steps,
        'hasWearableSource': hasWearableSource,
      };

  /// Projects a snapshot onto a single scalar for the given metric key.
  ///
  /// Centralised so the engine, charts and cards can never disagree about what
  /// "sleep duration" means.
  double? readMetric(MetricKey key) {
    switch (key) {
      case MetricKey.hrv:
        return hrv;
      case MetricKey.restingHeartRate:
        return restingHeartRate;
      case MetricKey.sleepDuration:
        return sleep == null ? null : sleep!.asleepMinutes / 60;
      case MetricKey.sleepEfficiency:
        final efficiency = sleep?.efficiency;
        return efficiency == null ? null : efficiency * 100;
      case MetricKey.activeEnergy:
        return activeEnergy;
      case MetricKey.steps:
        return steps;
    }
  }
}

class HealthSeries {
  const HealthSeries({
    required this.from,
    required this.to,
    required this.days,
    required this.syncedAt,
  });

  final IsoDay from;
  final IsoDay to;
  final List<DailySnapshot> days;
  final String syncedAt;

  factory HealthSeries.fromJson(Map<String, dynamic> json) => HealthSeries(
        from: json['from'] as String,
        to: json['to'] as String,
        days: (json['days'] as List<dynamic>)
            .map((d) => DailySnapshot.fromJson(d as Map<String, dynamic>))
            .toList(),
        syncedAt: json['syncedAt'] as String,
      );

  Map<String, dynamic> toJson() => {
        'from': from,
        'to': to,
        'days': days.map((d) => d.toJson()).toList(),
        'syncedAt': syncedAt,
      };
}
