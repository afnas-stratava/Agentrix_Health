import 'cycle_phase.dart';

class CycleDay {
  const CycleDay({
    required this.dayNumber,
    required this.phase,
    required this.isToday,
  });

  final int dayNumber;
  final CyclePhaseType phase;
  final bool isToday;
}
