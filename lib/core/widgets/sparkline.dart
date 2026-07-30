import 'package:flutter/material.dart';

/// Mirrors `src/components/health/Sparkline.tsx`, as a [CustomPainter] instead
/// of SVG.
///
/// Missing days are real information — a gap means "no data", not "zero" — so
/// the line is drawn as disjoint segments and a week off the watch renders as a
/// break rather than a plunge to the axis.
class Sparkline extends StatelessWidget {
  const Sparkline({
    super.key,
    required this.values,
    required this.color,
    this.height = 30,
    this.filled = false,
    this.strokeWidth = 2,
    this.showLastPoint = true,
  });

  final List<double?> values;
  final Color color;
  final double height;
  final bool filled;
  final double strokeWidth;
  final bool showLastPoint;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _SparklinePainter(
          values: values,
          color: color,
          filled: filled,
          strokeWidth: strokeWidth,
          showLastPoint: showLastPoint,
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({
    required this.values,
    required this.color,
    required this.filled,
    required this.strokeWidth,
    required this.showLastPoint,
  });

  final List<double?> values;
  final Color color;
  final bool filled;
  final double strokeWidth;
  final bool showLastPoint;

  @override
  void paint(Canvas canvas, Size size) {
    final present = values
        .whereType<double>()
        .where((v) => v.isFinite)
        .toList();
    if (present.length < 2 || values.length < 2) return;

    final min = present.reduce((a, b) => a < b ? a : b);
    final max = present.reduce((a, b) => a > b ? a : b);
    // A flat series would divide by zero; give it a nominal band so it renders
    // as a centred horizontal line.
    var span = max - min;
    if (span == 0) span = max.abs() * 0.1;
    if (span == 0) span = 1;

    final pad = strokeWidth;
    final usableHeight = size.height - pad * 2;
    final stepX = size.width / (values.length - 1);

    final points = <Offset?>[
      for (var i = 0; i < values.length; i += 1)
        if (values[i] == null || !values[i]!.isFinite)
          null
        else
          Offset(
            i * stepX,
            pad + usableHeight - ((values[i]! - min) / span) * usableHeight,
          ),
    ];

    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Each contiguous run is its own path, which is what keeps gaps visible.
    final runs = <List<Offset>>[];
    var current = <Offset>[];
    for (final point in points) {
      if (point == null) {
        if (current.length >= 2) runs.add(current);
        current = <Offset>[];
      } else {
        current.add(point);
      }
    }
    if (current.length >= 2) runs.add(current);
    if (runs.isEmpty) return;

    if (filled) {
      // Only the longest run gets a fill, so a gap never gets a misleading
      // shaded floor beneath it.
      final longest = runs.reduce((a, b) => b.length > a.length ? b : a);
      final area = Path()..moveTo(longest.first.dx, longest.first.dy);
      for (final point in longest.skip(1)) {
        area.lineTo(point.dx, point.dy);
      }
      area
        ..lineTo(longest.last.dx, size.height)
        ..lineTo(longest.first.dx, size.height)
        ..close();

      canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              color.withValues(alpha: 0.28),
              color.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
      );
    }

    for (final run in runs) {
      final path = Path()..moveTo(run.first.dx, run.first.dy);
      for (final point in run.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, stroke);
    }

    if (showLastPoint) {
      final last = runs.last.last;
      canvas.drawCircle(last, strokeWidth + 1, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.color != color ||
      old.filled != filled ||
      old.strokeWidth != strokeWidth ||
      old.showLastPoint != showLastPoint ||
      !identical(old.values, values);
}
