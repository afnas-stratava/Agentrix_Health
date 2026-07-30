import 'package:agentrix_health/core/stats/stats.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ported from `__tests__/stats.test.ts`.
///
/// Jest's `toBeCloseTo(v, n)` passes when the difference is below `10^-n / 2`,
/// so each tolerance below is that same bound rather than an eyeballed epsilon
/// — otherwise the port would silently loosen the original assertions.
void main() {
  group('pearson', () {
    test('returns 1 for a perfect positive relationship', () {
      expect(pearson([1, 2, 3, 4, 5], [2, 4, 6, 8, 10]), closeTo(1, 0.5e-10));
    });

    test('returns -1 for a perfect inverse relationship', () {
      expect(pearson([1, 2, 3, 4, 5], [10, 8, 6, 4, 2]), closeTo(-1, 0.5e-10));
    });

    test('matches a hand-computed value on non-trivial data', () {
      // Σdxdy = 478, Σdx² = 1240.83, Σdy² = 656 → r = 478/√(1240.83·656) = 0.5298
      final r = pearson([43, 21, 25, 42, 57, 59], [99, 65, 79, 75, 87, 81]);
      expect(r, closeTo(0.5298, 0.5e-4));
    });

    test('is NaN when a series has no variance', () {
      expect(pearson([5, 5, 5, 5], [1, 2, 3, 4]).isNaN, isTrue);
    });

    test('refuses to compute on fewer than 3 points', () {
      expect(pearson([1, 2], [3, 4]).isNaN, isTrue);
    });
  });

  group('correlationPValue', () {
    test('is near zero for a strong correlation over many samples', () {
      expect(correlationPValue(0.9, 50), lessThan(0.0001));
    });

    test('is near one for no correlation', () {
      expect(correlationPValue(0, 30), closeTo(1, 0.5e-6));
    });

    test('matches the t-distribution at a known point', () {
      // r = 0.5, n = 20 → t = 2.4495, df = 18 → two-tailed p = 0.02502
      expect(correlationPValue(0.5, 20), closeTo(0.025, 0.5e-3));
    });

    test('treats an under-powered sample as non-significant', () {
      expect(correlationPValue(0.99, 3), 1);
    });

    test('is symmetric in the sign of r', () {
      expect(
        correlationPValue(0.62, 25),
        closeTo(correlationPValue(-0.62, 25), 0.5e-12),
      );
    });
  });

  group('classifyStrength', () {
    test('rejects a high r on a small sample', () {
      // The whole point: 0.8 across 6 days is noise, not a finding.
      expect(
        classifyStrength(0.8, correlationPValue(0.8, 6), 6),
        CorrelationStrength.none,
      );
    });

    test('rejects anything that fails the significance gate', () {
      expect(classifyStrength(0.7, 0.06, 20), CorrelationStrength.none);
    });

    test('grades a significant, well-powered correlation', () {
      expect(classifyStrength(0.65, 0.001, 40), CorrelationStrength.strong);
      expect(classifyStrength(0.45, 0.004, 40), CorrelationStrength.moderate);
      expect(classifyStrength(0.3, 0.04, 40), CorrelationStrength.weak);
    });
  });

  group('pairSeries', () {
    test('drops indices where either side is missing', () {
      final paired = pairSeries([1, null, 3, 4], [5, 6, null, 8]);
      expect(paired.x, [1, 4]);
      expect(paired.y, [5, 8]);
    });

    test('shifts x backwards by the lag so x[t-1] pairs with y[t]', () {
      final paired = pairSeries([10, 20, 30, 40], [1, 2, 3, 4], 1);
      expect(paired.x, [10, 20, 30]);
      expect(paired.y, [2, 3, 4]);
    });

    test('excludes non-finite values', () {
      final paired = pairSeries([double.nan, 2], [1, 2]);
      expect(paired.x, [2]);
    });
  });

  group('descriptive helpers', () {
    test('computes the sample standard deviation with n-1', () {
      // Σ(x−x̄)² = 8 over 5 points → 8/(n−1) = 2 → sample SD = √2 = 1.41421…
      // (the population SD, dividing by n, would be 1.26491 — the distinction
      // matters because baselines here are samples, not populations)
      expect(stdDev([2, 4, 4, 4, 6]), closeTo(1.4142135, 0.5e-6));
    });

    test('returns a zero z-score when the baseline has no spread', () {
      expect(zScore(10, [5, 5, 5]), 0);
    });

    test('signs the slope by direction', () {
      expect(linearSlope([1, 2, 3, 4, 5]), closeTo(1, 0.5e-10));
      expect(linearSlope([5, 4, 3, 2, 1]), closeTo(-1, 0.5e-10));
    });

    test('guards percentChange against a zero baseline', () {
      expect(percentChange(0, 50), 0);
      expect(percentChange(50, 60), closeTo(20, 0.5e-10));
    });

    test(
      'smooths a dense series and blanks positions with too few neighbours',
      () {
        // Window 3 needs at least 2 of the 3 surrounding values to be present.
        final result = rollingMean([2, 4, 6, null, null, null, 8], 3);

        expect(result[1], closeTo(4, 0.5e-10)); // (2+4+6)/3
        expect(result[4], isNull); // isolated inside the gap
        expect(result[6], isNull); // only itself at the edge of the gap
      },
    );
  });
}
