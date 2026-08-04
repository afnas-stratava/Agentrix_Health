import 'dart:math' as math;

import '../../domain/entities/nutrition/food_definition.dart';
import '../../domain/entities/profile/cuisine.dart';
import '../../domain/entities/user_profile.dart';
import 'food_database.dart';

/// Plate suggestion for photo logging.
/// Ported from `src/features/nutrition/recognize.ts`.
///
/// ───────────────────────────────────────────────────────────────────────────
/// THIS DOES NOT LOOK AT THE PHOTO. It is the profile-ranked path.
///
/// [GeminiMealVision] is the one that reads the image. This file is what
/// answers when there is no key configured, the call fails, or the model looked
/// and found no food — and what fills the list before any photo is taken at all.
///
/// What it does is narrow the food table down to the handful of items a given
/// user plausibly ate at a given meal — using their cuisine preferences, dietary
/// constraints, the time of day and their own logging history — and let them
/// confirm in two taps.
///
/// Neither path may say "we identified your food". Both end in the same
/// confirm-and-adjust list, and each carries its own basis string — this one
/// [suggestionBasis], the vision one `photoReadBasis` — rendered verbatim in the
/// sheet so the user always knows which of the two produced the list in front of
/// them. Swapping one for the other silently is the failure mode to avoid.
/// ───────────────────────────────────────────────────────────────────────────
const String suggestionBasis =
    'Ranked from your cuisines, diet and the time of day — not from the photo. '
    'Tap to confirm what you actually ate.';

class PlateSuggestion {
  const PlateSuggestion({
    required this.food,
    required this.confidence,
    required this.reason,
    this.portions = 1,
  });

  final FoodDefinition food;

  /// 0–1, and never 1: these are candidates, not identifications. The entry only
  /// reaches full confidence once the user confirms it.
  final double confidence;

  /// Why this surfaced, shown as a caption.
  final String reason;

  /// Multiples of [FoodDefinition.portionLabel]. The ranked path cannot know how
  /// much is on the plate and always says one; only the vision path estimates.
  final double portions;
}

/// Which foods make sense in which slot.
///
/// A dosa at 9pm is not impossible, it is just less likely than at 9am, and the
/// ordering should reflect that.
const Map<MealSlot, List<String>> _slotAffinity = {
  MealSlot.breakfast: [
    'scrambled-eggs',
    'turkey-bacon',
    'breakfast-sausage',
    'hash-browns',
    'pancakes-syrup',
    'waffle',
    'biscuits-gravy',
    'bagel-cream-cheese',
    'breakfast-burrito',
    'oats-porridge',
    'boiled-eggs',
    'veg-omelette',
    'greek-yoghurt',
    'avocado-toast',
    'banana',
    'black-coffee',
    'idli',
    'plain-dosa',
    'masala-dosa',
    'upma',
    'ven-pongal',
    'aloo-paratha',
    'masala-chai',
    'filter-coffee',
  ],
  MealSlot.lunch: [
    'grilled-chicken-sandwich',
    'turkey-sandwich',
    'grilled-cheese',
    'pb-and-j',
    'tuna-salad-sandwich',
    'caesar-salad-chicken',
    'cobb-salad',
    'chicken-noodle-soup',
    'clam-chowder',
    'turkey-chili',
    'chicken-burrito-bowl',
    'chicken-tacos',
    'chicken-fajitas',
    'black-beans',
    'grilled-chicken-salad',
    'chickpea-salad',
    'lentil-soup',
    'hummus-pita',
    'dal-tadka',
    'rajma',
    'chole',
    'sambar',
    'curd-rice',
    'plain-rice',
    'brown-rice',
    'roti',
    'mixed-sabzi',
    'chicken-biryani',
  ],
  MealSlot.dinner: [
    'meatloaf',
    'pot-roast',
    'steak-baked-potato',
    'bbq-pulled-pork',
    'buffalo-wings',
    'mac-and-cheese',
    'steak-quesadilla',
    'carne-asada-plate',
    'shrimp-tacos',
    'grilled-salmon',
    'tofu-stirfry',
    'greek-salad',
    'pho',
    'salmon-sushi',
    'palak-paneer',
    'paneer-tikka',
    'tandoori-chicken',
    'chicken-tikka',
    'butter-chicken',
    'fish-curry',
    'roti',
    'dal-makhani',
  ],
  MealSlot.snack: [
    'almonds',
    'walnuts',
    'trail-mix',
    'granola-bar',
    'protein-bar',
    'peanut-butter',
    'string-cheese',
    'popcorn',
    'soft-pretzel',
    'apple-pie',
    'banana',
    'orange',
    'greek-yoghurt',
    'whey-shake',
    'guacamole-chips',
    'samosa',
    'pakora',
    'chocolate-bar',
    'chocolate-milkshake',
    'sweet-tea',
    'lemonade',
    'cola',
    'ice-cream',
  ],
};

