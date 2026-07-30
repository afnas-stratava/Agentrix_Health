import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../../features/cycle/menstrual_phase.dart';

/// Phase colours: a validated four-step **ordinal** ramp from the brand hue.
///
/// Ordinal rather than categorical, because the phases are ordered stages —
/// and because the two other options are both wrong. The status ramp
/// (rose/amber/blue) is reserved for good→critical and must never impersonate
/// identity; lime measures 1.33:1 on white and disappears as a mark.
///
/// Assigned dark→light through the cycle so the **period** is the heaviest
/// block on the ring — it is what people look for first — and the long luteal
/// stretch recedes instead of dominating. Verified against the ordinal gates:
/// monotone lightness, every adjacent ΔL ≥ 0.06, single hue (3° spread), and a
/// light end of 4FA873 at 2.92:1 against the surface.
///
/// Ovulation is the one thing colour does *not* carry — it rides a distinct
/// marker shape instead, so the event and the phase are separate channels.
const Map<MenstrualPhaseName, Color> cyclePhaseColor = {
  MenstrualPhaseName.menstrual: AppColors.brand800, // 11.51:1
  MenstrualPhaseName.follicular: AppColors.brand600, // 6.54:1
  MenstrualPhaseName.ovulatory: AppColors.brand500, // 4.62:1
  MenstrualPhaseName.luteal: AppColors.brand400, // 2.92:1
};

const Map<MenstrualPhaseName, String> cyclePhaseShortLabel = {
  MenstrualPhaseName.menstrual: 'Period',
  MenstrualPhaseName.follicular: 'Follicular',
  MenstrualPhaseName.ovulatory: 'Fertile',
  MenstrualPhaseName.luteal: 'Luteal',
};

/// Which phase an arbitrary cycle day falls in.
///
/// Mirrors the boundaries in `computeMenstrualPhase` exactly, and lives in one
/// place so the ring, the legend and the day-detail copy can never paint the
/// same day two different ways.
MenstrualPhaseName phaseForCycleDay({
  required int day,
  required int ovulationDay,
  required int periodDays,
}) {
  if (day <= periodDays) return MenstrualPhaseName.menstrual;
  if (day < ovulationDay - 1) return MenstrualPhaseName.follicular;
  if (day <= ovulationDay + 1) return MenstrualPhaseName.ovulatory;
  return MenstrualPhaseName.luteal;
}

/// One cycle as a ring of day marks, with today called out and ovulation
/// flagged.
///
/// The ring is the form because a cycle *is* cyclical: laid out as a bar chart,
/// day 28 and day 1 end up at opposite ends of the plot when they are in fact
/// adjacent. Position around the circle carries the ordering, which frees
/// colour to carry the phase.
class CycleRing extends StatelessWidget {
  const CycleRing({
    super.key,
    required this.phase,
    required this.periodDays,
    this.diameter = 260,
    this.selectedDay,
    this.onSelectDay,
  });

  final MenstrualPhase phase;

  /// Length of the bleed, which sets where the menstrual arc ends.
  final int periodDays;

  final double diameter;

  /// Defaults to today when null.
  final int? selectedDay;

  final ValueChanged<int>? onSelectDay;

  MenstrualPhaseName _phaseForDay(int day) => phaseForCycleDay(
    day: day,
    ovulationDay: phase.ovulationDay,
    periodDays: periodDays,
  );

  @override
  Widget build(BuildContext context) {
    final active = selectedDay ?? phase.dayOfCycle;
    final length = phase.cycleLengthDays;

    return SizedBox(
      width: diameter,
      height: diameter,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: onSelectDay == null
            ? null
            : (details) {
                // Nearest-mark hit testing by angle. Individual day dots are
                // far below a comfortable tap target, so the whole wedge
                // around each one is live rather than the dot itself.
                final centre = Offset(diameter / 2, diameter / 2);
                final delta = details.localPosition - centre;
                if (delta.distance < diameter * 0.22) return;

                // atan2 measures from three o'clock; the ring starts at twelve.
                var turns =
                    (math.atan2(delta.dy, delta.dx) + math.pi / 2) /
                    (math.pi * 2);
                if (turns < 0) turns += 1;
                final index = (turns * length).round() % length;
                onSelectDay!(index + 1);
              },
        child: CustomPaint(
          size: Size(diameter, diameter),
          painter: _CycleRingPainter(
            cycleLength: length,
            activeDay: active,
            ovulationDay: phase.ovulationDay,
            phaseForDay: _phaseForDay,
            surface: AppColors.surface,
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Cycle day',
                  style: AppTextStyles.cardMeta.copyWith(fontSize: 12),
                ),
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // The view's hero figure: product sans, display size,
                    // proportional figures.
                    Text(
                      '$active',
                      style: AppTextStyles.metricLarge.copyWith(fontSize: 52),
                    ),
                    Text(
                      ' / $length',
                      style: AppTextStyles.cardBody.copyWith(fontSize: 15),
                    ),
                  ],
                ),
                Text(
                  cyclePhaseShortLabel[_phaseForDay(active)]!,
                  style: AppTextStyles.tag.copyWith(
                    fontSize: 11,
                    color: AppColors.brand700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CycleRingPainter extends CustomPainter {
  _CycleRingPainter({
    required this.cycleLength,
    required this.activeDay,
    required this.ovulationDay,
    required this.phaseForDay,
    required this.surface,
  });

  final int cycleLength;
  final int activeDay;
  final int ovulationDay;
  final MenstrualPhaseName Function(int day) phaseForDay;
  final Color surface;

  static const double _dotRadius = 5;
  static const double _activeRadius = 9;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - _activeRadius - 4;

    Offset positionFor(int day) {
      // Day 1 at twelve o'clock, advancing clockwise.
      final turn = (day - 1) / cycleLength;
      final angle = turn * math.pi * 2 - math.pi / 2;
      return centre + Offset(math.cos(angle), math.sin(angle)) * radius;
    }

    for (var day = 1; day <= cycleLength; day += 1) {
      final point = positionFor(day);
      final colour = cyclePhaseColor[phaseForDay(day)]!;
      final isPast = day <= activeDay;

      // Days still to come are the same hue held back, so the ring reads as
      // progress through the cycle as well as a map of it.
      canvas.drawCircle(
        point,
        _dotRadius,
        Paint()..color = isPast ? colour : colour.withValues(alpha: 0.28),
      );
    }

    // Ovulation: a hollow ring, so the event is carried by shape rather than
    // by spending another colour on it.
    if (ovulationDay >= 1 && ovulationDay <= cycleLength) {
      final point = positionFor(ovulationDay);
      canvas.drawCircle(
        point,
        _dotRadius + 4,
        Paint()
          ..color = AppColors.brand700
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    // Today, last so it wins any overlap, with a surface ring keeping it
    // legible against its neighbours.
    //
    // Filled rather than hollow, and deliberately: ovulation already owns the
    // hollow-ring shape, and on a cycle where today *is* ovulation day the two
    // marks land on the same dot. Filled-inside-hollow reads as "today, which
    // is ovulation"; two hollow rings read as a rendering bug.
    final activePoint = positionFor(activeDay);
    canvas.drawCircle(activePoint, _activeRadius + 2, Paint()..color = surface);
    canvas.drawCircle(
      activePoint,
      _activeRadius,
      Paint()..color = cyclePhaseColor[phaseForDay(activeDay)]!,
    );
  }

  @override
  bool shouldRepaint(_CycleRingPainter old) =>
      old.cycleLength != cycleLength ||
      old.activeDay != activeDay ||
      old.ovulationDay != ovulationDay ||
      old.surface != surface;
}
