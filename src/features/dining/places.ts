import * as Application from 'expo-application';

import type { Cuisine } from '@/schemas/profile';
import type { Restaurant } from '@/schemas/dining';
import { RestaurantSchema } from '@/schemas/dining';
import { env } from '@/lib/env';
import { log } from '@/lib/logger';

/**
 * Google Places API (New) — Nearby Search.
 *
 * Called directly from the device because this build has no backend. The key is
 * therefore in the bundle and MUST be restricted in the Cloud console to this
 * bundle identifier and to the Places API alone; an unrestricted key in a
 * shipped app is a billing incident waiting to happen. See README.
 *
 * Every failure path here is non-fatal: the caller falls back to the curated
 * fixture set, so a dead network, an exhausted quota or a missing key degrades
 * the feature to "plausible nearby restaurants" rather than an error screen.
 */

const ENDPOINT = 'https://places.googleapis.com/v1/places:searchNearby';

/**
 * Field mask is mandatory on the new API and is what you are billed on — asking
 * for photos or opening hours here would move this into a pricier SKU for no
 * benefit, since the UI shows neither.
 */
const FIELD_MASK = [
  'places.id',
  'places.displayName',
  'places.primaryType',
  'places.types',
  'places.rating',
  'places.userRatingCount',
  'places.priceLevel',
  'places.location',
  'places.shortFormattedAddress',
  'places.googleMapsUri',
].join(',');

const REQUEST_TIMEOUT_MS = 8000;

/**
 * Provider type strings mapped onto our cuisine vocabulary. Ordered most
 * specific first — `south_indian_restaurant` must win over `indian_restaurant`,
 * which must win over the bare `restaurant`.
 */
const TYPE_TO_CUISINE: Array<[string, Cuisine]> = [
  ['south_indian_restaurant', 'south-indian'],
  ['north_indian_restaurant', 'north-indian'],
  ['indian_restaurant', 'north-indian'],
  ['mediterranean_restaurant', 'mediterranean'],
  ['greek_restaurant', 'mediterranean'],
  ['middle_eastern_restaurant', 'middle-eastern'],
  ['lebanese_restaurant', 'middle-eastern'],
  ['turkish_restaurant', 'middle-eastern'],
  ['japanese_restaurant', 'japanese'],
  ['sushi_restaurant', 'japanese'],
  ['ramen_restaurant', 'japanese'],
  ['thai_restaurant', 'thai'],
  ['vietnamese_restaurant', 'east-asian'],
  ['chinese_restaurant', 'east-asian'],
  ['korean_restaurant', 'east-asian'],
  ['asian_restaurant', 'east-asian'],
  ['mexican_restaurant', 'mexican'],
  ['american_restaurant', 'american'],
  ['hamburger_restaurant', 'american'],
  ['italian_restaurant', 'continental'],
  ['pizza_restaurant', 'continental'],
  ['french_restaurant', 'continental'],
];

export function inferCuisine(types: string[]): Cuisine | null {
  for (const [type, cuisine] of TYPE_TO_CUISINE) {
    if (types.includes(type)) return cuisine;
  }
  return null;
}

/** Haversine distance in metres. */
export function distanceBetween(
  a: { latitude: number; longitude: number },
  b: { latitude: number; longitude: number },
): number {
  const R = 6_371_000;
  const toRad = (deg: number) => (deg * Math.PI) / 180;
  const dLat = toRad(b.latitude - a.latitude);
  const dLon = toRad(b.longitude - a.longitude);
  const lat1 = toRad(a.latitude);
  const lat2 = toRad(b.latitude);

  const h =
    Math.sin(dLat / 2) ** 2 + Math.sin(dLon / 2) ** 2 * Math.cos(lat1) * Math.cos(lat2);
  return Math.round(2 * R * Math.asin(Math.sqrt(h)));
}

