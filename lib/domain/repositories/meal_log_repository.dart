import '../../core/util/iso_day.dart';
import '../entities/nutrition/meal_entry.dart';

/// Persistence for the food log and the day's hydration.
///
/// Hydration is a running millilitre total per day rather than a list of
/// entries: nobody wants to log four individual glasses of water, and the only
/// question the analyser asks of it is "how much, that day".
abstract class MealLogRepository {
  Future<List<MealEntry>> loadMeals();

  Future<void> saveMeals(List<MealEntry> meals);

  Future<Map<IsoDay, int>> loadHydration();

  Future<void> saveHydration(Map<IsoDay, int> hydration);

  Future<void> clear();
}
