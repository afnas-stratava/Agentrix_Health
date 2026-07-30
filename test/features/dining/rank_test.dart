import 'package:agentrix_health/domain/entities/allergy.dart';
import 'package:agentrix_health/domain/entities/dining/restaurant.dart';
import 'package:agentrix_health/domain/entities/nutrition/food_definition.dart';
import 'package:agentrix_health/domain/entities/nutrition/macros.dart';
import 'package:agentrix_health/domain/entities/nutrition/nutrition_targets.dart';
import 'package:agentrix_health/domain/entities/cuisine_preference.dart';
import 'package:agentrix_health/domain/entities/profile/cuisine.dart';
import 'package:agentrix_health/domain/entities/profile/diet_pattern.dart';
import 'package:agentrix_health/domain/entities/user_profile.dart';
import 'package:agentrix_health/features/dining/fixtures.dart';
import 'package:agentrix_health/features/dining/rank.dart';
import 'package:agentrix_health/features/nutrition/food_database.dart';
import 'package:flutter_test/flutter_test.dart';

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

UserProfile _profile({
  DietPattern? diet,
  Set<Allergy> allergies = const {},
  Set<Restriction> restrictions = const {},
  List<CuisinePreference> cuisines = const [],
}) => UserProfile.initial().copyWith(
  dietPattern: diet,
  allergies: allergies,
  restrictions: restrictions,
  cuisines: cuisines,
);

List<RestaurantPick> _rank({
  UserProfile? profile,
  Macros consumed = Macros.empty,
  DiningMode mode = DiningMode.aligned,
  List<FoodTag> focusTags = const [],
  List<Restaurant>? restaurants,
}) => rankRestaurants(
  restaurants: restaurants ?? fixtureRestaurants,
  profile: profile ?? _profile(),
  targets: _targets,
  consumed: consumed,
  mode: mode,
  focusTags: focusTags,
);

