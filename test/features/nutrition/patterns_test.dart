import 'package:agentrix_health/core/util/iso_day.dart';
import 'package:agentrix_health/domain/entities/nutrition/food_definition.dart';
import 'package:agentrix_health/domain/entities/nutrition/meal_entry.dart';
import 'package:agentrix_health/domain/entities/nutrition/nutrition_targets.dart';
import 'package:agentrix_health/features/nutrition/demo_seed.dart';
import 'package:agentrix_health/features/nutrition/food_database.dart';
import 'package:agentrix_health/features/nutrition/patterns.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 7, 30, 21);

const _targets = NutritionTargets(
  calories: 2200,
  maintenanceCalories: 2200,
  energyBasis: EnergyBasis.estimated,
  macros: MacroTargets(proteinG: 130, carbsG: 250, fatG: 70, fibreG: 31),
  addedSugarCeilingG: 27,
  waterMl: 2700,
  stepTarget: 8000,
  sleepTargetMinutes: 480,
);

MealEntry _meal({
  required int daysAgo,
  required List<String> foodIds,
  MealSlot slot = MealSlot.lunch,
  int hour = 13,
}) {
  final date = addDays(_now, -daysAgo);
  return MealEntry(
    id: 'm-$daysAgo-${slot.wireName}-$hour',
    day: toIsoDay(date),
    loggedAt: DateTime(date.year, date.month, date.day, hour),
    slot: slot,
    foods: foodIds
        .map(findFood)
        .whereType<FoodDefinition>()
        .map(LoggedFood.fromDefinition)
        .toList(),
  );
}

/// A day of real, adequate eating. The baseline that patterns deviate from.
List<MealEntry> _cleanDay(int daysAgo) => [
  _meal(
    daysAgo: daysAgo,
    slot: MealSlot.breakfast,
    hour: 8,
    foodIds: ['oats-porridge', 'boiled-eggs'],
  ),
  _meal(
    daysAgo: daysAgo,
    slot: MealSlot.lunch,
    hour: 13,
    foodIds: ['dal-tadka', 'brown-rice', 'cooked-spinach'],
  ),
  _meal(
    daysAgo: daysAgo,
    slot: MealSlot.dinner,
    hour: 20,
    foodIds: ['tandoori-chicken', 'mixed-sabzi'],
  ),
];

