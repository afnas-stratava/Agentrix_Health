import { useEffect, useMemo } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import type { DailySnapshot, HealthPermissionState } from '@/schemas/health';
import { queryKeys } from '@/lib/query-client';
import { addDays, nowIso, startOfLocalDay } from '@/lib/date';
import { log } from '@/lib/logger';
import { useHealthStore } from '@/store/health.store';
import { useSettingsStore, selectAnalysisWindow } from '@/store/settings.store';
import { healthProvider } from './provider';
import { aggregateDailySnapshots } from './aggregate';

/**
 * Reads the requested window from the active provider and collapses it into
 * daily snapshots. The aggregation is intentionally inside the query function
 * rather than a `select`, so the expensive interval sweep runs once per fetch
 * instead of once per subscribed component.
 */
export function useHealthSeries(days?: number) {
  const configuredWindow = useSettingsStore(selectAnalysisWindow);
  const windowDays = days ?? configuredWindow;
  const permission = useHealthStore((s) => s.permission);
  const markSynced = useHealthStore((s) => s.markSynced);

  return useQuery({
    queryKey: queryKeys.health.series(windowDays),
    enabled: permission === 'granted',
    queryFn: async (): Promise<DailySnapshot[]> => {
      const to = new Date();
      // Reach back one extra day so a sleep session that ended after midnight
      // still has its full preceding-night samples inside the range.
      const from = startOfLocalDay(addDays(to, -(windowDays + 1)));

      const raw = await healthProvider.fetchRange(from, to);
      const snapshots = aggregateDailySnapshots(raw, addDays(to, -windowDays), to);

      const hadData = snapshots.some(
        (s) => s.hrv != null || s.restingHeartRate != null || s.sleep != null || s.steps != null,
      );
      markSynced(nowIso(), hadData);

      return snapshots;
    },
    // A user opening the app twice in a minute does not need a fresh
    // 90-day HealthKit sweep.
    staleTime: 5 * 60_000,
  });
}

export function useTodaySnapshot() {
  const { data, ...rest } = useHealthSeries();
  const today = useMemo(() => (data && data.length > 0 ? data[data.length - 1] : undefined), [data]);
  return { ...rest, data: today };
}

/** Drives the permission-priming flow; never called implicitly on mount. */
export function useRequestHealthAccess() {
  const queryClient = useQueryClient();
  const setPermission = useHealthStore((s) => s.setPermission);

  return useMutation<HealthPermissionState>({
    mutationFn: () => healthProvider.requestAuthorization(),
    onSuccess: (state) => {
      setPermission(state);
      if (state === 'granted') {
        void queryClient.invalidateQueries({ queryKey: queryKeys.health.all });
      }
    },
  });
}

/** Resolves availability + stored grant on cold start. */
export function useHealthPermissionSync() {
  const setPermission = useHealthStore((s) => s.setPermission);
  const stored = useHealthStore((s) => s.permission);

  useEffect(() => {
    let cancelled = false;

    void (async () => {
      const available = await healthProvider.isAvailable();
      if (cancelled) return;

      if (!available) {
        setPermission('unavailable');
        return;
      }

      // A previously-granted app can re-init silently — iOS will not show the
      // sheet a second time, so this restores access without user friction.
      if (stored === 'granted') {
        const state = await healthProvider.requestAuthorization();
        if (!cancelled) setPermission(state);
      }
    })();

    return () => {
      cancelled = true;
    };
    // Intentionally runs once: re-running on every permission change would
    // loop through requestAuthorization.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);
}

/**
 * Subscribes to HealthKit background-delivery notifications and invalidates the
 * telemetry cache when new samples land, so the dashboard updates without a
 * pull-to-refresh.
 */
export function useHealthObserver() {
  const queryClient = useQueryClient();
  const permission = useHealthStore((s) => s.permission);

  useEffect(() => {
    if (permission !== 'granted') return undefined;

    let timer: ReturnType<typeof setTimeout> | null = null;

    // HealthKit can fire several observers in a burst after a Watch sync;
    // debounce so one sync triggers one refetch.
    const unsubscribe = healthProvider.subscribe(() => {
      if (timer) clearTimeout(timer);
      timer = setTimeout(() => {
        log.debug('health', 'Observer fired — invalidating telemetry');
        void queryClient.invalidateQueries({ queryKey: queryKeys.health.all });
      }, 2000);
    });

    return () => {
      if (timer) clearTimeout(timer);
      unsubscribe();
    };
  }, [permission, queryClient]);
}