/// Ranks plausible plate contents for a slot.
///
/// Deterministic for a given (slot, profile, history): the same photo always
/// yields the same ordering, which is what makes the sheet feel like a considered
/// suggestion rather than a shuffle.
List<PlateSuggestion> suggestPlate({
  required MealSlot slot,
  required UserProfile profile,

  /// Food ids the user has logged before, most recent first.
  List<String> recentFoodIds = const [],
  int limit = 8,
}) {
  final affinity = _slotAffinity[slot] ?? const [];
  final cuisines = profile.rankedCuisines;
  final dietPattern = profile.effectiveDietPattern;
  final allergens = profile.allergies;

  final scored = <({FoodDefinition food, double score, String reason})>[];

  for (final food in foodDatabase) {
    // Allergens and diet pattern are safety, not preference: a suggestion that
    // violates one is a bug, so filter rather than down-rank.
    if (dietaryConflict(
          food,
          dietPattern: dietPattern,
          allergens: allergens,
        ) !=
        null) {
      continue;
    }

    final slotIndex = affinity.indexOf(food.id);
    // Not typical of this slot — still selectable via search, but it does not
    // belong in a pre-selected shortlist.
    if (slotIndex == -1) continue;

    // Base score decays down the slot list.
    var score = 1 - slotIndex / affinity.length;
    final reasons = <String>[];

    final cuisineRank = food.cuisine == null
        ? -1
        : cuisines.indexOf(food.cuisine!);
    if (cuisineRank == 0) {
      score += 0.45;
      reasons.add('your top cuisine');
    } else if (cuisineRank > 0) {
      score += 0.3 - cuisineRank * 0.05;
      reasons.add('a cuisine you picked');
    }

    final recentIndex = recentFoodIds.indexOf(food.id);
    if (recentIndex != -1) {
      // Logged recently — people eat the same twenty things.
      score += math.max(0.1, 0.4 - recentIndex * 0.03);
      reasons.add('you logged this recently');
    }

    scored.add((
      food: food,
      score: score,
      // The strongest reason wins; cuisine is pushed before recency because
      // "your top cuisine" explains the pick better than "you ate it before".
      reason: reasons.isNotEmpty
          ? reasons.first
          : 'common at ${slot.label.toLowerCase()}',
    ));
  }

  scored.sort((a, b) {
    final byScore = b.score.compareTo(a.score);
    return byScore != 0 ? byScore : a.food.name.compareTo(b.food.name);
  });

  return scored
      .take(limit)
      .map(
        (entry) => PlateSuggestion(
          food: entry.food,
          // Held below 0.8 on purpose: these are candidates awaiting
          // confirmation, never identifications.
          confidence: math.min(0.78, (entry.score * 100).round() / 100),
          reason: entry.reason,
        ),
      )
      .toList();
}

/// Cuisine label for a food, for the sheet's secondary line.
String cuisineLabel(Cuisine? cuisine) => cuisine?.label ?? 'Everyday';
