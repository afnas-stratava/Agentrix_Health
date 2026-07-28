import { QueryClient } from '@tanstack/react-query';
import { ApiError, ValidationError } from './api';
import { log } from './logger';

export const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      // Telemetry is expensive to read from HealthKit; a minute of staleness
      // is imperceptible and keeps tab switches instant.
      staleTime: 60_000,
      gcTime: 30 * 60_000,
      retry: (failureCount, error) => {
        if (error instanceof ValidationError) return false;
        if (error instanceof ApiError && !error.isRetryable) return false;
        return failureCount < 2;
      },
      retryDelay: (attempt) => Math.min(1000 * 2 ** attempt, 8000),
      refetchOnWindowFocus: false,
      refetchOnReconnect: true,
    },
    mutations: {
      retry: false,
      onError: (error) => log.error('api', 'Mutation failed', error),
    },
  },
});

/**
 * Hierarchical, typed cache keys. Never inline a key literal at a call site —
 * invalidation correctness depends on these prefixes matching exactly.
 */
export const queryKeys = {
  health: {
    all: ['health'] as const,
    permissions: () => [...queryKeys.health.all, 'permissions'] as const,
    series: (days: number) => [...queryKeys.health.all, 'series', days] as const,
    today: () => [...queryKeys.health.all, 'today'] as const,
  },
  labs: {
    all: ['labs'] as const,
    list: () => [...queryKeys.labs.all, 'list'] as const,
    detail: (id: string) => [...queryKeys.labs.all, 'detail', id] as const,
  },
  insights: {
    all: ['insights'] as const,
    computed: (labIds: string[], windowDays: number) =>
      [...queryKeys.insights.all, 'computed', labIds.join('|'), windowDays] as const,
    readiness: () => [...queryKeys.insights.all, 'readiness'] as const,
  },
} as const;
