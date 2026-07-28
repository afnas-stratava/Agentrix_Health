import '../../domain/entities/cycle_day.dart';
import '../../domain/entities/cycle_phase.dart';
import '../../domain/repositories/cycle_repository.dart';

class MockCycleRepository implements CycleRepository {
  @override
  List<CycleDay> monthDays({required int totalDays, required int today}) {
    return [
      for (var day = 1; day <= totalDays; day++)
        CycleDay(
          dayNumber: day,
          phase: CyclePhaseType.forDay(day),
          isToday: day == today,
        ),
    ];
  }

  @override
  String phaseInsight() =>
      'Energy is high today — a great day for a harder workout.';

  @override
  int wellnessScore() => 82;

  @override
  String wellnessInsight() =>
      'Recovery is strong — solid day to push training.';
}
