import '../entities/meal.dart';
import '../entities/weekly_log_entry.dart';

abstract interface class MealRepository {
  List<Meal> initialMeals();

  /// The preset meal logged when the demo "Log a meal" action fires for
  /// the given [mealId] (dinner in the reference design).
  Meal presetFor(int mealId);

  List<WeeklyLogEntry> weeklyLog();
}
