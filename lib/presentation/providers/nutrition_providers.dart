import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/secrets.dart';
import '../../core/util/iso_day.dart';
import '../../data/nutrition/gemini_meal_vision.dart';
import '../../data/repositories/prefs_meal_log_repository.dart';
import '../../domain/entities/nutrition/food_definition.dart';
import '../../domain/entities/nutrition/macros.dart';
import '../../domain/entities/nutrition/meal_entry.dart';
import '../../domain/entities/nutrition/nutrition_targets.dart';
import '../../domain/repositories/meal_log_repository.dart';
import '../../features/nutrition/demo_seed.dart';
import '../../features/nutrition/patterns.dart';
import '../../features/nutrition/targets.dart';
import 'cycle_phase_provider.dart';
import 'health_providers.dart';
import 'labs_providers.dart';
import 'user_profile_provider.dart';

final mealLogRepositoryProvider = Provider<MealLogRepository>(
  (ref) => PrefsMealLogRepository(),
);

/// Reads meal photos, or null when no key is configured.
///
/// Null rather than a no-op implementation on purpose: the log screen checks
/// for it and skips the whole photo-reading affordance, so an unconfigured
/// build never shows a spinner for a call it cannot make.
final mealVisionProvider = Provider<GeminiMealVision?>((ref) {
  const vision = GeminiMealVision(apiKey: geminiApiKey);
  return vision.isConfigured ? vision : null;
});

/// The food log.
///
/// Seeded on first run only — [MealLogNotifier.clear] writes an explicit empty
/// marker so a user who clears the demo data does not get it back on relaunch.
class MealLogState {
  const MealLogState({
    required this.meals,
    required this.hydration,
    this.loading = true,
  });

  final List<MealEntry> meals;
  final Map<IsoDay, int> hydration;
  final bool loading;

  MealLogState copyWith({
    List<MealEntry>? meals,
    Map<IsoDay, int>? hydration,
    bool? loading,
  }) => MealLogState(
    meals: meals ?? this.meals,
    hydration: hydration ?? this.hydration,
    loading: loading ?? this.loading,
  );

  List<MealEntry> forDay(IsoDay day) {
    final out = meals.where((m) => m.day == day).toList()
      ..sort((a, b) => a.loggedAt.compareTo(b.loggedAt));
    return out;
  }
}

class MealLogNotifier extends Notifier<MealLogState> {
  @override
  MealLogState build() {
    _hydrate();
    return const MealLogState(meals: [], hydration: {});
  }

  MealLogRepository get _repository => ref.read(mealLogRepositoryProvider);

  Future<void> _hydrate() async {
    final meals = await _repository.loadMeals();
    final hydration = await _repository.loadHydration();

    if (meals.isEmpty && hydration.isEmpty) {
      final seeded = demoMealSeed();
      final seededHydration = demoHydrationSeed();
      await _repository.saveMeals(seeded);
      await _repository.saveHydration(seededHydration);
      state = MealLogState(
        meals: seeded,
        hydration: seededHydration,
        loading: false,
      );
      return;
    }

    state = MealLogState(meals: meals, hydration: hydration, loading: false);
  }

  Future<void> add(MealEntry meal) async {
    final next = [...state.meals, meal];
    state = state.copyWith(meals: next);
    await _repository.saveMeals(next);
  }

  Future<void> remove(String id) async {
    final next = state.meals.where((m) => m.id != id).toList();
    state = state.copyWith(meals: next);
    await _repository.saveMeals(next);
  }

  Future<void> addWater(int ml, {IsoDay? day}) async {
    final key = day ?? toIsoDay(DateTime.now());
    final current = state.hydration[key] ?? 0;
    final next = {...state.hydration, key: (current + ml).clamp(0, 20000)};
    state = state.copyWith(hydration: next);
    await _repository.saveHydration(next);
  }

  /// Clears the log without re-seeding, so "reset" means reset.
  Future<void> clear() async {
    state = const MealLogState(meals: [], hydration: {}, loading: false);
    await _repository.saveMeals(const []);
    await _repository.saveHydration(const {});
  }

