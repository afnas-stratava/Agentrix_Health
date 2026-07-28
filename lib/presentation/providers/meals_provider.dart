import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/meal.dart';
import 'repository_providers.dart';

class MealsNotifier extends Notifier<List<Meal>> {
  @override
  List<Meal> build() => ref.read(mealRepositoryProvider).initialMeals();

  void logMeal(int mealId) {
    final preset = ref.read(mealRepositoryProvider).presetFor(mealId);
    state = [
      for (final meal in state)
        if (meal.id == mealId) preset else meal,
    ];
  }

  void reset() => state = ref.read(mealRepositoryProvider).initialMeals();
}

final mealsProvider = NotifierProvider<MealsNotifier, List<Meal>>(
  MealsNotifier.new,
);

final todayCaloriesProvider = Provider<int>((ref) {
  return ref
      .watch(mealsProvider)
      .where((m) => m.logged)
      .fold(0, (sum, m) => sum + m.calories);
});

final weeklyLogProvider = Provider(
  (ref) => ref.watch(mealRepositoryProvider).weeklyLog(),
);
