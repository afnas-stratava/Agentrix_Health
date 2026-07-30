import 'dart:math' as math;

/// Small, dependency-free statistics kernel.
///
/// Ported from `src/features/correlation/stats.ts`. Everything here is pure and
/// synchronous so the engine can run on the UI isolate without jank — the
/// working set is at most a few hundred paired observations.

double mean(List<double> values) {
  if (values.isEmpty) return double.nan;
  return values.fold<double>(0, (sum, v) => sum + v) / values.length;
}

double median(List<double> values) {
  if (values.isEmpty) return double.nan;
  final sorted = [...values]..sort();
  final mid = sorted.length ~/ 2;
  return sorted.length.isEven
      ? (sorted[mid - 1] + sorted[mid]) / 2
      : sorted[mid];
}

/// Sample standard deviation (n − 1).
double stdDev(List<double> values) {
  if (values.length < 2) return double.nan;
  final m = mean(values);
  final variance =
      values.fold<double>(0, (sum, v) => sum + (v - m) * (v - m)) /
      (values.length - 1);
  return math.sqrt(variance);
}

double zScore(double value, List<double> baseline) {
  final sd = stdDev(baseline);
  if (!sd.isFinite || sd == 0) return 0;
  return (value - mean(baseline)) / sd;
}

/// Ordinary-least-squares slope in units per day, x being the index.
double linearSlope(List<double> values) {
  final n = values.length;
  if (n < 3) return 0;
  final xMean = (n - 1) / 2;
  final yMean = mean(values);
  var numerator = 0.0;
  var denominator = 0.0;
  for (var i = 0; i < n; i += 1) {
    numerator += (i - xMean) * (values[i] - yMean);
    denominator += (i - xMean) * (i - xMean);
  }
  return denominator == 0 ? 0.0 : numerator / denominator;
}

class PairedSeries {
  const PairedSeries({required this.x, required this.y});

  final List<double> x;
  final List<double> y;
}

/// Pairs two nullable series positionally, dropping any index where either side
/// is missing. [lag] shifts `x` backwards so `x[t − lag]` is compared with
/// `y[t]`, which is how a physiological input is tested against a delayed
/// response (e.g. training load today → HRV tomorrow).
PairedSeries pairSeries(List<double?> xs, List<double?> ys, [int lag = 0]) {
  final x = <double>[];
  final y = <double>[];

  for (var t = lag; t < ys.length; t += 1) {
    final xIndex = t - lag;
    if (xIndex >= xs.length) continue;
    final xv = xs[xIndex];
    final yv = ys[t];
    if (xv == null || yv == null) continue;
    if (!xv.isFinite || !yv.isFinite) continue;
    x.add(xv);
    y.add(yv);
  }

  return PairedSeries(x: x, y: y);
}

double pearson(List<double> x, List<double> y) {
  final n = math.min(x.length, y.length);
  if (n < 3) return double.nan;

  final mx = mean(x);
  final my = mean(y);
  // Deliberately not named `num` as in the TypeScript original — that shadows
  // Dart's built-in `num` type.
  var numerator = 0.0;
  var dx = 0.0;
  var dy = 0.0;

  for (var i = 0; i < n; i += 1) {
    final a = x[i] - mx;
    final b = y[i] - my;
    numerator += a * b;
    dx += a * a;
    dy += b * b;
  }

  final denom = math.sqrt(dx * dy);
  return denom == 0 ? double.nan : numerator / denom;
}

// ---------------------------------------------------------------------------
// Student's t → p-value, via the regularised incomplete beta function.
// A normal approximation is not good enough here: correlation windows are
// routinely 14–30 days, where the t and z tails diverge materially.
// ---------------------------------------------------------------------------

const List<double> _lanczosCoefficients = [
  0.99999999999980993,
  676.5203681218851,
  -1259.1392167224028,
  771.32342877765313,
  -176.61502916214059,
  12.507343278686905,
  -0.13857109526572012,
  9.9843695780195716e-6,
  1.5056327351493116e-7,
];

