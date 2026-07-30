import 'package:flutter/material.dart';

/// Design tokens mirrored from the React Native app's palette
/// (`src/theme/colors.ts` + `tailwind.config.js`).
///
/// That file is the source of truth for the brand; this is its Dart mirror.
/// Keep the two in lockstep — a value changed there has to be changed here.
///
/// The system is a near-white canvas with a green cast, deep forest green as
/// the brand, and a lime accent that is **always paired with [ink], never with
/// white text**.
abstract final class AppColors {
  // ---------------------------------------------------------------------
  // Canvas and ink
  // ---------------------------------------------------------------------

  /// Near-white canvas with a green cast.
  static const Color canvas = Color(0xFFF4FAF1);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color hairline = Color(0xFFE0ECDA);

  static const Color ink = Color(0xFF13281C);
  static const Color muted = Color(0xFF5C6E63);
  static const Color faint = Color(0xFF8D9E92);

  // ---------------------------------------------------------------------
  // Brand — deep forest green
  // ---------------------------------------------------------------------

  /// Deliberately darker and less saturated than [optimal], so "brand" and
  /// "this biomarker is healthy" never read as the same signal.
  static const Color brand = Color(0xFF226A44);
  static const Color brandDeep = Color(0xFF0F2E1E);
  static const Color brandLight = Color(0xFF4FA873);

  static const Color brand50 = Color(0xFFEFF8F1);
  static const Color brand100 = Color(0xFFD9EEDF);
  static const Color brand200 = Color(0xFFB4DDC1);
  static const Color brand300 = Color(0xFF84C69C);
  static const Color brand400 = Color(0xFF4FA873);
  static const Color brand500 = Color(0xFF2E8455);
  static const Color brand600 = Color(0xFF226A44);
  static const Color brand700 = Color(0xFF1B5436);
  static const Color brand800 = Color(0xFF16412B);
  static const Color brand900 = Color(0xFF0F2E1E);

  /// Gradient stops for the deep-green hero card, light to dark.
  static const List<Color> heroGradient = [
    Color(0xFF2E8455),
    Color(0xFF1B5436),
  ];

  // ---------------------------------------------------------------------
  // Lime accent — CTAs, active pills, gauge fill. Always paired with ink.
  // ---------------------------------------------------------------------

  static const Color lime = Color(0xFFBFF049);
  static const Color limeSoft = Color(0xFFE8FAC4);
  static const Color limeStrong = Color(0xFFA6D934);

  // ---------------------------------------------------------------------
  // Text and icons that sit on the deep-green hero surface
  // ---------------------------------------------------------------------

  static const Color onBrand = Color(0xFFFFFFFF);
  static const Color onBrandMuted = Color(0xB8FFFFFF); // rgba(255,255,255,0.72)
  static const Color onBrandFaint = Color(0x73FFFFFF); // rgba(255,255,255,0.45)

  // ---------------------------------------------------------------------
  // Semantic status ramp — biomarker flags and metric deltas
  // ---------------------------------------------------------------------

  static const Color optimal = Color(0xFF16A34A);
  static const Color normal = Color(0xFF0EA5E9);
  static const Color borderline = Color(0xFFF59E0B);
  static const Color abnormal = Color(0xFFF97316);
  static const Color critical = Color(0xFFE11D48);

  // ---------------------------------------------------------------------
  // Aliases retained from the earlier "Modernist" token set, repointed at
  // the green system. Kept as members (rather than deleted) so existing call
  // sites re-theme automatically instead of failing to compile — these names
  // are referenced across ~30 files.
  // ---------------------------------------------------------------------

  /// Legacy alias — use [canvas].
  static const Color bg = canvas;

  /// Legacy alias — use [ink].
  static const Color text = ink;

  /// Legacy alias — use [hairline].
  static const Color divider = hairline;

  /// Legacy alias — use [brand].
  static const Color accent = brand;

  /// Legacy alias — use [lime]. The old gold accent is now the lime accent.
  static const Color accent2 = lime;

  // Neutral ramp, re-cast with the green tint of the canvas so greys never
  // read as cold against the brand.
  static const Color neutral100 = Color(0xFFF4FAF1);
  static const Color neutral200 = Color(0xFFE9F2E5);
  static const Color neutral300 = Color(0xFFE0ECDA);
  static const Color neutral400 = Color(0xFF8D9E92);
  static const Color neutral500 = Color(0xFF77897D);
  static const Color neutral600 = Color(0xFF5C6E63);
  static const Color neutral700 = Color(0xFF465549);
  static const Color neutral800 = Color(0xFF2C3F33);
  static const Color neutral900 = Color(0xFF13281C);

  // Brand ramp under the legacy `accent*` names, 1:1 with `brand*`.
  static const Color accent100 = brand100;
  static const Color accent200 = brand200;
  static const Color accent300 = brand300;
  static const Color accent400 = brand400;
  static const Color accent500 = brand500;
  static const Color accent600 = brand600;
  static const Color accent700 = brand700;
  static const Color accent800 = brand800;
  static const Color accent900 = brand900;

  // Lime ramp under the legacy `accent2_*` names. 500 is the canonical
  // accent, 200 the soft tint, 600 the strong variant.
  static const Color accent2_100 = Color(0xFFF4FDE2);
  static const Color accent2_200 = Color(0xFFE8FAC4);
  static const Color accent2_300 = Color(0xFFDBF79C);
  static const Color accent2_400 = Color(0xFFCDF370);
  static const Color accent2_500 = Color(0xFFBFF049);
  static const Color accent2_600 = Color(0xFFA6D934);
  static const Color accent2_700 = Color(0xFF85B120);
  static const Color accent2_800 = Color(0xFF628215);
  static const Color accent2_900 = Color(0xFF3F540D);
}
