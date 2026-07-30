import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Mark specs and the on-canvas chart palette.
///
/// Scope: figures that sit on the **white card surface**. The readiness hero
/// paints on the deep-green gradient and carries its own lighter, warmer band
/// colours — see `readiness_hero.dart`; do not reach for these there.
///
/// Two rules drive every value here.
///
/// **Marks carry the data colour; text never does.** Values, labels and axis
/// ticks wear ink/muted/faint. Identity comes from the coloured mark beside the
/// label, never from tinting the label itself.
///
/// **Contrast is measured, not eyeballed.** Ratios are against `#FFFFFF`:
///
/// | token    | vs surface | usable as a mark? |
/// | -------- | ---------- | ----------------- |
/// | brand600 | 6.54:1     | yes — the default |
/// | brand500 | 4.62:1     | yes               |
/// | brand400 | 2.92:1     | context only      |
/// | lime     | **1.33:1** | **no**            |
///
/// That last row is the load-bearing one: the lime accent is a CTA fill that
/// carries ink, and as a bar or line on white it all but disappears. Every mark
/// on a card therefore comes from the forest-green ramp.
abstract final class ChartStyle {
  /// Cap bar thickness rather than filling the slot — the band's leftover is
  /// air, and it is what keeps a week of columns from reading as a solid block.
  static const double barMaxThickness = 24;

  /// Rounded at the data end, square where it meets the baseline.
  static const double barEndRadius = 4;

  /// The surface-coloured gap that separates touching marks. White does the
  /// separating; a stroke around each bar would add ink that is not data.
  static const double surfaceGap = 2;

  static const double gridStroke = 1;

  /// The single-series default, and the emphasised mark in an emphasis chart.
  static const Color mark = AppColors.brand600;

  /// Context marks in an emphasis chart — "pick one out, let the rest recede".
  /// Same hue as [mark], so the pair reads as one ordered ramp rather than as
  /// two competing categories.
  static const Color markContext = AppColors.brand400;

  /// One step off the surface, hairline, solid. Never dashed — a dashed rule
  /// reads as a threshold or a forecast when it is only a grid.
  static const Color grid = AppColors.hairline;

  static const Color axisText = AppColors.faint;
}