/** Places (New) returns price level as an enum string, not a number. */
const PRICE_LEVEL: Record<string, number> = {
  PRICE_LEVEL_INEXPENSIVE: 1,
  PRICE_LEVEL_MODERATE: 2,
  PRICE_LEVEL_EXPENSIVE: 3,
  PRICE_LEVEL_VERY_EXPENSIVE: 4,
};

interface PlacesResponsePlace {
  id?: string;
  displayName?: { text?: string };
  primaryType?: string;
  types?: string[];
  rating?: number;
  userRatingCount?: number;
  priceLevel?: string;
  location?: { latitude?: number; longitude?: number };
  shortFormattedAddress?: string;
  googleMapsUri?: string;
}

export interface NearbySearchInput {
  latitude: number;
  longitude: number;
  /** Metres. Google caps this at 50,000; 2 km is the useful default for food. */
  radiusMetres?: number;
  maxResults?: number;
  signal?: AbortSignal;
}

export const isPlacesConfigured = (): boolean => env.placesApiKey !== '';

export async function searchNearbyRestaurants({
  latitude,
  longitude,
  radiusMetres = 2000,
  maxResults = 20,
  signal,
}: NearbySearchInput): Promise<Restaurant[]> {
  if (!isPlacesConfigured()) {
    log.info('dining', 'No Places API key — using fixtures');
    return [];
  }

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);
  // Honour an upstream cancellation (screen unmount) as well as our timeout.
  signal?.addEventListener('abort', () => controller.abort(), { once: true });

  try {
    const response = await fetch(ENDPOINT, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': env.placesApiKey,
        'X-Goog-FieldMask': FIELD_MASK,
        // An "iOS apps" key restriction is enforced against this header, which
        // Google's native SDKs send for you but a raw fetch does not. Without
        // it a correctly-restricted key rejects our own requests with
        // API_KEY_IOS_APP_BLOCKED and iosBundleId=<empty>.
        ...(Application.applicationId
          ? { 'X-Ios-Bundle-Identifier': Application.applicationId }
          : {}),
      },
      body: JSON.stringify({
        includedTypes: ['restaurant'],
        maxResultCount: Math.min(20, maxResults),
        rankPreference: 'DISTANCE',
        locationRestriction: {
          circle: {
            center: { latitude, longitude },
            radius: Math.min(50_000, radiusMetres),
          },
        },
      }),
      signal: controller.signal,
    });

    if (!response.ok) {
      log.warn('dining', `Places search failed: ${response.status}`);
      return [];
    }

    const body = (await response.json()) as { places?: PlacesResponsePlace[] };
    const places = body.places ?? [];

    const mapped: Restaurant[] = [];
    for (const place of places) {
      if (place.id == null || place.displayName?.text == null) continue;

      const types = place.types ?? [];
      const allTypes = place.primaryType ? [place.primaryType, ...types] : types;

      const parsed = RestaurantSchema.safeParse({
        id: place.id,
        name: place.displayName.text,
        cuisine: inferCuisine(allTypes),
        providerTypes: allTypes,
        rating: place.rating ?? null,
        ratingCount: place.userRatingCount ?? 0,
        priceLevel: place.priceLevel != null ? (PRICE_LEVEL[place.priceLevel] ?? null) : null,
        distanceMetres:
          place.location?.latitude != null && place.location.longitude != null
            ? distanceBetween(
                { latitude, longitude },
                { latitude: place.location.latitude, longitude: place.location.longitude },
              )
            : null,
        address: place.shortFormattedAddress ?? null,
        openNow: null,
        source: 'places',
        mapsUri: place.googleMapsUri ?? null,
      });

      // One malformed row should not take out the whole list.
      if (parsed.success) mapped.push(parsed.data);
      else log.debug('dining', `Dropped a malformed place: ${place.id}`);
    }

    return mapped;
  } catch (error) {
    log.warn('dining', 'Places search errored — falling back to fixtures', error);
    return [];
  } finally {
    clearTimeout(timer);
  }
}