  /// Restores the demo week — the counterpart to [clear] for a repeat demo.
  Future<void> reseed() async {
    final seeded = demoMealSeed();
    final seededHydration = demoHydrationSeed();
    state = MealLogState(
      meals: seeded,
      hydration: seededHydration,
      loading: false,
    );
    await _repository.saveMeals(seeded);
    await _repository.saveHydration(seededHydration);
  }
}

final mealLogProvider = NotifierProvider<MealLogNotifier, MealLogState>(
  MealLogNotifier.new,
);

final todayIsoDayProvider = Provider<IsoDay>(
  (ref) => toIsoDay(DateTime.now()),
);

final todayMealsProvider = Provider<List<MealEntry>>(
  (ref) => ref.watch(mealLogProvider).forDay(ref.watch(todayIsoDayProvider)),
);

/// What the user has actually eaten today — the denominator for every "left
/// today" figure in the app.
final consumedTodayProvider = Provider<Macros>(
  (ref) => sumMacros(ref.watch(todayMealsProvider).map((m) => m.macros)),
);

final hydrationTodayProvider = Provider<int>((ref) {
  final log = ref.watch(mealLogProvider);
  return log.hydration[ref.watch(todayIsoDayProvider)] ?? 0;
});

/// Whether the user has declared today a cheat day. Never inferred.
final cheatDayProvider = NotifierProvider<CheatDayNotifier, bool>(
  CheatDayNotifier.new,
);

class CheatDayNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;

  void set(bool value) => state = value;
}

/// Daily targets.
///
/// Falls back to population-typical body composition when the user has not
/// entered height and weight, so the arithmetic is demonstrable from the first
/// launch. The brief labels that assumption as a caveat rather than hiding it.
final nutritionTargetsProvider = Provider<NutritionTargets?>((ref) {
  final profile = withAssumedBodyComposition(ref.watch(userProfileProvider));
  final series = ref.watch(healthSeriesProvider).valueOrNull ?? const [];

  return computeTargets(
    profile: profile,
    series: series,
    phase: ref.watch(menstrualPhaseProvider),
    isCheatDay: ref.watch(cheatDayProvider),
  );
});

final weeklyNutritionProvider = Provider<WeeklyNutritionSummary>((ref) {
  final log = ref.watch(mealLogProvider);
  return analyseWeek(
    meals: log.meals,
    hydration: log.hydration,
    targets: ref.watch(nutritionTargetsProvider),
  );
});

/// The food tags today's plan wants floated up, shared by the brief's examples
/// and the dish ranker so the two can never disagree about the day's focus.
final focusTagsProvider = Provider<List<FoodTag>>((ref) {
  final phase = ref.watch(menstrualPhaseProvider);
  final tags = <FoodTag>[];

  final report = ref.watch(latestLabReportProvider);
  for (final biomarker in report?.flagged ?? const []) {
    switch (biomarker.code?.wireName) {
      case 'ferritin' || 'hemoglobin' || 'transferrinSaturation':
        tags.addAll([FoodTag.ironRich, FoodTag.vitaminCRich]);
      case 'hba1c' || 'fastingGlucose' || 'fastingInsulin':
        tags.addAll([FoodTag.highFibre, FoodTag.highProtein, FoodTag.lowCarb]);
      case 'ldl' || 'triglycerides' || 'totalCholesterol':
        tags.addAll([FoodTag.highFibre, FoodTag.omega3Rich]);
      case 'vitaminD':
        tags.add(FoodTag.omega3Rich);
      case 'vitaminB12':
        tags.add(FoodTag.highProtein);
    }
  }

  if (phase != null) {
    tags.addAll(ref.watch(phaseGuidanceProvider)?.favourTags ?? const []);
  }

  if (tags.isEmpty) tags.addAll([FoodTag.highProtein, FoodTag.highFibre]);

  return tags.toSet().toList();
});
