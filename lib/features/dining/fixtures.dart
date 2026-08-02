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
    id: 'fx-burger',
    name: 'Patty Yard — Burgers & Fries',
    cuisine: Cuisine.american,
    rating: 4.0,
    ratingCount: 2400,
    priceLevel: 2,
    distanceMetres: 320,
    source: RestaurantSource.fixture,
  ),
  Restaurant(
    id: 'fx-diner',
    name: 'The Corner Diner — American Classics',
    cuisine: Cuisine.american,
    rating: 4.4,
    ratingCount: 1980,
    priceLevel: 2,
    distanceMetres: 430,
    source: RestaurantSource.fixture,
  ),
  Restaurant(
    id: 'fx-bbq',
    name: 'Smoke &amp; Bone — BBQ Pit',
    cuisine: Cuisine.american,
    rating: 4.6,
    ratingCount: 1540,
    priceLevel: 2,
    distanceMetres: 540,
    source: RestaurantSource.fixture,
  ),
  Restaurant(
    id: 'fx-steakhouse',
    name: 'Ember &amp; Oak — Steakhouse',
    cuisine: Cuisine.american,
    rating: 4.5,
    ratingCount: 860,
    priceLevel: 3,
    distanceMetres: 950,
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
  Restaurant(
    id: 'fx-taqueria',
    name: 'Casa Verde — Taqueria &amp; Grill',
    cuisine: Cuisine.mexican,
    rating: 4.5,
    ratingCount: 1320,
    priceLevel: 1,
    distanceMetres: 480,
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
    id: 'fx-south-tiffin',
    name: 'The Tiffin Room — South Indian',
    cuisine: Cuisine.southIndian,
    rating: 4.5,
    ratingCount: 1840,
    priceLevel: 1,
    distanceMetres: 1450,
    source: RestaurantSource.fixture,
  ),
  Restaurant(
    id: 'fx-north-thali',
    name: 'Copper Pot — North Indian Thali',
    cuisine: Cuisine.northIndian,
    rating: 4.3,
    ratingCount: 2260,
    priceLevel: 2,
    distanceMetres: 1600,
    source: RestaurantSource.fixture,
  ),
];

/// Rendered wherever fixture results are shown, so the fallback is never silent.
const String fixtureDisclosure =
    'Showing example venues — live nearby search is unavailable right now.';
