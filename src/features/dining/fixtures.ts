import type { Restaurant } from '@/schemas/dining';
import type { Cuisine } from '@/schemas/profile';

/**
 * Curated fallback restaurants.
 *
 * Used whenever Places is unconfigured, offline, rate-limited or returns
 * nothing — which on a conference wifi is a real possibility, and a demo that
 * dies on a failed fetch is a demo that does not happen.
 *
 * These are deliberately generic archetypes rather than impersonations of real
 * businesses: the names describe the kind of place, and `source: 'fixture'` is
 * carried all the way into the UI so a fallback list is never passed off as
 * live nearby results.
 */

interface FixtureInput {
  id: string;
  name: string;
  cuisine: Cuisine;
  rating: number;
  ratingCount: number;
  priceLevel: number;
  /** Metres, used verbatim when there is no location fix to measure from. */
  distanceMetres: number;
}

const FIXTURE_INPUTS: FixtureInput[] = [
  {
    id: 'fx-south-tiffin',
    name: 'The Tiffin Room — South Indian',
    cuisine: 'south-indian',
    rating: 4.5,
    ratingCount: 1840,
    priceLevel: 1,
    distanceMetres: 320,
  },
  {
    id: 'fx-north-thali',
    name: 'Copper Pot — North Indian Thali',
    cuisine: 'north-indian',
    rating: 4.3,
    ratingCount: 2260,
    priceLevel: 2,
    distanceMetres: 540,
  },
  {
    id: 'fx-tandoor',
    name: 'Charcoal & Clay — Tandoori Grill',
    cuisine: 'north-indian',
    rating: 4.4,
    ratingCount: 980,
    priceLevel: 2,
    distanceMetres: 760,
  },
  {
    id: 'fx-med-grill',
    name: 'Olive & Ember — Mediterranean Grill',
    cuisine: 'mediterranean',
    rating: 4.6,
    ratingCount: 640,
    priceLevel: 3,
    distanceMetres: 890,
  },
  {
    id: 'fx-levant',
    name: 'Levant Kitchen — Middle Eastern',
    cuisine: 'middle-eastern',
    rating: 4.2,
    ratingCount: 410,
    priceLevel: 2,
    distanceMetres: 1100,
  },
  {
    id: 'fx-sushi',
    name: 'Hinoki — Sushi & Donburi',
    cuisine: 'japanese',
    rating: 4.7,
    ratingCount: 520,
    priceLevel: 3,
    distanceMetres: 1350,
  },
  {
    id: 'fx-wok',
    name: 'Iron Wok — Pan Asian',
    cuisine: 'east-asian',
    rating: 4.1,
    ratingCount: 1120,
    priceLevel: 2,
    distanceMetres: 700,
  },
  {
    id: 'fx-thai',
    name: 'Lemongrass — Thai',
    cuisine: 'thai',
    rating: 4.3,
    ratingCount: 380,
    priceLevel: 2,
    distanceMetres: 1580,
  },
  {
    id: 'fx-burger',
    name: 'Patty Yard — Burgers & Fries',
    cuisine: 'american',
    rating: 4.0,
    ratingCount: 2400,
    priceLevel: 2,
    distanceMetres: 430,
  },
  {
    id: 'fx-pizza',
    name: 'Forno — Wood-Fired Pizza',
    cuisine: 'continental',
    rating: 4.4,
    ratingCount: 1660,
    priceLevel: 2,
    distanceMetres: 620,
  },
];

export const FIXTURE_RESTAURANTS: readonly Restaurant[] = FIXTURE_INPUTS.map((input) => ({
  id: input.id,
  name: input.name,
  cuisine: input.cuisine,
  providerTypes: [],
  rating: input.rating,
  ratingCount: input.ratingCount,
  priceLevel: input.priceLevel,
  distanceMetres: input.distanceMetres,
  address: null,
  openNow: null,
  source: 'fixture' as const,
  mapsUri: null,
}));

/** Rendered wherever fixture results are shown, so the fallback is never silent. */
export const FIXTURE_DISCLOSURE =
  'Showing example venues — live nearby search is unavailable right now.';
