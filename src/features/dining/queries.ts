import { useCallback, useMemo, useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import * as Location from 'expo-location';
import type { DiningMode, RestaurantPick } from '@/schemas/dining';
import { queryKeys } from '@/lib/query-client';
import { log } from '@/lib/logger';
import { useProfile } from '@/features/profile/use-profile';
import { useDailyBrief, useTodayProgress } from '@/features/brief/use-brief';
import { useNutritionStore } from '@/store/nutrition.store';
import { toIsoDay } from '@/lib/date';
import { FIXTURE_RESTAURANTS } from './fixtures';
import { searchNearbyRestaurants, isPlacesConfigured, distanceBetween } from './places';
import { rankRestaurants } from './rank';

/**
 * Nearby dining, ranked against today's remaining macros.
 *
 * Location is requested at the moment the user opens the screen, never on
 * launch — a health app that asks for location on first run reads as a tracking
 * app. Denial is a first-class path, not an error: the fixture venues render
 * with their distances intact and the ranking still works.
 */

export type LocationState = 'idle' | 'requesting' | 'granted' | 'denied' | 'unavailable';

export interface Coordinates {
  latitude: number;
  longitude: number;
}

export function useLocationPermission() {
  const [state, setState] = useState<LocationState>('idle');
  const [coords, setCoords] = useState<Coordinates | null>(null);

  const request = useCallback(async () => {
    setState('requesting');
    try {
      const { status } = await Location.requestForegroundPermissionsAsync();
      if (status !== 'granted') {
        setState('denied');
        return null;
      }

      const position = await Location.getCurrentPositionAsync({
        // Street-level precision is ample for "restaurants near me", and the
        // cheaper accuracy tier gets a fix in a second rather than fifteen.
        accuracy: Location.Accuracy.Balanced,
      });

      const next = {
        latitude: position.coords.latitude,
        longitude: position.coords.longitude,
      };
      setCoords(next);
      setState('granted');
      return next;
    } catch (error) {
      log.warn('dining', 'Location lookup failed', error);
      setState('unavailable');
      return null;
    }
  }, []);

  return { state, coords, request };
}

interface NearbyResult {
  picks: RestaurantPick[];
  /** True when the list came from fixtures rather than live search. */
  isFixture: boolean;
  isLoading: boolean;
  refetch: () => void;
}

export function useNearbyDining(coords: Coordinates | null, mode: DiningMode): NearbyResult {
  const profile = useProfile();
  const { targets, consumed } = useTodayProgress();
  const { brief } = useDailyBrief();

  const focusTags = useMemo(() => brief?.foodFocus.tags ?? [], [brief]);

  const query = useQuery({
    queryKey: queryKeys.dining.nearby(coords?.latitude ?? null, coords?.longitude ?? null),
    // Without coordinates there is nothing to search; fixtures cover that case
    // synchronously below rather than through a fetch.
    enabled: coords != null && isPlacesConfigured(),
    queryFn: async () => searchNearbyRestaurants({ ...coords! }),
    // Restaurants near a fixed point do not change minute to minute, and each
    // call is billed.
    staleTime: 10 * 60_000,
  });

  const restaurants = useMemo(() => {
    const live = query.data ?? [];
    if (live.length > 0) return live;

    // Fixtures, with real distances when we know where the user is so the
    // fallback still sorts sensibly.
    if (coords == null) return FIXTURE_RESTAURANTS;
    return FIXTURE_RESTAURANTS.map((restaurant, index) => ({
      ...restaurant,
      distanceMetres:
        restaurant.distanceMetres ??
        distanceBetween(coords, {
          latitude: coords.latitude + index * 0.001,
          longitude: coords.longitude + index * 0.001,
        }),
    }));
  }, [query.data, coords]);

  const picks = useMemo(
    () =>
      rankRestaurants({
        restaurants: [...restaurants],
        profile,
        targets,
        consumed,
        mode,
        focusTags,
      }),
    [restaurants, profile, targets, consumed, mode, focusTags],
  );

  return {
    picks,
    isFixture: (query.data?.length ?? 0) === 0,
    isLoading: query.isLoading,
    refetch: () => void query.refetch(),
  };
}

/** Cheat-day state for today, shared by the dining screen and the food tab. */
export function useDiningMode(): { mode: DiningMode; toggle: () => void } {
  const cheatDays = useNutritionStore((s) => s.cheatDays);
  const toggleCheatDay = useNutritionStore((s) => s.toggleCheatDay);
  const day = toIsoDay(new Date());

  return {
    mode: cheatDays.includes(day) ? 'cheat' : 'aligned',
    toggle: () => toggleCheatDay(day),
  };
}
