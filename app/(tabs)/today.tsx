import { useCallback, useMemo } from 'react';
import { Dimensions, RefreshControl, ScrollView, StyleSheet, Text, View } from 'react-native';
import Animated, { useAnimatedScrollHandler, useSharedValue } from 'react-native-reanimated';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useRouter } from 'expo-router';
import { useQueryClient } from '@tanstack/react-query';
import { Calendar, HeartPulse, RefreshCw, Settings2 } from 'lucide-react-native';

import { ActivityCard, ITEM_SIZE, type Activity } from '@/components/ActivityCard';
import { ReadinessRing } from '@/components/health/ReadinessRing';
import { MetricCard } from '@/components/health/MetricCard';
import { MetricCardSkeleton } from '@/components/ui/Skeleton';
import { IconButton } from '@/components/ui/Button';
import { Card } from '@/components/ui/Card';
import { READINESS_COPY } from '@/features/correlation/readiness';
import { useInsights, useSuggestionFeed } from '@/features/insights/use-insights';
import { useHealthSeries } from '@/features/health/queries';
import { buildEngineContext } from '@/features/correlation/context';
import { useSettingsStore, selectSex } from '@/store/settings.store';
import { useHealthStore } from '@/store/health.store';
import { queryKeys } from '@/lib/query-client';
import { METRIC_META } from '@/schemas/health';
import type { InsightDomain, Suggestion } from '@/schemas/insights';
import { palette, SEVERITY_COLOR } from '@/theme/colors';

const { width: SCREEN_WIDTH } = Dimensions.get('window');

const DOMAIN_TO_CARD: Record<InsightDomain, Activity['type']> = {
  nutrition: 'nutrition',
  training: 'training',
  sleep: 'sleep',
  recovery: 'recovery',
  stress: 'recovery',
  'medical-referral': 'doctor',
};

const EFFORT_TAG: Record<Suggestion['effort'], string> = {
  low: 'EASY',
  medium: 'STEADY',
  high: 'COMMIT',
};

/** Shown before there is anything to analyse, so the carousel is never empty. */
const ONBOARDING_CARDS: Activity[] = [
  {
    id: 'connect-health',
    time: 'STEP 1',
    title: 'Connect Apple Health',
    subtitle: 'HRV, sleep and resting heart rate',
    type: 'recovery',
  },
  {
    id: 'add-labs',
    time: 'STEP 2',
    title: 'Add a blood report',
    subtitle: 'PDF or a photo of the printout',
    type: 'doctor',
  },
  {
    id: 'get-insights',
    time: 'STEP 3',
    title: 'Get your correlations',
    subtitle: 'Where your labs meet your telemetry',
    type: 'nutrition',
  },
];

function formatToday(): string {
  return new Date()
    .toLocaleDateString(undefined, {
      weekday: 'long',
      day: 'numeric',
      month: 'long',
      year: 'numeric',
    })
    .toUpperCase();
}

