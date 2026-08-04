import '../cuisine_preference.dart';

/// Ported from `CuisineSchema` in `src/schemas/profile.ts`.
///
/// This is the *food-table* cuisine vocabulary — the one the dish ranker and
/// the food database join on. It is deliberately finer-grained than the
/// [CuisinePreference] chips shown during onboarding: "Indian" is one tap for a
/// user but two menus for a ranker, because a tiffin room and a tandoori grill
/// share almost no dishes.
enum Cuisine {
  american('american', 'American'),
  continental('continental', 'Continental'),
  mexican('mexican', 'Mexican'),
  mediterranean('mediterranean', 'Mediterranean'),
  northIndian('north-indian', 'North Indian'),
  southIndian('south-indian', 'South Indian'),
  middleEastern('middle-eastern', 'Middle Eastern'),
  eastAsian('east-asian', 'East Asian'),
  japanese('japanese', 'Japanese'),
  thai('thai', 'Thai'),
  chinese('chinese', 'Chinese'),
  korean('korean', 'Korean');

  const Cuisine(this.wireName, this.label);

  final String wireName;
  final String label;

  static Cuisine? fromWireName(String value) {
    for (final cuisine in Cuisine.values) {
      if (cuisine.wireName == value) return cuisine;
    }
    return null;
  }
}

/// Expands the onboarding chips into the ranker's vocabulary.
///
/// Order is load-bearing all the way through: the ranker reads a cuisine's
/// index as a preference weight, so a user who tapped "Indian" first must get
/// both Indian sub-cuisines ahead of everything they tapped second.
List<Cuisine> expandCuisinePreferences(List<CuisinePreference> preferences) {
  final out = <Cuisine>[];

  void add(Cuisine cuisine) {
    if (!out.contains(cuisine)) out.add(cuisine);
  }

  for (final preference in preferences) {
    switch (preference) {
      case CuisinePreference.indian:
        add(Cuisine.northIndian);
        add(Cuisine.southIndian);
      case CuisinePreference.mediterranean:
        add(Cuisine.mediterranean);
      case CuisinePreference.chinese:
        add(Cuisine.chinese);
        add(Cuisine.eastAsian);
      case CuisinePreference.korean:
        add(Cuisine.korean);
        add(Cuisine.eastAsian);
      case CuisinePreference.mexican:
        add(Cuisine.mexican);
      case CuisinePreference.american:
        add(Cuisine.american);
        add(Cuisine.continental);
      // "Vegetarian" is a diet, not a cuisine — it is honoured as a
      // [DietPattern] hard filter instead, and contributes no cuisine weight.
      case CuisinePreference.vegetarian:
        break;
    }
  }

  return out;
}
