import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../domain/entities/labs/biomarker.dart';
import 'biomarker_table.dart';

/// A flagged analyte shown against the interval it was judged on.
///
/// The bar is the argument the screen is making: the lab's own interval is the
/// wide band, the optimal band sits inside it, and the dot is where the value
/// actually landed. A value can be inside the wide band and outside the narrow
/// one, and that gap is the only thing worth looking at.
class BiomarkerRangeRow extends StatelessWidget {
  const BiomarkerRangeRow({
    super.key,
    required this.biomarker,
    required this.isLast,
  });

  final Biomarker biomarker;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final colour = flagColour(biomarker.flag);
    final rangeLabel = _rangeLabel(biomarker);
    final axis = _axisFor(biomarker);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space4,
        vertical: AppSpacing.space4,
      ),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: AppColors.hairline, width: 1),
              ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: AppSpacing.space3,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      biomarker.displayName,
                      style: AppTextStyles.cardTitle.copyWith(fontSize: 15),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      rangeLabel ??
                          (biomarker.range.source == ReferenceSource.lab
                              ? 'Against your lab’s own interval'
                              : 'Against our reference interval'),
                      style: AppTextStyles.cardBody.copyWith(
                        fontSize: 12,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    spacing: 4,
                    children: [
                      Text(
                        biomarker.valueLabel,
                        style: AppTextStyles.metricSmall.copyWith(
                          fontSize: 21,
                          color: colour,
                        ),
                      ),
                      Text(
                        biomarker.unit,
                        style: AppTextStyles.cardBody.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  _FlagPill(label: biomarker.flag.label, colour: colour),
                ],
              ),
            ],
          ),
          if (axis != null) ...[
            const SizedBox(height: AppSpacing.space3),
            _RangeBar(biomarker: biomarker, axis: axis, marker: colour),
          ],
        ],
      ),
    );
  }
}

class _FlagPill extends StatelessWidget {
  const _FlagPill({required this.label, required this.colour});

  final String label;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.09),
        border: Border.all(color: colour.withValues(alpha: 0.32)),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: AppTextStyles.tag.copyWith(
          fontSize: 11,
          letterSpacing: 0,
          color: colour,
        ),
      ),
    );
  }
}

/// The plotted window. Wider than the reference interval so a value sitting
/// just outside it still has somewhere to be drawn.
typedef _Axis = ({double min, double max});

_Axis? _axisFor(Biomarker biomarker) {
  final range = biomarker.range;
  final bounds = <double>[
    ?range.low,
    ?range.high,
    ?range.optimalLow,
    ?range.optimalHigh,
  ];
  // A value on its own has no interval to be plotted against.
  if (bounds.isEmpty) return null;

  var low = bounds.reduce(math.min);
  var high = bounds.reduce(math.max);
  low = math.min(low, biomarker.value);
  high = math.max(high, biomarker.value);

  // A one-sided ceiling ("< 3 mg/L") reads as a ceiling only if the axis starts
  // at zero — otherwise the bar implies a floor the report never printed.
  if (range.low == null && range.optimalLow == null) {
    low = math.min(low, 0);
  }

  if (high <= low) return null;
  final pad = (high - low) * 0.18;
  return (min: low - pad, max: high + pad);
}

String? _rangeLabel(Biomarker biomarker) {
  final range = biomarker.range;
  final unit = biomarker.unit.isEmpty ? '' : ' ${biomarker.unit}';

  return switch ((range.low, range.high)) {
    (null, null) => null,
    (final low?, null) => '> ${_trim(low)}$unit',
    (null, final high?) => '< ${_trim(high)}$unit',
    (final low?, final high?) => '${_trim(low)}–${_trim(high)}$unit',
  };
}

String _trim(double value) {
  final rounded = (value * 100).round() / 100;
  return rounded == rounded.roundToDouble() ? '${rounded.round()}' : '$rounded';
}

class _RangeBar extends StatelessWidget {
  const _RangeBar({
    required this.biomarker,
    required this.axis,
    required this.marker,
  });

  final Biomarker biomarker;
  final _Axis axis;
  final Color marker;

  @override
  Widget build(BuildContext context) {
    final range = biomarker.range;
    final hasReference = range.low != null || range.high != null;
    final hasOptimal = range.optimalLow != null || range.optimalHigh != null;

    double at(double value) =>
        ((value - axis.min) / (axis.max - axis.min)).clamp(0.0, 1.0);

    return SizedBox(
      height: 10,
      child: CustomPaint(
        painter: _RangeBarPainter(
          reference: hasReference
              ? (
                  start: at(range.low ?? axis.min),
                  end: at(range.high ?? axis.max),
                )
              : null,
          optimal: hasOptimal
              ? (
                  start: at(range.optimalLow ?? range.low ?? axis.min),
                  end: at(range.optimalHigh ?? range.high ?? axis.max),
                )
              : null,
          value: at(biomarker.value),
          valueColour: marker,
        ),
      ),
    );
  }
}

typedef _Band = ({double start, double end});

class _RangeBarPainter extends CustomPainter {
  const _RangeBarPainter({
    required this.reference,
    required this.optimal,
    required this.value,
    required this.valueColour,
  });

  final _Band? reference;
  final _Band? optimal;
  final double value;
  final Color valueColour;

  static const double _trackHeight = 5;
  static const double _dotRadius = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final centreY = size.height / 2;
    final top = centreY - _trackHeight / 2;

    void band(double start, double end, Color colour) {
      final left = start * size.width;
      final right = math.max(end * size.width, left + _trackHeight);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, right - left, _trackHeight),
          const Radius.circular(_trackHeight / 2),
        ),
        Paint()..color = colour,
      );
    }

    band(0, 1, AppColors.neutral200);
    if (reference != null) {
      band(
        reference!.start,
        reference!.end,
        AppColors.normal.withValues(alpha: 0.32),
      );
    }
    if (optimal != null) {
      band(optimal!.start, optimal!.end, AppColors.brand400);
    }

    // Keep the dot fully on the track at either extreme.
    final dotX = (value * size.width).clamp(
      _dotRadius,
      size.width - _dotRadius,
    );
    canvas.drawCircle(
      Offset(dotX, centreY),
      _dotRadius,
      Paint()..color = valueColour,
    );
  }

  @override
  bool shouldRepaint(_RangeBarPainter old) =>
      old.reference != reference ||
      old.optimal != optimal ||
      old.value != value ||
      old.valueColour != valueColour;
}
