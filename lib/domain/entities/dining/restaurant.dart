import '../nutrition/food_definition.dart';
import '../nutrition/macros.dart';
import '../profile/cuisine.dart';

/// Restaurant and dish recommendations. Ported from `src/schemas/dining.ts`.
///
/// IMPORTANT, AND SURFACED IN THE UI: nothing here reads an actual menu.
/// Places APIs return a restaurant's name, location, rating and type — never
/// its dish list, and certainly never nutrition for those dishes. What this
/// feature does is match *the kind of food a place serves* against what the user
/// has left in their macro budget today, and name specific dishes typical of
/// that cuisine.
///
/// So "order the dal tadka and two rotis here" means "at a North Indian place,
/// that combination fits your remaining macros" — not "we read their menu and
/// they have it". [DishPick.basis] carries that distinction into the UI, and
/// every card renders it.

enum RestaurantSource {
  /// Live result from the Places provider.
  places,

  /// Curated archetype used when live search is unavailable.
  fixture,
}

class Restaurant {
  const Restaurant({
    required this.id,
    required this.name,
    required this.source,
    this.cuisine,
    this.providerTypes = const [],
    this.rating,
    this.ratingCount = 0,
    this.priceLevel,
    this.distanceMetres,
    this.address,
    this.openNow,
    this.mapsUri,
  });

  final String id;
  final String name;

  /// Inferred from the provider's type tags; null when nothing matched.
  final Cuisine? cuisine;

  /// Raw provider type strings, kept for debugging a bad cuisine inference.
  final List<String> providerTypes;

  final double? rating;
  final int ratingCount;

  /// 1–4.
  final int? priceLevel;

  /// Metres from the user. Null when location was unavailable.
  final double? distanceMetres;

  final String? address;
  final bool? openNow;
  final RestaurantSource source;

  /// Deep link to the provider's listing, for directions.
  final String? mapsUri;

  String? get distanceLabel {
    final metres = distanceMetres;
    if (metres == null) return null;
    if (metres < 1000) return '${metres.round()} m';
    return '${(metres / 1000).toStringAsFixed(1)} km';
  }

  String get priceLabel => priceLevel == null ? '' : '₹' * priceLevel!;
}

/// A specific dish recommendation, with the macros that justify it.
class DishPick {
  const DishPick({
    required this.foodId,
    required this.name,
    required this.portionLabel,
    required this.macros,
    required this.tags,
    required this.score,
    required this.rationale,
    required this.basis,
  });

  final String foodId;
  final String name;
  final String portionLabel;
  final Macros macros;
  final List<FoodTag> tags;

  /// 0–100.
  final int score;

  /// One line: why this dish, for this person, today.
  final String rationale;

  /// Standing disclosure that this is cuisine-typical, not menu-verified.
  final String basis;
}

class RestaurantPick {
  const RestaurantPick({
    required this.restaurant,
    required this.score,
    required this.dishes,
    required this.combo,
    required this.comboMacros,
    required this.reasons,
  });

  final Restaurant restaurant;

  /// 0–100.
  final int score;

  /// Best two or three dishes, already ranked.
  final List<DishPick> dishes;

  /// The dishes the headline actually recommends ordering together.
  final List<DishPick> combo;

  /// Combined macros of [combo].
  final Macros comboMacros;

  /// Why this restaurant floated up: cuisine match, macro fit, distance.
  final List<String> reasons;
}

/// Cheat day is an explicit user choice, never inferred.
///
/// In cheat mode the ranker stops penalising indulgence and starts optimising
/// for "the best version of what you actually want" — allergens and diet pattern
/// remain hard filters, because those are safety, not preference.
enum DiningMode {
  aligned('Aligned to today'),
  cheat('Cheat day');

  const DiningMode(this.label);

  final String label;
}