void main() {
  group('sparseness', () {
    test('reports sparse rather than inventing findings', () {
      final summary = analyseWeek(
        meals: _cleanDay(1),
        hydration: const {},
        targets: _targets,
        now: _now,
      );

      expect(summary.isSparse, isTrue);
      expect(summary.patterns, isEmpty);
      expect(summary.loggedDays, 1);
    });

    test('a single snack does not count as a logged day', () {
      final summary = analyseWeek(
        meals: [
          for (var i = 0; i < 7; i += 1)
            _meal(daysAgo: i, slot: MealSlot.snack, foodIds: ['banana']),
        ],
        hydration: const {},
        targets: _targets,
        now: _now,
      );

      expect(summary.loggedDays, 0);
      expect(summary.isSparse, isTrue);
    });

    test('never produces findings without targets', () {
      final summary = analyseWeek(
        meals: [for (var i = 0; i < 7; i += 1) ..._cleanDay(i)],
        hydration: const {},
        targets: null,
        now: _now,
      );

      expect(summary.patterns, isEmpty);
      // Averages are still real — they need no target to be true.
      expect(summary.averages.calories, greaterThan(0));
    });
  });

  group('counting, not averaging', () {
    test('finds added sugar over ceiling on the days it happened', () {
      final meals = <MealEntry>[];
      for (var i = 0; i < 7; i += 1) {
        meals.addAll(_cleanDay(i));
        // Four of the seven days carry a dessert and a soft drink.
        if (i.isEven && i < 8) {
          meals.add(
            _meal(
              daysAgo: i,
              slot: MealSlot.snack,
              hour: 17,
              foodIds: ['gulab-jamun', 'cola'],
            ),
          );
        }
      }

      final summary = analyseWeek(
        meals: meals,
        hydration: const {},
        targets: _targets,
        now: _now,
      );

      final sugar = summary.patterns.firstWhere((p) => p.id == 'sugar-over');
      expect(sugar.daysAffected, 4);
      expect(sugar.daysConsidered, 7);
      expect(sugar.tone, PatternTone.concern);
      expect(sugar.title, contains('4 of 7 days'));
    });

    test('three clean days and four heavy ones still produce a finding', () {
      // The case an average would hide entirely.
      final meals = <MealEntry>[];
      for (var i = 0; i < 7; i += 1) {
        meals.addAll(_cleanDay(i));
        if (i < 4) {
          meals.add(
            _meal(
              daysAgo: i,
              slot: MealSlot.snack,
              hour: 16,
              foodIds: ['ice-cream', 'chocolate-bar'],
            ),
          );
        }
      }

      final summary = analyseWeek(
        meals: meals,
        hydration: const {},
        targets: _targets,
        now: _now,
      );

      expect(
        summary.patterns.map((p) => p.id),
        contains('sugar-over'),
      );
    });
  });

  group('individual findings', () {
    test('flags short protein and quantifies the gap', () {
      final meals = [
        for (var i = 0; i < 7; i += 1)
          _meal(
            daysAgo: i,
            foodIds: ['plain-rice', 'mixed-sabzi', 'roti'],
          ),
        for (var i = 0; i < 7; i += 1)
          _meal(
            daysAgo: i,
            slot: MealSlot.dinner,
            hour: 20,
            foodIds: ['plain-dosa', 'coconut-chutney'],
          ),
      ];

      final summary = analyseWeek(
        meals: meals,
        hydration: const {},
        targets: _targets,
        now: _now,
      );

      final protein = summary.patterns.firstWhere(
        (p) => p.id == 'protein-short',
      );
      expect(protein.daysAffected, 7);
      expect(protein.detail, contains('130 g target'));
    });

    test('reinforces a week where protein was never short', () {
      final meals = [
        for (var i = 0; i < 7; i += 1)
          _meal(
            daysAgo: i,
            slot: MealSlot.breakfast,
            hour: 8,
            foodIds: ['greek-yoghurt', 'whey-shake', 'boiled-eggs'],
          ),
        for (var i = 0; i < 7; i += 1)
          _meal(
            daysAgo: i,
            foodIds: ['chicken-breast', 'quinoa', 'chickpea-salad'],
          ),
        for (var i = 0; i < 7; i += 1)
          _meal(
            daysAgo: i,
            slot: MealSlot.dinner,
            hour: 20,
            foodIds: ['grilled-salmon', 'cooked-spinach', 'paneer'],
          ),
      ];

      final summary = analyseWeek(
        meals: meals,
        hydration: const {},
        targets: _targets,
        now: _now,
      );

      final win = summary.patterns.firstWhere(
        (p) => p.id == 'protein-consistent',
      );
      expect(win.tone, PatternTone.win);
    });

    test('flags late eating', () {
      final meals = [
        for (var i = 0; i < 7; i += 1) ..._cleanDay(i),
        for (var i = 0; i < 5; i += 1)
          _meal(
            daysAgo: i,
            slot: MealSlot.snack,
            hour: 23,
            foodIds: ['almonds'],
          ),
      ];

      final summary = analyseWeek(
        meals: meals,
        hydration: const {},
        targets: _targets,
        now: _now,
      );

      final late = summary.patterns.firstWhere((p) => p.id == 'late-eating');
      expect(late.daysAffected, 5);
    });

    test('ignores days with no hydration logged at all', () {
      // A zero must mean "did not log", not "drank nothing" — otherwise every
      // user who never touches the water button gets a false finding.
      final summary = analyseWeek(
        meals: [for (var i = 0; i < 7; i += 1) ..._cleanDay(i)],
        hydration: const {},
        targets: _targets,
        now: _now,
      );

      expect(
        summary.patterns.map((p) => p.id),
        isNot(contains('hydration-short')),
      );
    });

    test('flags hydration when it was logged and short', () {
      final summary = analyseWeek(
        meals: [for (var i = 0; i < 7; i += 1) ..._cleanDay(i)],
        hydration: {
          for (var i = 0; i < 7; i += 1) toIsoDay(addDays(_now, -i)): 1200,
        },
        targets: _targets,
        now: _now,
      );

      expect(
        summary.patterns.map((p) => p.id),
        contains('hydration-short'),
      );
    });
  });

  group('ranking', () {
    test('the headline is a concern when one exists', () {
      final meals = <MealEntry>[];
      for (var i = 0; i < 7; i += 1) {
        meals.addAll(_cleanDay(i));
        meals.add(
          _meal(
            daysAgo: i,
            slot: MealSlot.snack,
            hour: 17,
            foodIds: ['gulab-jamun', 'cola'],
          ),
        );
      }

      final summary = analyseWeek(
        meals: meals,
        hydration: const {},
        targets: _targets,
        now: _now,
      );

      expect(summary.headline, isNotNull);
      expect(summary.headline!.tone, PatternTone.concern);
    });

    test('patterns come back sorted by weight', () {
      final summary = analyseWeek(
        meals: [for (var i = 0; i < 7; i += 1) ..._cleanDay(i)],
        hydration: const {},
        targets: _targets,
        now: _now,
      );

      final weights = summary.patterns.map((p) => p.weight).toList();
      expect(weights, orderedEquals([...weights]..sort((a, b) => b - a)));
    });
  });

  group('the demo seed', () {
    test('produces the sugar pattern the product promises', () {
      final summary = analyseWeek(
        meals: demoMealSeed(now: _now),
        hydration: demoHydrationSeed(now: _now),
        targets: _targets,
        now: _now,
      );

      expect(summary.isSparse, isFalse);
      final sugar = summary.patterns.firstWhere((p) => p.id == 'sugar-over');
      expect(sugar.daysAffected, 4);
    });

    test('never timestamps a meal in the future', () {
      for (final meal in demoMealSeed(now: _now)) {
        expect(meal.loggedAt.isAfter(_now), isFalse);
      }
    });
  });

  group('totalsByDay', () {
    test('returns one entry per day in the window, oldest first', () {
      final days = totalsByDay(
        meals: _cleanDay(2),
        hydration: const {},
        windowDays: 7,
        now: _now,
      );

      expect(days, hasLength(7));
      expect(days.first.day, toIsoDay(addDays(_now, -6)));
      expect(days.last.day, toIsoDay(_now));
    });

    test('records the latest meal hour for the late-eating check', () {
      final days = totalsByDay(
        meals: _cleanDay(0),
        hydration: const {},
        windowDays: 7,
        now: _now,
      );

      expect(days.last.lastMealHour, 20);
    });
  });
}
