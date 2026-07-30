import 'dart:math' as math;

import '../../domain/entities/dining/restaurant.dart';
import '../../domain/entities/nutrition/food_definition.dart';
import '../../domain/entities/nutrition/macros.dart';
import '../../domain/entities/nutrition/nutrition_targets.dart';
import '../../domain/entities/profile/diet_pattern.dart';
import '../../domain/entities/user_profile.dart';
import '../nutrition/food_database.dart';

/// Dish-level restaurant ranking. Ported from `src/features/dining/rank.ts`.
///
/// The unit of recommendation is a *dish*, not a venue: "there is a healthy
/// place 400 m away" is not actionable, and "order the dal tadka with two rotis
/// — that is 34 g of protein and fits the 780 kcal you have left" is.
///
/// Dishes come from the same food table the logger uses, filtered by the
/// restaurant's cuisine. That is what makes the macros real: the numbers behind
/// a recommendation are the identical numbers that get written to the food log
/// if the user taps "I ate this". No menu is scraped, and the UI says so.

const String dishBasis =
    'Typical of this cuisine — we have not read this restaurant’s menu.';

class _Remaining {
  const _Remaining({
    required this.calories,
    required this.proteinG,
    required this.fibreG,
    required this.sugarHeadroomG,
  });

  final double calories;
  final double proteinG;
  final double fibreG;
  final double sugarHeadroomG;
}

String _capitalise(String value) =>
    value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);

/// Scores one dish 0–100 and explains itself.
///
/// The rationale is built from the terms that actually moved the score, so it
/// can never claim a reason the maths did not use.
DishPick? _scoreDish({
  required FoodDefinition food,
  required UserProfile profile,
  required _Remaining? remaining,
  required DiningMode mode,
  required List<FoodTag> focusTags,
}) {
  // Hard filter: allergens and diet pattern are safety, not preference, and
  // they apply identically on a cheat day.
  if (dietaryConflict(
        food,
        dietPattern: profile.effectiveDietPattern,
        allergens: profile.allergies,
      ) !=
      null) {
    return null;
  }

  var score = 50.0;
  final reasons = <String>[];

  if (mode == DiningMode.cheat) {
    // Cheat mode inverts the objective: the user has decided to enjoy
    // themselves, and a ranker that keeps pushing grilled fish at them is
    // useless. Protein still scores, because a satisfying meal with protein in
    // it beats one without.
    if (food.tags.contains(FoodTag.fried) ||
        food.tags.contains(FoodTag.sugary)) {
      score += 22;
      reasons.add('the indulgent pick you came for');
    }
    if (food.macros.proteinG >= 20) {
      score += 10;
      reasons.add(
        'still carries ${food.macros.proteinG.round()} g of protein',
      );
    }
    if (food.tags.contains(FoodTag.ultraProcessed)) score += 4;
  } else {
    // --- Protein density -----------------------------------------------------
    final proteinPer100Kcal =
        food.macros.proteinG / math.max(1, food.macros.calories) * 100;
    if (proteinPer100Kcal >= 8) {
      score += 20;
      reasons.add(
        '${food.macros.proteinG.round()} g of protein for '
        '${food.macros.calories} kcal',
      );
    } else if (proteinPer100Kcal >= 5) {
      score += 10;
    }

    // --- Fibre ---------------------------------------------------------------
    if (food.macros.fibreG >= 6) {
      score += 10;
      reasons.add('${food.macros.fibreG.round()} g of fibre');
    }

    // --- Penalties -----------------------------------------------------------
    if (food.tags.contains(FoodTag.fried)) score -= 16;
    if (food.tags.contains(FoodTag.sugary)) score -= 20;
    if (food.tags.contains(FoodTag.ultraProcessed)) score -= 10;

    // --- Declared restrictions ----------------------------------------------
    final restrictions = profile.restrictions;
    if (restrictions.contains(Restriction.noFried) &&
        food.tags.contains(FoodTag.fried)) {
      score -= 30;
    }
    if (restrictions.contains(Restriction.noAddedSugar) &&
        food.macros.addedSugarG > 5) {
      score -= 30;
    }
    if (restrictions.contains(Restriction.lowSodium) &&
        food.macros.sodiumMg > 700) {
      score -= 22;
      reasons.add('heavier on salt than you asked for');
    }
    if (restrictions.contains(Restriction.lowCarb) &&
        food.macros.carbsG > 40) {
      score -= 20;
    }
    if (restrictions.contains(Restriction.noAlcohol) && food.containsAlcohol) {
      score -= 60;
    }
  }

  // --- Today's focus (brief / cycle phase / flagged biomarker) --------------
  final matchedFocus = food.tags.where(focusTags.contains).toList();
  if (matchedFocus.isNotEmpty) {
    score += 8 * matchedFocus.length;
    reasons.add(
      '${matchedFocus.first.label.toLowerCase()} — what today’s plan calls for',
    );
  }

  // --- Fit against what is actually left -----------------------------------
  if (remaining != null && mode == DiningMode.aligned) {
    if (remaining.calories > 0) {
      final share = food.macros.calories / remaining.calories;
      if (share <= 0.55) {
        score += 12;
        reasons.add(
          'leaves room in your ${remaining.calories.round()} kcal budget',
        );
      } else if (share <= 0.85) {
        score += 4;
      } else if (share > 1.15) {
        score -= 24;
        reasons.add('more than you have left today');
      }
    }

    if (remaining.proteinG > 15 &&
        food.macros.proteinG >= remaining.proteinG * 0.4) {
      score += 10;
      reasons.add(
        'closes most of your ${remaining.proteinG.round()} g protein gap',
      );
    }

    if (food.macros.addedSugarG > remaining.sugarHeadroomG &&
        food.macros.addedSugarG > 5) {
      score -= 18;
    }
  }

  final bounded = score.round().clamp(0, 100);

  return DishPick(
    foodId: food.id,
    name: food.name,
    portionLabel: food.portionLabel,
    macros: food.macros,
    tags: food.tags,
    score: bounded,
    rationale: reasons.isNotEmpty
        ? _capitalise(reasons.take(2).join(', and '))
        : '${food.macros.calories} kcal, '
              '${food.macros.proteinG.round()} g protein',
    basis: dishBasis,
  );
}

