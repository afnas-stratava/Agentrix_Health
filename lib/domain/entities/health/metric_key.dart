/// Canonical telemetry vocabulary.
///
/// Ported from `src/schemas/health.ts`. These keys are the join-key between the
/// HealthKit adapter, the correlation engine and the UI, so they are declared
/// once here and never re-typed as bare strings elsewhere.
enum MetricKey {
  hrv('hrv'),
  restingHeartRate('restingHeartRate'),
  sleepDuration('sleepDuration'),
  sleepEfficiency('sleepEfficiency'),
  activeEnergy('activeEnergy'),
  steps('steps');

  const MetricKey(this.wireName);

  /// Serialised form. Matches the TypeScript enum exactly so payloads written
  /// by either build deserialise in the other.
  final String wireName;

  static MetricKey fromWireName(String value) => MetricKey.values.firstWhere(
        (k) => k.wireName == value,
        orElse: () => throw ArgumentError.value(value, 'value', 'Unknown MetricKey'),
      );
}

/// Direction in which a metric moving *up* is clinically desirable.
enum MetricPolarity { higherIsBetter, lowerIsBetter }

const Map<MetricKey, MetricPolarity> metricPolarity = {
  MetricKey.hrv: MetricPolarity.higherIsBetter,
  MetricKey.restingHeartRate: MetricPolarity.lowerIsBetter,
  MetricKey.sleepDuration: MetricPolarity.higherIsBetter,
  MetricKey.sleepEfficiency: MetricPolarity.higherIsBetter,
  MetricKey.activeEnergy: MetricPolarity.higherIsBetter,
  MetricKey.steps: MetricPolarity.higherIsBetter,
};

class MetricMeta {
  const MetricMeta({
    required this.label,
    required this.short,
    required this.unit,
    required this.precision,
  });

  final String label;
  final String short;
  final String unit;
  final int precision;
}

const Map<MetricKey, MetricMeta> metricMeta = {
  MetricKey.hrv: MetricMeta(
    label: 'Heart Rate Variability',
    short: 'HRV',
    unit: 'ms',
    precision: 0,
  ),
  MetricKey.restingHeartRate: MetricMeta(
    label: 'Resting Heart Rate',
    short: 'RHR',
    unit: 'bpm',
    precision: 0,
  ),
  MetricKey.sleepDuration: MetricMeta(
    label: 'Sleep Duration',
    short: 'Sleep',
    unit: 'h',
    precision: 1,
  ),
  MetricKey.sleepEfficiency: MetricMeta(
    label: 'Sleep Efficiency',
    short: 'Efficiency',
    unit: '%',
    precision: 0,
  ),
  MetricKey.activeEnergy: MetricMeta(
    label: 'Active Energy',
    short: 'Energy',
    unit: 'kcal',
    precision: 0,
  ),
  MetricKey.steps: MetricMeta(
    label: 'Steps',
    short: 'Steps',
    unit: '',
    precision: 0,
  ),
};

enum HealthPermissionState {
  undetermined('undetermined'),
  granted('granted'),
  denied('denied'),
  unavailable('unavailable');

  const HealthPermissionState(this.wireName);

  final String wireName;

  static HealthPermissionState fromWireName(String value) =>
      HealthPermissionState.values.firstWhere(
        (s) => s.wireName == value,
        orElse: () => HealthPermissionState.undetermined,
      );
}
