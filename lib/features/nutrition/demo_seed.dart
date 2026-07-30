import '../../core/util/iso_day.dart';
import '../../domain/entities/nutrition/food_definition.dart';
import '../../domain/entities/nutrition/meal_entry.dart';
import 'food_database.dart';

/// A week of plausible eating, used to seed a first run.
///
/// This exists so the weekly pattern analyser has something to find on the very
/// first launch — an empty log correctly reports "not enough data", which is the
/// honest answer and a useless first impression.
///
/// The week is *composed to contain a finding*: added sugar clears its ceiling on
/// four of the seven days, driven by chai, lassi, cola and a dessert, which is
/// exactly the "high sugar 4 days this week" shape the product promises. Fibre
/// and protein are deliberately adequate so the sugar pattern is the headline
/// rather than one of five competing complaints.
///
/// Every entry is marked [MealSource.seed], so the UI can label it and the user
/// can clear it in one tap from Profile.
class _SeedMeal {
  const _SeedMeal(this.slot, this.hour, this.foodIds);

  final MealSlot slot;
  final int hour;

  /// Food-table ids; a `null` lookup is skipped rather than faked.
  final List<String> foodIds;
}

/// Day 0 is today. Sugar-heavy days are 1, 3, 4 and 6 days ago.
const Map<int, List<_SeedMeal>> _week = {
  6: [
    _SeedMeal(MealSlot.breakfast, 8, ['idli', 'sambar', 'filter-coffee']),
    _SeedMeal(MealSlot.lunch, 13, ['dal-tadka', 'roti', 'mixed-sabzi']),
    _SeedMeal(MealSlot.snack, 17, ['masala-chai', 'gulab-jamun']),
    _SeedMeal(MealSlot.dinner, 20, ['chicken-tikka', 'greek-salad']),
  ],
  5: [
    _SeedMeal(MealSlot.breakfast, 8, ['oats-porridge', 'banana']),
    _SeedMeal(MealSlot.lunch, 13, ['chole', 'brown-rice']),
    _SeedMeal(MealSlot.dinner, 20, ['grilled-chicken-salad']),
  ],
  4: [
    // The filter coffee is what carries this day over the sugar ceiling — the
    // lassi alone lands just under it, and the point of the seed is that four
    // days clear it.
    _SeedMeal(MealSlot.breakfast, 9, [
      'masala-dosa',
      'coconut-chutney',
      'filter-coffee',
    ]),
    _SeedMeal(MealSlot.lunch, 13, ['rajma', 'plain-rice']),
    _SeedMeal(MealSlot.snack, 16, ['sweet-lassi', 'samosa']),
    _SeedMeal(MealSlot.dinner, 21, ['paneer-tikka', 'roti']),
  ],
  3: [
    _SeedMeal(MealSlot.breakfast, 8, ['boiled-eggs', 'avocado-toast']),
    _SeedMeal(MealSlot.lunch, 13, ['sambar', 'curd-rice']),
    _SeedMeal(MealSlot.snack, 17, ['cola', 'chocolate-bar']),
    _SeedMeal(MealSlot.dinner, 20, ['fish-curry', 'brown-rice']),
  ],
  2: [
    _SeedMeal(MealSlot.breakfast, 8, ['greek-yoghurt', 'guava']),
    _SeedMeal(MealSlot.lunch, 14, ['lentil-soup', 'hummus-pita']),
    _SeedMeal(MealSlot.dinner, 20, ['tandoori-chicken', 'mixed-sabzi']),
  ],
  1: [
    _SeedMeal(MealSlot.breakfast, 9, ['aloo-paratha', 'masala-chai']),
    _SeedMeal(MealSlot.lunch, 13, ['chicken-biryani', 'raita']),
    _SeedMeal(MealSlot.snack, 17, ['ice-cream']),
    _SeedMeal(MealSlot.dinner, 21, ['palak-paneer', 'roti']),
  ],
  0: [
    _SeedMeal(MealSlot.breakfast, 8, ['oats-porridge', 'almonds']),
    _SeedMeal(MealSlot.lunch, 13, ['dal-tadka', 'roti', 'cooked-spinach']),
  ],
};

/// Portions that need to be more than one to be realistic — nobody eats a
/// single roti with a bowl of dal.
const Map<String, double> _portions = {'roti': 2};

List<MealEntry> demoMealSeed({DateTime? now}) {
  final today = now ?? DateTime.now();
  final out = <MealEntry>[];

  // Ordered oldest-first so ids and the list read chronologically.
  final offsets = _week.keys.toList()..sort((a, b) => b.compareTo(a));

  for (final offset in offsets) {
    final date = addDays(today, -offset);
    for (final seed in _week[offset]!) {
      final foods = seed.foodIds
          .map(findFood)
          .whereType<FoodDefinition>()
          .map(
            (definition) => LoggedFood.fromDefinition(
              definition,
              portions: _portions[definition.id] ?? 1,
            ),
          )
          .toList();

      if (foods.isEmpty) continue;

      // A seeded lunch must not be timestamped in the future on the current day,
      // or the "last meal hour" check reads a meal that has not happened.
      if (offset == 0 && seed.hour > today.hour) continue;

      out.add(
        MealEntry(
          id: 'seed-${toIsoDay(date)}-${seed.slot.wireName}',
          day: toIsoDay(date),
          loggedAt: DateTime(
            date.year,
            date.month,
            date.day,
            seed.hour,
            15,
          ),
          slot: seed.slot,
          source: MealSource.seed,
          foods: foods,
        ),
      );
    }
  }

  return out;
}

/// Hydration to match — short of target on the days the sugar was high, which
/// is both realistic and gives the hydration pattern something to say.
Map<IsoDay, int> demoHydrationSeed({DateTime? now}) {
  final today = now ?? DateTime.now();
  const byOffset = {6: 2100, 5: 2600, 4: 1500, 3: 1400, 2: 2500, 1: 1600, 0: 900};
  return {
    for (final entry in byOffset.entries)
      toIsoDay(addDays(today, -entry.key)): entry.value,
  };
}
