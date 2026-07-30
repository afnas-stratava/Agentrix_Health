import '../../domain/entities/nutrition/food_definition.dart';
import '../../domain/entities/profile/cuisine.dart';
import '../../domain/entities/user_profile.dart';
import 'food_database.dart';

/// Plate suggestion for photo logging.
/// Ported from `src/features/nutrition/recognize.ts`.
///
/// ───────────────────────────────────────────────────────────────────────────
/// THIS DOES NOT LOOK AT THE PHOTO. There is no vision model in this build.
///
/// What it does is narrow the food table down to the handful of items a given
/// user plausibly ate at a given meal — using their cuisine preferences, dietary
/// constraints, the time of day and their own logging history — and let them
/// confirm in two taps. The photo is still captured and attached to the entry, so
/// the log is visual; the macros come from the user's confirmation, not from a
/// guess we dressed up as recognition.
///
/// The UI must therefore never say "we identified your food". It says "what's on
/// the plate?" and pre-selects likely answers. [suggestionBasis] is rendered
/// verbatim in the sheet so the mechanism is never misrepresented.
///
/// To make this real, implement a vision call that returns the same
/// [PlateSuggestion] list; every call site already treats confidence below 1 as
/// "needs confirming", so nothing else changes.
/// ───────────────────────────────────────────────────────────────────────────
const String suggestionBasis =
    'Ranked from your cuisines, diet and the time of day — not from the photo. '
    'Tap to confirm what you actually ate.';

class PlateSuggestion {
  const PlateSuggestion({
    required this.food,
    required this.confidence,
    required this.reason,
  });

  final FoodDefinition food;

  /// 0–1, and never 1: these are candidates, not identifications. The entry only
  /// reaches full confidence once the user confirms it.
  final double confidence;

  /// Why this surfaced, shown as a caption.
  final String reason;
}

/// Which foods make sense in which slot.
///
/// A dosa at 9pm is not impossible, it is just less likely than at 9am, and the
/// ordering should reflect that.
const Map<MealSlot, List<String>> _slotAffinity = {
  MealSlot.breakfast: [
    'idli',
    'plain-dosa',
    'masala-dosa',
    'upma',
    'ven-pongal',
    'aloo-paratha',
    'oats-porridge',
    'boiled-eggs',
    'veg-omelette',
    'greek-yoghurt',
    'avocado-toast',
    'banana',
    'masala-chai',
    'filter-coffee',
    'black-coffee',
  ],
  MealSlot.lunch: [
    'dal-tadka',
    'rajma',
    'chole',
    'sambar',
    'curd-rice',
    'plain-rice',
    'brown-rice',
    'roti',
    'mixed-sabzi',
    'grilled-chicken-salad',
    'chickpea-salad',
    'lentil-soup',
    'hummus-pita',
    'chicken-biryani',
  ],
  MealSlot.dinner: [
    'palak-paneer',
    'paneer-tikka',
    'tandoori-chicken',
    'chicken-tikka',
    'butter-chicken',
    'fish-curry',
    'grilled-salmon',
    'tofu-stirfry',
    'roti',
    'dal-makhani',
    'greek-salad',
    'pho',
    'salmon-sushi',
  ],
  MealSlot.snack: [
    'almonds',
    'walnuts',
    'banana',
    'guava',
    'orange',
    'greek-yoghurt',
    'whey-shake',
    'samosa',
    'pakora',
    'masala-chai',
    'chocolate-bar',
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

    var score = 0.0;
    var reason = 'Common at this time of day';

    final slotIndex = affinity.indexOf(food.id);
    if (slotIndex >= 0) {
      score += 40 - slotIndex;
    } else {
      // Not typical of this slot — still selectable via search, but it does not
      // belong in a pre-selected shortlist.
      continue;
    }

    final cuisineIndex = food.cuisine == null
        ? -1
        : cuisines.indexOf(food.cuisine!);
    if (cuisineIndex == 0) {
      score += 25;
      reason = 'Your top cuisine, and typical of ${slot.label.toLowerCase()}';
    } else if (cuisineIndex > 0) {
      score += 18 - cuisineIndex * 2;
      reason = 'A cuisine you eat often';
    }

    final recentIndex = recentFoodIds.indexOf(food.id);
    if (recentIndex >= 0) {
      score += 30 - recentIndex.clamp(0, 20);
      reason = 'You have logged this before';
    }

    scored.add((food: food, score: score, reason: reason));
  }

  scored.sort((a, b) {
    final byScore = b.score.compareTo(a.score);
    return byScore != 0 ? byScore : a.food.name.compareTo(b.food.name);
  });

  final top = scored.take(limit).toList();
  if (top.isEmpty) return const [];

  final best = top.first.score;

  return top
      .map(
        (entry) => PlateSuggestion(
          food: entry.food,
          // Normalised against the best candidate and capped below 1, because
          // nothing here is an identification.
          confidence: best <= 0
              ? 0.4
              : (0.35 + 0.5 * (entry.score / best)).clamp(0.1, 0.9),
          reason: entry.reason,
        ),
      )
      .toList();
}

/// Cuisine label for a food, for the sheet's secondary line.
String cuisineLabel(Cuisine? cuisine) => cuisine?.label ?? 'Everyday';
