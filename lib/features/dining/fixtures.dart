import '../../domain/entities/dining/restaurant.dart';
import '../../domain/entities/profile/cuisine.dart';

/// Curated fallback restaurants. Ported from
/// `src/features/dining/fixtures.ts`.
///
/// Used whenever Places is unconfigured, offline, rate-limited or returns
/// nothing — which on conference wifi is a real possibility, and a demo that
/// dies on a failed fetch is a demo that does not happen.
///
/// These are deliberately generic archetypes rather than impersonations of real
/// businesses: the names describe the kind of place, and
/// [RestaurantSource.fixture] is carried all the way into the UI so a fallback
/// list is never passed off as live nearby results.
const List<Restaurant> fixtureRestaurants = [
  Restaurant(
    id: 'fx-south-tiffin',
    name: 'The Tiffin Room — South Indian',
    cuisine: Cuisine.southIndian,
    rating: 4.5,
    ratingCount: 1840,
    priceLevel: 1,
    distanceMetres: 320,
    source: RestaurantSource.fixture,
  ),
  Restaurant(
    id: 'fx-north-thali',
    name: 'Copper Pot — North Indian Thali',
    cuisine: Cuisine.northIndian,
    rating: 4.3,
    ratingCount: 2260,
    priceLevel: 2,
    distanceMetres: 540,
    source: RestaurantSource.fixture,
  ),
  Restaurant(
    id: 'fx-tandoor',
    name: 'Charcoal & Clay — Tandoori Grill',
    cuisine: Cuisine.northIndian,
    rating: 4.4,
    ratingCount: 980,
    priceLevel: 2,
    distanceMetres: 760,
    source: RestaurantSource.fixture,
  ),
  Restaurant(
    id: 'fx-med-grill',
    name: 'Olive & Ember — Mediterranean Grill',
    cuisine: Cuisine.mediterranean,
    rating: 4.6,
    ratingCount: 640,
    priceLevel: 3,
    distanceMetres: 890,
    source: RestaurantSource.fixture,
  ),
  Restaurant(
    id: 'fx-levant',
    name: 'Levant Kitchen — Middle Eastern',
    cuisine: Cuisine.middleEastern,
    rating: 4.2,
    ratingCount: 410,
    priceLevel: 2,
    distanceMetres: 1100,
    source: RestaurantSource.fixture,
  ),
  Restaurant(
    id: 'fx-sushi',
    name: 'Hinoki — Sushi & Donburi',
    cuisine: Cuisine.japanese,
    rating: 4.7,
    ratingCount: 520,
    priceLevel: 3,
    distanceMetres: 1350,
    source: RestaurantSource.fixture,
  ),
  Restaurant(
    id: 'fx-wok',
    name: 'Iron Wok — Pan Asian',
    cuisine: Cuisine.eastAsian,
    rating: 4.1,
    ratingCount: 1120,
    priceLevel: 2,
    distanceMetres: 700,
    source: RestaurantSource.fixture,
  ),
  Restaurant(
    id: 'fx-thai',
    name: 'Lemongrass — Thai',
    cuisine: Cuisine.thai,
    rating: 4.3,
    ratingCount: 380,
    priceLevel: 2,
    distanceMetres: 1580,
    source: RestaurantSource.fixture,
  ),
  Restaurant(
    id: 'fx-burger',
    name: 'Patty Yard — Burgers & Fries',
    cuisine: Cuisine.american,
    rating: 4.0,
    ratingCount: 2400,
    priceLevel: 2,
    distanceMetres: 430,
    source: RestaurantSource.fixture,
  ),
  Restaurant(
    id: 'fx-pizza',
    name: 'Forno — Wood-Fired Pizza',
    cuisine: Cuisine.continental,
    rating: 4.4,
    ratingCount: 1660,
    priceLevel: 2,
    distanceMetres: 620,
    source: RestaurantSource.fixture,
  ),
];

/// Rendered wherever fixture results are shown, so the fallback is never silent.
const String fixtureDisclosure =
    'Showing example venues — live nearby search is unavailable right now.';