double _logGamma(double x) {
  // Lanczos approximation, g = 7, n = 9.
  if (x < 0.5) {
    return math.log(math.pi / math.sin(math.pi * x)) - _logGamma(1 - x);
  }

  final z = x - 1;
  var a = _lanczosCoefficients[0];
  final t = z + 7.5;
  for (var i = 1; i < 9; i += 1) {
    a += _lanczosCoefficients[i] / (z + i);
  }

  return 0.5 * math.log(2 * math.pi) +
      (z + 0.5) * math.log(t) -
      t +
      math.log(a);
}

/// Continued-fraction expansion for the incomplete beta (Lentz's method).
double _betaContinuedFraction(double a, double b, double x) {
  const maxIterations = 200;
  const epsilon = 3e-12;
  const tiny = 1e-30;

  final qab = a + b;
  final qap = a + 1;
  final qam = a - 1;

  var c = 1.0;
  var d = 1 - (qab * x) / qap;
  if (d.abs() < tiny) d = tiny;
  d = 1 / d;
  var h = d;

  for (var m = 1; m <= maxIterations; m += 1) {
    final m2 = 2 * m;

    var aa = (m * (b - m) * x) / ((qam + m2) * (a + m2));
    d = 1 + aa * d;
    if (d.abs() < tiny) d = tiny;
    c = 1 + aa / c;
    if (c.abs() < tiny) c = tiny;
    d = 1 / d;
    h *= d * c;

    aa = (-(a + m) * (qab + m) * x) / ((a + m2) * (qap + m2));
    d = 1 + aa * d;
    if (d.abs() < tiny) d = tiny;
    c = 1 + aa / c;
    if (c.abs() < tiny) c = tiny;
    d = 1 / d;

    final delta = d * c;
    h *= delta;

    if ((delta - 1).abs() < epsilon) break;
  }

  return h;
}

/// Regularised incomplete beta I_x(a, b).
double _incompleteBeta(double a, double b, double x) {
  if (x <= 0) return 0;
  if (x >= 1) return 1;

  final front = math.exp(
    _logGamma(a + b) -
        _logGamma(a) -
        _logGamma(b) +
        a * math.log(x) +
        b * math.log(1 - x),
  );

  return x < (a + 1) / (a + b + 2)
      ? (front * _betaContinuedFraction(a, b, x)) / a
      : 1 - (front * _betaContinuedFraction(b, a, 1 - x)) / b;
}

/// Two-tailed p-value for a Pearson r over n paired observations.
double correlationPValue(double r, int n) {
  if (!r.isFinite || n < 4) return 1;
  final absR = math.min(r.abs(), 0.999999);
  final df = n - 2;
  final t = absR * math.sqrt(df / (1 - absR * absR));
  final p = _incompleteBeta(df / 2, 0.5, df / (df + t * t));
  // Double literals, not `1`/`0`: `math.min`/`math.max` are generic over
  // `T extends num`, and int literals here let inference settle on `num`,
  // which will not assign back to a `double` return type.
  return math.min(1.0, math.max(0.0, p));
}

enum CorrelationStrength { none, weak, moderate, strong }

/// Strength is deliberately conservative and gated on significance: an r of
/// 0.6 across five days is noise, and presenting it as a finding is how health
/// apps lose credibility.
CorrelationStrength classifyStrength(double r, double p, int n) {
  if (!r.isFinite || n < 10 || p > 0.05) return CorrelationStrength.none;
  final abs = r.abs();
  if (abs >= 0.6) return CorrelationStrength.strong;
  if (abs >= 0.4) return CorrelationStrength.moderate;
  if (abs >= 0.25) return CorrelationStrength.weak;
  return CorrelationStrength.none;
}

/// Centred rolling mean; positions without a full window return null.
List<double?> rollingMean(List<double?> values, int window) {
  final half = window ~/ 2;
  final required = (window / 2).ceil();

  return List<double?>.generate(values.length, (index) {
    final slice = <double>[];
    for (var i = index - half; i <= index + half; i += 1) {
      if (i < 0 || i >= values.length) continue;
      final v = values[i];
      if (v != null && v.isFinite) slice.add(v);
    }
    return slice.length >= required ? mean(slice) : null;
  });
}

/// Percentage change from [previous] to [current], guarding divide-by-zero.
double percentChange(double previous, double current) {
  if (previous == 0) return 0;
  return ((current - previous) / previous.abs()) * 100;
}

List<double> compact(List<double?> values) =>
    values.whereType<double>().where((v) => v.isFinite).toList();
