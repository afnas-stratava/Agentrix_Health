import '../allergy.dart';
import '../profile/cuisine.dart';
import '../profile/diet_pattern.dart';
import 'macros.dart';

/// Ported from `FoodTagSchema`. Tags the dish ranker and the pattern analyser
/// both filter on.
enum FoodTag {
  highProtein('high-protein', 'High protein'),
  highFibre('high-fibre', 'High fibre'),
  lowCarb('low-carb', 'Low carb'),
  wholegrain('wholegrain', 'Wholegrain'),
  fried('fried', 'Fried'),
  sugary('sugary', 'Sugary'),
  ultraProcessed('ultra-processed', 'Ultra-processed'),
  ironRich('iron-rich', 'Iron-rich'),
  calciumRich('calcium-rich', 'Calcium-rich'),
  omega3Rich('omega3-rich', 'Omega-3'),
  probiotic('probiotic', 'Probiotic'),
  leafyGreen('leafy-green', 'Leafy greens'),
  vitaminCRich('vitamin-c-rich', 'Vitamin C');

  const FoodTag(this.wireName, this.label);

  final String wireName;
  final String label;

  static FoodTag? fromWireName(String value) {
    for (final tag in FoodTag.values) {
      if (tag.wireName == value) return tag;
    }
    return null;
  }
}

enum MealSlot {
  breakfast('breakfast', 'Breakfast'),
  lunch('lunch', 'Lunch'),
  dinner('dinner', 'Dinner'),
  snack('snack', 'Snack');

  const MealSlot(this.wireName, this.label);

  final String wireName;
  final String label;

  static MealSlot? fromWireName(String value) {
    for (final slot in MealSlot.values) {
      if (slot.wireName == value) return slot;
    }
    return null;
  }

  /// The slot a meal logged at this hour most likely belongs to.
  static MealSlot forHour(int hour) {
    if (hour < 11) return MealSlot.breakfast;
    if (hour < 16) return MealSlot.lunch;
    if (hour < 22) return MealSlot.dinner;
    return MealSlot.snack;
  }
}

/// One row of the food database.
///
/// [portionLabel] describes what the macros refer to, so a portion multiplier
/// is always unambiguous: "1 medium, ~40 g" means the macros below are for
/// exactly one roti.
class FoodDefinition {
  const FoodDefinition({
    required this.id,
    required this.name,
    required this.portionLabel,
    required this.macros,
    this.cuisine,
    this.tags = const [],
    this.allergens = const [],
    this.vegetarian = false,
    this.vegan = false,
    this.jainSafe = false,
    this.containsPork = false,
    this.containsAlcohol = false,
  });

  final String id;
  final String name;

  /// Shown under the name — "1 medium, ~45 g".
  final String portionLabel;

  final Macros macros;
  final Cuisine? cuisine;
  final List<FoodTag> tags;
  final List<Allergy> allergens;

  final bool vegetarian;
  final bool vegan;

  /// Free of onion, garlic and root vegetables — required for Jain diets.
  final bool jainSafe;

  final bool containsPork;
  final bool containsAlcohol;
}

/// Hard dietary compatibility.
///
/// Returns the reason a food is excluded, or null when it is safe to recommend
/// — a string rather than a bool because the UI explains omissions ("hidden:
/// contains dairy") rather than silently shortening the list.
String? dietaryConflict(
  FoodDefinition item, {
  required DietPattern dietPattern,
  required Set<Allergy> allergens,
}) {
  for (final allergen in allergens) {
    if (item.allergens.contains(allergen)) {
      return 'contains ${allergen.label.toLowerCase()}';
    }
  }

  switch (dietPattern) {
    case DietPattern.vegetarian:
      if (!item.vegetarian) return 'not vegetarian';
    case DietPattern.lactoseFree:
      if (item.allergens.contains(Allergy.dairy)) return 'contains dairy';
    case DietPattern.vegan:
      if (!item.vegan) return 'not vegan';
    case DietPattern.pescatarian:
      if (!item.vegetarian &&
          !item.allergens.contains(Allergy.fish) &&
          !item.allergens.contains(Allergy.shellfish)) {
        return 'contains meat';
      }
    case DietPattern.halal:
      if (item.containsPork) return 'contains pork';
      if (item.containsAlcohol) return 'contains alcohol';
    case DietPattern.omnivore:
      break;
  }

  return null;
}
