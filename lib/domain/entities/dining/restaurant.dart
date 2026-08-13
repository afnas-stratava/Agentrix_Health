import '../../../core/util/units.dart';
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
  /// A real nearby-search result.
  live,

  /// Test-only double — never constructed by the running app.
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
    this.latitude,
    this.longitude,
    this.address,
    this.openNow,
    this.mapsUri,
  });

  final String id;
  final String name;

  /// Inferred from the provider's type/cuisine tags; null when nothing matched.
  final Cuisine? cuisine;

  /// Raw provider type/cuisine strings, kept for debugging a bad inference.
  final List<String> providerTypes;

  /// OpenStreetMap carries neither a rating nor a price level — both stay null
  /// for every live result. [rank.dart]'s scoring already treats a null rating
  /// as "no signal" rather than a penalty, so this costs the ranker nothing.
  final double? rating;
  final int ratingCount;

  /// 1–4.
  final int? priceLevel;

  /// Metres from the user. Null when location was unavailable.
  final double? distanceMetres;

  /// Needed to build a directions link — OSM has no equivalent of Places'
  /// `googleMapsUri`, so [mapsUri] is built from these at read time instead of
  /// coming from the provider.
  final double? latitude;
  final double? longitude;

  final String? address;
  final bool? openNow;
  final RestaurantSource source;

  /// Deep link to the provider's listing, for directions.
  final String? mapsUri;

  /// Under ~0.1 mi shows feet, matching how Google/Apple Maps break the two
  /// ranges — a distance a US user would actually read as "just down the
  /// street" gets lost if it renders as "0.1 mi" from the very first step.
  String? get distanceLabel {
    final metres = distanceMetres;
    if (metres == null) return null;
    final feet = metresToFeet(metres);
    if (feet < 528) return '${feet.round()} ft';
    return '${metresToMiles(metres).toStringAsFixed(1)} mi';
  }

  String get priceLabel => priceLevel == null ? '' : '₹' * priceLevel!;

  /// A universal Google Maps search link — resolves to whatever maps app is
  /// installed, and needs no API key since it is just a URL, not a Places
  /// call.
  String? get directionsUri {
    if (mapsUri != null) return mapsUri;
    final lat = latitude;
    final lon = longitude;
    if (lat == null || lon == null) return null;
    return 'https://www.google.com/maps/search/?api=1&query=$lat,$lon';
  }
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