/// Distance decay. Sharp inside a kilometre, flat beyond — the difference
/// between 200 m and 600 m matters to someone deciding where to eat; the
/// difference between 3 km and 3.4 km does not.
double _distanceScore(double? metres) {
  if (metres == null) return 0;
  if (metres <= 400) return 12;
  if (metres <= 800) return 8;
  if (metres <= 1500) return 4;
  if (metres <= 3000) return 0;
  return -8;
}

double _ratingScore(double? rating, int count) {
  // Too few reviews to mean anything.
  if (rating == null || count < 20) return 0;
  return ((rating - 3.8) * 10).roundToDouble();
}

List<RestaurantPick> rankRestaurants({
  required List<Restaurant> restaurants,
  required UserProfile profile,
  required NutritionTargets? targets,

  /// What the user has already eaten today.
  required Macros consumed,
  required DiningMode mode,

  /// Food tags today's brief wants floated up (iron-rich, high-protein…).
  List<FoodTag> focusTags = const [],
  int limit = 12,
}) {
  final remaining = targets == null
      ? null
      : _Remaining(
          calories: math.max(
            0,
            targets.calories - consumed.calories,
          ).toDouble(),
          proteinG: math.max(0.0, targets.macros.proteinG - consumed.proteinG),
          fibreG: math.max(0.0, targets.macros.fibreG - consumed.fibreG),
          sugarHeadroomG: math.max(
            0.0,
            targets.addedSugarCeilingG - consumed.addedSugarG,
          ),
        );

  final cuisineRank = profile.rankedCuisines;

  // Ranking happens on the raw score and only the *displayed* score is clamped.
  // Clamping first collapses every strong pick to 100 and leaves the top of the
  // list in arbitrary order — which is the one part of the ordering users
  // actually notice.
  final scored = <({RestaurantPick pick, double raw})>[];

  for (final restaurant in restaurants) {
    final dishes =
        menuForCuisine(restaurant.cuisine)
            .map(
              (food) => _scoreDish(
                food: food,
                profile: profile,
                remaining: remaining,
                mode: mode,
                focusTags: focusTags,
              ),
            )
            .whereType<DishPick>()
            .toList()
          ..sort((a, b) => b.score.compareTo(a.score));

    final top = dishes.take(3).toList();

    // A venue with nothing this user can eat is not a recommendation.
    if (top.isEmpty) continue;

    final reasons = <String>[];
    var score = top.first.score.toDouble();

    final rank = restaurant.cuisine == null
        ? -1
        : cuisineRank.indexOf(restaurant.cuisine!);
    if (rank == 0) {
      score += 14;
      reasons.add('your favourite cuisine');
    } else if (rank > 0) {
      score += math.max(4, 10 - rank * 2);
      reasons.add('a cuisine you eat often');
    }

    final distance = _distanceScore(restaurant.distanceMetres);
    score += distance;
    if (distance >= 8 && restaurant.distanceLabel != null) {
      reasons.add('${restaurant.distanceLabel} away');
    }

    score += _ratingScore(restaurant.rating, restaurant.ratingCount);
    if (restaurant.rating != null &&
        restaurant.rating! >= 4.4 &&
        restaurant.ratingCount >= 100) {
      reasons.add('rated ${restaurant.rating!.toStringAsFixed(1)}');
    }

    reasons.add(top.first.rationale.toLowerCase());

    // The combo is the top dish plus, in aligned mode, the best complementary
    // one that still fits the remaining budget — the "dal tadka + roti" shape of
    // recommendation rather than a single item.
    final combo = <DishPick>[top.first];
    if (mode == DiningMode.aligned && remaining != null && top.length > 1) {
      final together = combo.first.macros.calories + top[1].macros.calories;
      if (remaining.calories == 0 || together <= remaining.calories * 1.05) {
        combo.add(top[1]);
      }
    }

    scored.add((
      pick: RestaurantPick(
        restaurant: restaurant,
        score: score.round().clamp(0, 100),
        dishes: top,
        combo: combo,
        comboMacros: sumMacros(combo.map((d) => d.macros)),
        reasons: reasons.take(3).toList(),
      ),
      raw: score,
    ));
  }

  scored.sort((a, b) {
    final byScore = b.raw.compareTo(a.raw);
    // Distance breaks a genuine tie: between two equally good options, the
    // nearer one wins. Falling through to list order would make the ranking
    // depend on whatever order Places happened to return.
    if (byScore != 0) return byScore;
    final aDistance = a.pick.restaurant.distanceMetres ?? double.infinity;
    final bDistance = b.pick.restaurant.distanceMetres ?? double.infinity;
    return aDistance.compareTo(bDistance);
  });

  return scored.take(limit).map((entry) => entry.pick).toList();
}

/// The single sentence the Today screen shows: what to order, where, and why.
/// Returns null when there is nothing worth interrupting the user with.
String? headlineDiningPick(List<RestaurantPick> picks) {
  if (picks.isEmpty) return null;
  final top = picks.first;

  final names = top.combo.map((d) => d.name.toLowerCase()).toList();
  final dishPhrase = names.length > 1
      ? '${names[0]} with ${names[1]}'
      : names.first;

  return 'Order the $dishPhrase at ${top.restaurant.name} — '
      '${top.comboMacros.calories} kcal, '
      '${top.comboMacros.proteinG.round()} g protein.';
}
