import '../entities/cycle_day.dart';

abstract interface class CycleRepository {
  List<CycleDay> monthDays({required int totalDays, required int today});
  String phaseInsight();
  int wellnessScore();
  String wellnessInsight();
}