export default function TodayScreen() {
  const router = useRouter();
  const queryClient = useQueryClient();
  const scrollX = useSharedValue(0);

  const sex = useSettingsStore(selectSex);
  const permission = useHealthStore((s) => s.permission);
  const { readiness, insights, isLoading } = useInsights();
  const { feed } = useSuggestionFeed();
  const { data: series, isFetching, refetch } = useHealthSeries();

  const scrollHandler = useAnimatedScrollHandler({
    onScroll: (event) => {
      scrollX.value = event.contentOffset.x;
    },
  });

  const onRefresh = useCallback(() => {
    void refetch();
    void queryClient.invalidateQueries({ queryKey: queryKeys.insights.all });
  }, [refetch, queryClient]);

  // The metric tiles need the same derived stats the engine uses. Rebuilding
  // the context here (rather than threading it out of `useInsights`) keeps the
  // hook's public surface small; it is a pure O(n) pass over the window.
  const metrics = useMemo(() => {
    if (!series || series.length === 0) return null;
    return buildEngineContext({
      series,
      biomarkers: [],
      labReportId: null,
      labCollectedAt: null,
      sex,
    }).metrics;
  }, [series, sex]);

  const cards = useMemo<Activity[]>(() => {
    if (feed.length === 0) return ONBOARDING_CARDS;

    return feed.slice(0, 6).map(({ suggestion, source }) => ({
      id: suggestion.id,
      time: EFFORT_TAG[suggestion.effort],
      title: suggestion.title,
      subtitle: source.title,
      type: DOMAIN_TO_CARD[suggestion.domain],
      accent: SEVERITY_COLOR[source.severity],
    }));
  }, [feed]);

  const centerSpacer = (SCREEN_WIDTH - ITEM_SIZE) / 2;
  const readinessCopy = readiness ? READINESS_COPY[readiness.band] : null;

  return (
    <SafeAreaView className="flex-1" style={styles.container} edges={['top']}>
      {/* Decorative background wash from the design */}
      <View style={styles.topLightCircle} pointerEvents="none" />
      <View style={styles.bottomLightCircle} pointerEvents="none" />

      <ScrollView
        showsVerticalScrollIndicator={false}
        contentContainerStyle={{ paddingBottom: 140 }}
        refreshControl={
          <RefreshControl
            refreshing={isFetching}
            onRefresh={onRefresh}
            tintColor={palette.accent}
          />
        }
      >
        {/* HEADER */}
        <View className="mt-2 w-full flex-row items-center justify-between px-6">
          <IconButton
            icon={Settings2}
            label="Settings"
            tone="onCanvas"
            onPress={() => router.push('/(tabs)/settings')}
          />
          <IconButton icon={RefreshCw} label="Sync health data" tone="onCanvas" onPress={onRefresh} />
        </View>

        {/* TITLE & DATE */}
        <View className="mt-6 items-center px-6">
          <Text className="text-3xl font-bold tracking-wide text-white">Today&apos;s Focus</Text>

          <View className="mt-4 flex-row items-center gap-2 rounded-full border border-white/5 bg-black/25 px-4 py-2">
            <Calendar size={14} color={palette.accent} strokeWidth={2} />
            <Text className="text-[10px] font-bold uppercase tracking-widest text-white/80">
              {formatToday()}
            </Text>
          </View>
        </View>

        {/* READINESS */}
        <View className="mt-7 flex-row items-center gap-5 px-6">
          <ReadinessRing readiness={readiness} size={116} />
          <View className="flex-1">
            <Text className="text-[11px] font-semibold uppercase tracking-wider text-white/50">
              Readiness
            </Text>
            <Text className="mt-1 text-[15px] font-semibold leading-5 text-white">
              {readinessCopy?.label ?? 'Not enough data yet'}
            </Text>
            <Text className="mt-1.5 text-[12px] leading-4 text-white/60">
              {readinessCopy?.blurb ??
                (permission === 'granted'
                  ? 'Keep wearing your watch — 7 days builds your personal baseline.'
                  : 'Connect Apple Health to start building your baseline.')}
            </Text>
          </View>
        </View>

        {/* FAN CAROUSEL — today's highest-yield actions */}
        <View className="mt-4 items-center justify-center" style={{ height: 380 }}>
          <Animated.FlatList
            data={cards}
            keyExtractor={(item) => item.id}
            horizontal
            showsHorizontalScrollIndicator={false}
            snapToInterval={ITEM_SIZE}
            decelerationRate="fast"
            snapToAlignment="center"
            contentContainerStyle={{ paddingHorizontal: centerSpacer, alignItems: 'center' }}
            onScroll={scrollHandler}
            scrollEventThrottle={16}
            // The fan transform means neighbours are always partly visible;
            // clipping them would pop cards in and out at the edges.
            removeClippedSubviews={false}
            renderItem={({ item, index }) => (
              <ActivityCard
                activity={item}
                index={index}
                scrollX={scrollX}
                totalItems={cards.length}
              />
            )}
          />
        </View>

        {/* TOP FINDING */}
        {insights[0] && (
          <View className="mt-2 px-6">
            <Text className="mb-3 text-[11px] font-semibold uppercase tracking-wider text-white/50">
              Why this matters
            </Text>
            <Card tone="translucent">
              <View className="flex-row items-start gap-3">
                <HeartPulse size={18} color={SEVERITY_COLOR[insights[0].severity]} strokeWidth={2.2} />
                <View className="flex-1">
                  <Text className="text-[15px] font-semibold leading-5 text-white">
                    {insights[0].title}
                  </Text>
                  <Text className="mt-1.5 text-[12px] leading-[18px] text-white/60" numberOfLines={3}>
                    {insights[0].summary}
                  </Text>
                </View>
              </View>
            </Card>
          </View>
        )}

        {/* METRIC GRID */}
        <View className="mt-7 px-6">
          <Text className="mb-3 text-[11px] font-semibold uppercase tracking-wider text-white/50">
            Your telemetry
          </Text>

          {isLoading || !metrics ? (
            <View className="gap-3">
              <View className="flex-row gap-3">
                <MetricCardSkeleton />
                <MetricCardSkeleton />
              </View>
              <View className="flex-row gap-3">
                <MetricCardSkeleton />
                <MetricCardSkeleton />
              </View>
            </View>
          ) : (
            <View className="gap-3">
              <View className="flex-row gap-3">
                <MetricCard stats={metrics.hrv} />
                <MetricCard stats={metrics.restingHeartRate} />
              </View>
              <View className="flex-row gap-3">
                <MetricCard stats={metrics.sleepDuration} />
                <MetricCard stats={metrics.steps} />
              </View>
              <View className="flex-row gap-3">
                <MetricCard stats={metrics.activeEnergy} />
                <MetricCard stats={metrics.sleepEfficiency} />
              </View>
            </View>
          )}

          <Text className="mt-3 text-center text-[11px] text-white/35">
            {series?.length ?? 0} days analysed · {METRIC_META.hrv.short} drives readiness most
          </Text>
        </View>
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    backgroundColor: palette.bg,
  },
  topLightCircle: {
    position: 'absolute',
    top: -SCREEN_WIDTH * 0.4,
    left: -SCREEN_WIDTH * 0.2,
    width: SCREEN_WIDTH * 1.4,
    height: SCREEN_WIDTH * 1.4,
    borderRadius: SCREEN_WIDTH * 0.7,
    backgroundColor: '#7170C4',
    opacity: 0.35,
  },
  bottomLightCircle: {
    position: 'absolute',
    bottom: -SCREEN_WIDTH * 0.4,
    right: -SCREEN_WIDTH * 0.2,
    width: SCREEN_WIDTH * 1.2,
    height: SCREEN_WIDTH * 1.2,
    borderRadius: SCREEN_WIDTH * 0.6,
    backgroundColor: '#4E4CA0',
    opacity: 0.4,
  },
});
