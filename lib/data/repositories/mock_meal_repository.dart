import '../../domain/entities/meal.dart';
import '../../domain/entities/weekly_log_entry.dart';
import '../../domain/repositories/meal_repository.dart';

class MockMealRepository implements MealRepository {
  static const _weeklyCalories = [1900, 1750, 2100, 1680, 1820, 2050, 1580];
  static const _weeklyLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  List<Meal> initialMeals() {
    return const [
      Meal(
        id: 1,
        name: 'Breakfast',
        item: 'Oatmeal, blueberries & almonds',
        calories: 320,
        carbs: 48,
        protein: 10,
        fat: 9,
        logged: true,
      ),
      Meal(
        id: 2,
        name: 'Lunch',
        item: 'Grilled chicken salad, olive oil dressing',
        calories: 480,
        carbs: 22,
        protein: 42,
        fat: 20,
        logged: true,
      ),
      Meal(
        id: 3,
        name: 'Dinner',
        item: '',
        calories: 0,
        carbs: 0,
        protein: 0,
        fat: 0,
        logged: false,
      ),
      Meal(
        id: 4,
        name: 'Snacks',
        item: 'Greek yogurt & honey',
        calories: 150,
        carbs: 18,
        protein: 11,
        fat: 3,
        logged: true,
      ),
    ];
  }

  @override
  Meal presetFor(int mealId) {
    return Meal(
      id: mealId,
      name: 'Dinner',
      item: 'Salmon, quinoa & roasted vegetables',
      calories: 540,
      carbs: 38,
      protein: 40,
      fat: 22,
      logged: true,
    );
  }

  @override
  List<WeeklyLogEntry> weeklyLog() {
    return [
      for (var i = 0; i < _weeklyCalories.length; i++)
        WeeklyLogEntry(
          dayLabel: _weeklyLabels[i],
          calories: _weeklyCalories[i],
        ),
    ];
  }
}
