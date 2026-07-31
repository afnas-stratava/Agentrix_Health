import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import 'chart_style.dart';

/// A week of one measure, as columns — magnitude over a handful of time buckets.
///
/// This is an **emphasis** chart, not a categorical one: every column is the
/// same metric, so they share one hue and the selected day is picked out by a
/// darker step of it. Colouring each day differently would spend the identity
/// channel re-encoding what column height already shows.
///
/// The selected column is directly labelled, so its value is readable without
/// touching anything; tapping moves the selection, which makes every other
/// value reachable too. A tooltip is never the only way to read a number.
class DayColumnChart extends StatelessWidget {
  const DayColumnChart({
    super.key,
    required this.values,
    required this.labels,
    required this.selectedIndex,
    required this.formatValue,
    this.onSelect,
    this.plotHeight = 132,
  });

  /// Null is a day with no data — drawn as an empty band, never as zero.
  final List<double?> values;

  /// One short label per column, e.g. `M T W T F S S`.
  final List<String> labels;

  final int selectedIndex;

  /// Renders the direct label on the selected column, units included.
  final String Function(double value) formatValue;

  final ValueChanged<int>? onSelect;

  /// Height of the plot alone. The widget adds the x-axis band and the callout
  /// on top of this, so the axis labels are never squeezed out.
  final double plotHeight;

  /// Round the top of the scale up to a clean number so the gridline labels are
  /// readable values rather than whatever the maximum happened to be.
  static double _niceCeiling(double raw) {
    if (raw <= 0) return 1;
    final magnitude = _pow10((raw.abs()).floor().toString().length - 1);
    final normalised = raw / magnitude;
    final step = normalised <= 1
        ? 1.0
        : normalised <= 2
        ? 2.0
        : normalised <= 5
        ? 5.0
        : 10.0;
    return step * magnitude;
  }

  static double _pow10(int exponent) {
    var out = 1.0;
    for (var i = 0; i < exponent; i += 1) {
      out *= 10;
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final present = values.whereType<double>().toList();
    if (present.isEmpty) {
      return SizedBox(
        height: plotHeight,
        child: Center(
          child: Text(
            'No data for this week yet',
            style: AppTextStyles.cardMeta.copyWith(fontSize: 12),
          ),
        ),
      );
    }

    final ceiling = _niceCeiling(present.reduce((a, b) => a > b ? a : b));
    final safeIndex = selectedIndex.clamp(0, values.length - 1);
    final selectedValue = values[safeIndex];

    return LayoutBuilder(
      builder: (context, constraints) {
        final band = constraints.maxWidth / values.length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Callout band, reserved whether or not it is occupied, so the plot
            // does not shift as the selection moves.
            SizedBox(
              height: 30,
              child: selectedValue == null
                  ? null
                  : _Callout(
                      band: band,
                      index: safeIndex,
                      count: values.length,
                      maxWidth: constraints.maxWidth,
                      label: formatValue(selectedValue),
                    ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: onSelect == null
                  ? null
                  : (details) {
                      final index = (details.localPosition.dx / band)
                          .floor()
                          .clamp(0, values.length - 1);
                      HapticFeedback.selectionClick();
                      onSelect!(index);
                    },
              child: CustomPaint(
                // A childless CustomPaint sizes itself from `size`, which
                // defaults to zero — and a Column constrains its children
                // loosely on the cross axis, so without this the plot collapses
                // to nothing while the axis labels below it still lay out fine.
                size: Size(constraints.maxWidth, plotHeight),
                painter: _ColumnPainter(
                  values: values,
                  ceiling: ceiling,
                  selectedIndex: safeIndex,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                for (var i = 0; i < labels.length; i += 1)
                  SizedBox(
                    width: band,
                    child: Text(
                      labels[i],
                      textAlign: TextAlign.center,
                      style: AppTextStyles.cardMeta.copyWith(
                        fontSize: 11,
                        fontWeight: i == safeIndex
                            ? FontWeight.w700
                            : FontWeight.w400,
                        color: i == safeIndex
                            ? AppColors.ink
                            : ChartStyle.axisText,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// The direct label on the selected column, kept inside the plot's bounds.
class _Callout extends StatelessWidget {
  const _Callout({
    required this.band,
    required this.index,
    required this.count,
    required this.maxWidth,
    required this.label,
  });

  final double band;
  final int index;
  final int count;
  final double maxWidth;
  final String label;

  @override
  Widget build(BuildContext context) {
    final centre = band * index + band / 2;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          // Measured against the plot width rather than clipped — a label that
          // runs off the edge is worse than one that hugs it.
          left: (centre - 40).clamp(0.0, (maxWidth - 80).clamp(0.0, maxWidth)),
          child: SizedBox(
            width: 80,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.brand600,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  // Set inside a filled mark, so the label takes the light ink
                  // that clears contrast against it.
                  style: AppTextStyles.tag.copyWith(
                    color: AppColors.onBrand,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ColumnPainter extends CustomPainter {
  _ColumnPainter({
    required this.values,
    required this.ceiling,
    required this.selectedIndex,
  });

  final List<double?> values;
  final double ceiling;
  final int selectedIndex;

  @override
  void paint(Canvas canvas, Size size) {
    final band = size.width / values.length;

    // Two recessive hairlines — solid, one step off the surface. Dashed rules
    // read as a threshold when they are only a grid.
    final gridPaint = Paint()
      ..color = ChartStyle.grid
      ..strokeWidth = ChartStyle.gridStroke
      ..style = PaintingStyle.stroke;
    for (final fraction in const [0.0, 0.5, 1.0]) {
      final y = size.height * fraction;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    for (var i = 0; i < values.length; i += 1) {
      final value = values[i];
      if (value == null || value <= 0) continue;

      final isSelected = i == selectedIndex;
      // Cap the thickness and let the leftover band be air; the 2px surface gap
      // is what separates neighbours, not a stroke around each bar.
      final width = (band - ChartStyle.surfaceGap).clamp(
        1.0,
        ChartStyle.barMaxThickness,
      );
      final height = (value / ceiling).clamp(0.0, 1.0) * size.height;
      final left = band * i + (band - width) / 2;

      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(left, size.height - height, width, height),
          // Rounded at the data end, square where it meets the baseline.
          topLeft: const Radius.circular(ChartStyle.barEndRadius),
          topRight: const Radius.circular(ChartStyle.barEndRadius),
        ),
        Paint()
          ..color = isSelected ? ChartStyle.mark : ChartStyle.markContext,
      );
    }
  }

  @override
  bool shouldRepaint(_ColumnPainter old) =>
      old.values != values ||
      old.ceiling != ceiling ||
      old.selectedIndex != selectedIndex;
}