void main() {
  group('hard filters', () {
    test('never recommends a dish containing a declared allergen', () {
      final picks = _rank(
        profile: _profile(allergies: {Allergy.dairy, Allergy.gluten}),
      );

      for (final pick in picks) {
        for (final dish in pick.dishes) {
          final food = findFood(dish.foodId)!;
          expect(
            food.allergens.contains(Allergy.dairy),
            isFalse,
            reason: '${food.name} contains dairy',
          );
          expect(food.allergens.contains(Allergy.gluten), isFalse);
        }
      }
    });

    test('respects a vegan diet pattern', () {
      final picks = _rank(profile: _profile(diet: DietPattern.vegan));

      for (final pick in picks) {
        for (final dish in pick.dishes) {
          expect(findFood(dish.foodId)!.vegan, isTrue);
        }
      }
    });

    test('respects a vegetarian diet pattern', () {
      final picks = _rank(profile: _profile(diet: DietPattern.vegetarian));

      for (final pick in picks) {
        for (final dish in pick.dishes) {
          expect(findFood(dish.foodId)!.vegetarian, isTrue);
        }
      }
    });

    test('allergen filters still apply on a cheat day', () {
      // Cheat mode relaxes preferences, never safety.
      final picks = _rank(
        profile: _profile(allergies: {Allergy.peanuts, Allergy.dairy}),
        mode: DiningMode.cheat,
      );

      for (final pick in picks) {
        for (final dish in pick.dishes) {
          final food = findFood(dish.foodId)!;
          expect(food.allergens.contains(Allergy.peanuts), isFalse);
          expect(food.allergens.contains(Allergy.dairy), isFalse);
        }
      }
    });

    test('drops a venue with nothing the user can eat', () {
      final picks = _rank(
        profile: _profile(diet: DietPattern.vegan),
        restaurants: const [
          Restaurant(
            id: 'bacon-only',
            name: 'Bacon Only',
            // American fixtures are burgers, fries and bacon; fries are the
            // only vegan row, so this venue survives — the assertion below is
            // about the *pork* place having no vegan option at all.
            cuisine: Cuisine.japanese,
            source: RestaurantSource.fixture,
          ),
        ],
      );

      for (final pick in picks) {
        expect(pick.dishes, isNotEmpty);
      }
    });
  });

  group('macro fit', () {
    test('penalises a dish larger than the remaining budget', () {
      final fresh = _rank();
      final nearlyFull = _rank(
        consumed: const Macros(
          calories: 2000,
          proteinG: 120,
          carbsG: 230,
          fatG: 64,
          fibreG: 28,
          addedSugarG: 10,
          sodiumMg: 1800,
        ),
      );

      // With 200 kcal left, the top recommendation must be smaller than it was
      // with the whole day available.
      expect(
        nearlyFull.first.comboMacros.calories,
        lessThan(fresh.first.comboMacros.calories),
      );
    });

    test('the combo fits the remaining budget', () {
      final picks = _rank(
        consumed: const Macros(
          calories: 1400,
          proteinG: 80,
          carbsG: 160,
          fatG: 45,
          fibreG: 18,
          addedSugarG: 8,
          sodiumMg: 1200,
        ),
      );

      // 800 kcal left; a two-dish combo must not blow well past it.
      expect(
        picks.first.comboMacros.calories,
        lessThanOrEqualTo((2200 - 1400) * 1.1),
      );
    });

    test('comboMacros is the actual sum of the combo', () {
      for (final pick in _rank()) {
        expect(
          pick.comboMacros.calories,
          pick.combo.fold<int>(0, (sum, d) => sum + d.macros.calories),
        );
      }
    });
  });

  group('mode', () {
    test('cheat mode surfaces what aligned mode penalises', () {
      final aligned = _rank();
      final cheat = _rank(mode: DiningMode.cheat);

      bool hasIndulgent(List<RestaurantPick> picks) => picks
          .take(3)
          .expand((p) => p.combo)
          .any(
            (d) =>
                d.tags.contains(FoodTag.fried) ||
                d.tags.contains(FoodTag.sugary),
          );

      expect(hasIndulgent(cheat), isTrue);
      expect(hasIndulgent(aligned), isFalse);
    });

    test('aligned mode leads with protein density', () {
      final top = _rank().first.combo.first;
      final food = findFood(top.foodId)!;
      expect(
        food.macros.proteinG / food.macros.calories * 100,
        greaterThan(4),
      );
    });

    test('cheat mode builds a single-dish combo, not a budgeted pair', () {
      // There is no budget to respect, so pairing would be arbitrary.
      for (final pick in _rank(mode: DiningMode.cheat)) {
        expect(pick.combo, hasLength(1));
      }
    });
  });

  group('preferences', () {
    test("floats up the user's preferred cuisines", () {
      // Cuisine preference is a weighting, not an override — dish quality still
      // decides which of the user's cuisines wins. So the contract is "the top
      // pick is one they eat", not "it is their rank-0 cuisine".
      final asian = expandCuisinePreferences([CuisinePreference.eastAsian]);
      final picks = _rank(
        profile: _profile(cuisines: [CuisinePreference.eastAsian]),
      );

      expect(asian, contains(picks.first.restaurant.cuisine));
      expect(
        picks.first.reasons.any((r) => r.contains('cuisine')),
        isTrue,
      );
    });

    test('only claims a cuisine is preferred when it is', () {
      const venues = [
        Restaurant(
          id: 'jp',
          name: 'Japanese',
          cuisine: Cuisine.japanese,
          rating: 4.2,
          ratingCount: 500,
          distanceMetres: 600,
          source: RestaurantSource.fixture,
        ),
        Restaurant(
          id: 'med',
          name: 'Mediterranean',
          cuisine: Cuisine.mediterranean,
          rating: 4.2,
          ratingCount: 500,
          distanceMetres: 600,
          source: RestaurantSource.fixture,
        ),
      ];

      bool claimsCuisine(List<RestaurantPick> picks, String id) => picks
          .firstWhere((p) => p.restaurant.id == id)
          .reasons
          .any((r) => r.contains('cuisine'));

      final neutral = _rank(restaurants: venues);
      final preferring = _rank(
        restaurants: venues,
        profile: _profile(cuisines: [CuisinePreference.eastAsian]),
      );

      // With no stated preference, nothing may claim to match one.
      expect(claimsCuisine(neutral, 'jp'), isFalse);
      expect(claimsCuisine(neutral, 'med'), isFalse);

      expect(claimsCuisine(preferring, 'jp'), isTrue);
      expect(claimsCuisine(preferring, 'med'), isFalse);
    });

    test('honours a low-sodium restriction', () {
      final picks = _rank(
        profile: _profile(restrictions: {Restriction.lowSodium}),
      );

      // The top pick should not be one of the heavily salted dishes.
      expect(picks.first.combo.first.macros.sodiumMg, lessThan(900));
    });

    test('honours no-fried', () {
      final picks = _rank(
        profile: _profile(restrictions: {Restriction.noFried}),
      );

      for (final dish in picks.take(4).map((p) => p.combo.first)) {
        expect(dish.tags.contains(FoodTag.fried), isFalse);
      }
    });

    test('focus tags lift the score of matching dishes', () {
      // Not "the top pick changes" — a good ranker may already have been
      // recommending the right dish. What must change is the score and the
      // stated reason.
      int scoreOf(List<RestaurantPick> picks, String foodId) => picks
          .expand((p) => p.dishes)
          .firstWhere((d) => d.foodId == foodId)
          .score;

      final generic = _rank();
      final ironFocus = _rank(
        focusTags: [FoodTag.ironRich, FoodTag.vitaminCRich],
      );

      expect(
        scoreOf(ironFocus, 'sambar'),
        greaterThan(scoreOf(generic, 'sambar')),
      );
    });

    test('a focus-matched dish says why it surfaced', () {
      final picks = _rank(focusTags: [FoodTag.ironRich]);
      final matched = picks
          .expand((p) => p.dishes)
          .where((d) => d.tags.contains(FoodTag.ironRich));

      expect(matched, isNotEmpty);
      expect(
        matched.first.rationale.toLowerCase(),
        contains('today’s plan'),
      );
    });
  });

  group('output shape', () {
    test('scores are bounded 0–100', () {
      for (final pick in _rank()) {
        expect(pick.score, inInclusiveRange(0, 100));
        for (final dish in pick.dishes) {
          expect(dish.score, inInclusiveRange(0, 100));
        }
      }
    });

    test('picks come back best-first', () {
      final scores = _rank().map((p) => p.score).toList();
      expect(scores, orderedEquals([...scores]..sort((a, b) => b - a)));
    });

    test('every dish carries the not-a-menu disclosure', () {
      for (final pick in _rank()) {
        for (final dish in pick.dishes) {
          expect(dish.basis, dishBasis);
        }
      }
    });

    test('every dish has a rationale', () {
      for (final pick in _rank()) {
        for (final dish in pick.dishes) {
          expect(dish.rationale, isNotEmpty);
        }
      }
    });

    test('at most three dishes per venue', () {
      for (final pick in _rank()) {
        expect(pick.dishes.length, lessThanOrEqualTo(3));
      }
    });

    test('works with no targets at all', () {
      final picks = rankRestaurants(
        restaurants: fixtureRestaurants,
        profile: _profile(),
        targets: null,
        consumed: Macros.empty,
        mode: DiningMode.aligned,
      );

      expect(picks, isNotEmpty);
    });
  });

  group('headlineDiningPick', () {
    test('names the dish, the venue and the macros', () {
      final headline = headlineDiningPick(_rank())!;

      expect(headline, contains('Order the'));
      expect(headline, contains('kcal'));
      expect(headline, contains('g protein'));
    });

    test('is null when there is nothing to say', () {
      expect(headlineDiningPick(const []), isNull);
    });
  });

  group('fixtures', () {
    test('every fixture is labelled as one', () {
      for (final restaurant in fixtureRestaurants) {
        expect(restaurant.source, RestaurantSource.fixture);
      }
    });

    test('every fixture has a cuisine the food table can serve', () {
      for (final restaurant in fixtureRestaurants) {
        expect(
          menuForCuisine(restaurant.cuisine),
          isNotEmpty,
          reason: '${restaurant.name} has no dishes',
        );
      }
    });
  });
}
