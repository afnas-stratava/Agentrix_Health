import { useCallback, useMemo } from 'react';
import { Dimensions, RefreshControl, ScrollView, StyleSheet, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { LinearGradient } from 'expo-linear-gradient';
import { useRouter } from 'expo-router';
import { useQueryClient } from '@tanstack/react-query';
import {
  CheckCircle2,
  ChevronRight,
  Flame,
  MapPin,
  RefreshCw,
  Settings2,
  ShieldAlert,
  Sparkles,
} from 'lucide-react-native';

import { ReadinessHero } from '@/components/health/ReadinessHero';
import { SignalChip, StatTile } from '@/components/health/StatTile';
import { HeadlineInsight } from '@/components/insights/HeadlineInsight';
import { ActionRow } from '@/components/insights/ActionRow';
import { LabStatusCard } from '@/components/labs/LabStatusCard';
import { SectionHeader } from '@/components/ui/SectionHeader';
import { Card } from '@/components/ui/Card';
import { IconButton } from '@/components/ui/Button';
import { PressableScale } from '@/components/ui/PressableScale';
import { Skeleton } from '@/components/ui/Skeleton';
import { FadeIn } from '@/components/ui/FadeIn';

import { useInsights, useSuggestionFeed } from '@/features/insights/use-insights';
import { useDailyBrief, useTodayProgress } from '@/features/brief/use-brief';
import { useHealthSeries } from '@/features/health/queries';
import { buildEngineContext } from '@/features/correlation/context';
import { mergeBiomarkers } from '@/features/correlation/engine';
import { enrichBiomarker, needsAttention } from '@/features/labs/reference-ranges';
import { useSettingsStore, selectSex } from '@/store/settings.store';
import { useHealthStore } from '@/store/health.store';
import { useLabsStore } from '@/store/labs.store';
import { queryKeys } from '@/lib/query-client';
import { palette } from '@/theme/colors';

const { width: SCREEN_WIDTH } = Dimensions.get('window');

/** How many actions to surface before deferring to the Insights tab. */
const MAX_ACTIONS = 3;

function greeting(): string {
  const hour = new Date().getHours();
  if (hour < 12) return 'Good morning';
  if (hour < 18) return 'Good afternoon';
  return 'Good evening';
}

function formatToday(): string {
  return new Date().toLocaleDateString(undefined, {
    weekday: 'long',
    day: 'numeric',
    month: 'long',
  });
}

/**
 * Sync freshness at minute granularity. The date alone does not tell you
 * whether the numbers below it are current, and "synced 4m ago" is the
 * difference between trusting a flat HRV reading and pulling to refresh.
 */
function syncLabel(iso: string | null): string | null {
  if (!iso) return null;
  const minutes = Math.floor((Date.now() - new Date(iso).getTime()) / 60_000);
  if (!Number.isFinite(minutes) || minutes < 0) return null;
  if (minutes < 1) return 'synced just now';
  if (minutes < 60) return `synced ${minutes}m ago`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `synced ${hours}h ago`;
  return `synced ${Math.floor(hours / 24)}d ago`;
}

export default function TodayScreen() {
  const router = useRouter();
  const queryClient = useQueryClient();

  const sex = useSettingsStore(selectSex);
  const permission = useHealthStore((s) => s.permission);
  const lastSyncedAt = useHealthStore((s) => s.lastSyncedAt);
  const reports = useLabsStore((s) => s.reports);

  const { readiness, insights, isLoading, hasLabData } = useInsights();
  const { feed } = useSuggestionFeed();
  const { data: series, isFetching, refetch } = useHealthSeries();
  const { brief } = useDailyBrief();
  const { targets, consumed, remainingCalories } = useTodayProgress();

  const onRefresh = useCallback(() => {
    void refetch();
    void queryClient.invalidateQueries({ queryKey: queryKeys.insights.all });
  }, [refetch, queryClient]);

  // The tiles need the same derived stats the engine uses. Rebuilding the
  // context here (rather than widening the hook's return type) is a pure O(n)
  // pass over the window.
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

  const latestReport = useMemo(
    () => reports.find((r) => r.status === 'ready' || r.status === 'needs-review') ?? null,
    [reports],
  );

  const flaggedCount = useMemo(() => {
    const ready = reports.filter((r) => r.status === 'ready' || r.status === 'needs-review');
    return mergeBiomarkers(ready)
      .map((b) => enrichBiomarker(b, sex))
      .filter((b) => needsAttention(b.flag)).length;
  }, [reports, sex]);

  const actions = useMemo(() => feed.slice(0, MAX_ACTIONS), [feed]);
  const headline = insights[0] ?? null;
  const urgentCount = insights.filter((i) => i.severity === 'urgent').length;

  // Recomputed whenever a sync lands rather than on a ticking interval — a
  // timer firing every minute to age a label is not worth the wakeups.
  const synced = useMemo(() => syncLabel(lastSyncedAt), [lastSyncedAt]);

  const baselineHint =
    permission === 'granted'
      ? 'Keep wearing your watch — seven days of data unlocks your score.'
      : 'Connect Apple Health to start building your baseline.';

  return (
    <SafeAreaView className="flex-1 bg-canvas" edges={['top']}>
      {/* Soft green wash behind the content, echoing the reference's ambiance */}
      <LinearGradient
        colors={['#E4F4DA', '#F4FAF1', '#FBFDF9']}
        locations={[0, 0.45, 1]}
        style={StyleSheet.absoluteFill}
        pointerEvents="none"
      />
      <View style={styles.glowTop} pointerEvents="none" />
      <View style={styles.glowBottom} pointerEvents="none" />

      <ScrollView
        showsVerticalScrollIndicator={false}
        contentContainerStyle={{ paddingBottom: 130 }}
        refreshControl={
          <RefreshControl refreshing={isFetching} onRefresh={onRefresh} tintColor={palette.brand} />
        }
      >
        {/* HEADER */}
        <View className="mt-1 flex-row items-center justify-between px-5">
          <View className="flex-1 pr-3">
            <View className="flex-row items-center gap-1.5">
              <Text className="text-[11px] font-medium text-muted">{formatToday()}</Text>
              {synced && (
                <>
                  <View className="h-[3px] w-[3px] rounded-full bg-faint" />
                  <Text className="text-[11px] font-medium text-faint">{synced}</Text>
                </>
              )}
            </View>
            <Text className="mt-0.5 text-[25px] font-bold leading-[30px] text-ink">
              {greeting()}
            </Text>
          </View>

          <View className="flex-row gap-2">
            <IconButton
              icon={RefreshCw}
              label="Sync health data"
              busy={isFetching}
              onPress={onRefresh}
            />
            <IconButton
              icon={Settings2}
              label="Settings"
              onPress={() => router.push('/(tabs)/settings')}
            />
          </View>
        </View>

        {/* URGENT — the one thing that outranks readiness. Tappable, because a
            "see a clinician" banner that goes nowhere is the one dead end on
            this screen a user would actually try to follow. */}
        {urgentCount > 0 && (
          <FadeIn className="mt-4 px-5">
            <PressableScale
              scaleTo={0.98}
              accessibilityRole="button"
              accessibilityLabel={
                urgentCount === 1
                  ? 'One finding is worth taking to a clinician'
                  : `${urgentCount} findings are worth taking to a clinician`
              }
              accessibilityHint="Opens the full findings list"
              onPress={() => router.push('/(tabs)/insights')}
              className="flex-row items-center gap-2.5 rounded-2xl border border-critical/25 bg-critical/8 px-4 py-3"
            >
              <ShieldAlert size={17} color={palette.critical} strokeWidth={2.3} />
              <Text className="flex-1 text-[12px] leading-4 text-ink/80">
                {urgentCount === 1
                  ? 'One finding is worth taking to a clinician.'
                  : `${urgentCount} findings are worth taking to a clinician.`}
              </Text>
              <ChevronRight size={15} color={palette.critical} strokeWidth={2.4} />
            </PressableScale>
          </FadeIn>
        )}

        {/* MORNING BRIEF — the composed plan for the day. Sits above readiness
            because it *contains* readiness: the score is an input to it, and a
            user who reads one thing should read the plan, not the number. */}
        {brief && (
          <FadeIn delay={20} className="mt-4 px-5">
            <PressableScale
              scaleTo={0.98}
              accessibilityRole="button"
              accessibilityLabel={`Your morning brief: ${brief.headline}`}
              accessibilityHint="Opens today's full plan"
              onPress={() => router.push('/brief')}
              className="rounded-2xl border border-brand-200 bg-brand-50 px-4 py-3.5"
            >
              <View className="flex-row items-center gap-2">
                <Sparkles size={15} color={palette.brand} strokeWidth={2.3} />
                <Text className="flex-1 text-[10px] font-bold uppercase tracking-wider text-brand-700">
                  Your brief for today
                </Text>
                <ChevronRight size={15} color={palette.brand} strokeWidth={2.4} />
              </View>

              <Text className="mt-1.5 text-[15px] font-semibold leading-[20px] text-ink">
                {brief.headline}
              </Text>
              <Text className="mt-1 text-[12px] leading-[17px] text-muted" numberOfLines={2}>
                {brief.workout.title} · {brief.foodFocus.title}
              </Text>
            </PressableScale>
          </FadeIn>
        )}

        {/* HERO — the dominant focal card, as in the reference */}
        <FadeIn delay={40} className="mt-4 px-5">
          {isLoading && !metrics ? (
            <Skeleton className="h-[248px] w-full rounded-card" />
          ) : (
            <ReadinessHero
              readiness={readiness}
              fallbackHint={baselineHint}
              onPress={() => router.push('/(tabs)/insights')}
            />
          )}
        </FadeIn>

        {/* PRIMARY STATS — HRV and resting HR carry 65% of readiness */}
        <FadeIn delay={120} className="mt-5 px-5">
          <SectionHeader
            title="Your signals"
            {...(series ? { actionLabel: `${series.length} days`, onAction: onRefresh } : {})}
          />

          {!metrics ? (
            <View className="gap-2.5">
              <View className="flex-row gap-2.5">
                <Skeleton className="h-[150px] flex-1 rounded-card" />
                <Skeleton className="h-[150px] flex-1 rounded-card" />
              </View>
              <Skeleton className="h-[84px] w-full rounded-2xl" />
            </View>
          ) : (
            <View className="gap-2.5">
              <View className="flex-row gap-2.5">
                <StatTile stats={metrics.hrv} />
                <StatTile stats={metrics.restingHeartRate} />
              </View>

              {/* Supporting signals as a chip row */}
              <View className="flex-row gap-2">
                <SignalChip stats={metrics.sleepDuration} />
                <SignalChip stats={metrics.sleepEfficiency} />
                <SignalChip stats={metrics.steps} />
                <SignalChip stats={metrics.activeEnergy} />
              </View>
            </View>
          )}
        </FadeIn>

        {/* FUEL — today's intake against today's target, and the way into the
            restaurant picker. Only rendered once targets exist; a calorie strip
            reading "0 / 0" is worse than no strip. */}
        {targets && (
          <FadeIn delay={160} className="mt-5 px-5">
            <SectionHeader
              title="Fuel"
              actionLabel="Log a meal"
              onAction={() => router.push('/meal/log')}
            />
            <Card padded={false}>
              <PressableScale
                scaleTo={0.99}
                accessibilityRole="button"
                accessibilityLabel={`${consumed.calories} of ${targets.calories} calories eaten today`}
                onPress={() => router.push('/(tabs)/food')}
                className="flex-row items-center gap-3 px-4 py-3.5"
              >
                <View className="h-10 w-10 items-center justify-center rounded-xl bg-brand-50">
                  <Flame size={17} color={palette.brand} strokeWidth={2.2} />
                </View>

                <View className="flex-1">
                  <Text className="text-[14px] font-semibold text-ink">
                    {remainingCalories != null && remainingCalories > 0
                      ? `${remainingCalories} kcal left today`
                      : `${consumed.calories} kcal logged`}
                  </Text>
                  <Text className="mt-0.5 text-[11px] text-muted">
                    {Math.round(consumed.proteinG)} of {targets.macros.proteinG} g protein
                    {targets.isCheatDay ? ' · cheat day' : ''}
                  </Text>
                </View>

                <View className="h-1.5 w-16 overflow-hidden rounded-full bg-ink/8">
                  <View
                    style={{
                      width: `${Math.min(100, (consumed.calories / Math.max(1, targets.calories)) * 100)}%`,
                      backgroundColor: palette.brand,
                    }}
                    className="h-full rounded-full"
                  />
                </View>
              </PressableScale>

              <PressableScale
                scaleTo={0.99}
                accessibilityRole="button"
                accessibilityLabel="Find somewhere to eat nearby"
                onPress={() => router.push('/dining')}
                className="flex-row items-center gap-3 border-t border-hairline px-4 py-3.5"
              >
                <View className="h-10 w-10 items-center justify-center rounded-xl bg-brand-50">
                  <MapPin size={17} color={palette.brand} strokeWidth={2.2} />
                </View>
                <Text className="flex-1 text-[14px] font-semibold text-ink">Eating out?</Text>
                <ChevronRight size={15} color={palette.faint} strokeWidth={2.4} />
              </PressableScale>
            </Card>
          </FadeIn>
        )}

        {/* HEADLINE FINDING — the product's differentiator */}
        <FadeIn delay={200} className="mt-6 px-5">
          <SectionHeader
            title="What we found"
            count={insights.length}
            {...(insights.length > 1
              ? { actionLabel: 'See all', onAction: () => router.push('/(tabs)/insights') }
              : {})}
          />

          {isLoading && !metrics ? (
            <Skeleton className="h-[168px] w-full rounded-card" />
          ) : headline ? (
            <HeadlineInsight insight={headline} onPress={() => router.push('/(tabs)/insights')} />
          ) : (
            <Card>
              <View className="flex-row items-start gap-3">
                <CheckCircle2 size={19} color={palette.optimal} strokeWidth={2.1} />
                <View className="flex-1">
                  <Text className="text-[15px] font-semibold text-ink">
                    {hasLabData ? 'Nothing to flag today' : 'No correlations yet'}
                  </Text>
                  <Text className="mt-1 text-[12px] leading-[17px] text-muted">
                    {hasLabData
                      ? 'Your telemetry is tracking its baseline and no lab value is out of band. We will surface something the moment that changes.'
                      : 'Add a blood report and we can start pairing your biomarkers against these daily trends.'}
                  </Text>
                </View>
              </View>
            </Card>
          )}
        </FadeIn>

        {/* ACTIONS — vertical list, nothing hidden behind a swipe */}
        {actions.length > 0 && (
          <FadeIn delay={280} className="mt-6 px-5">
            <SectionHeader title="Do this today" />
            <Card padded={false}>
              {actions.map(({ suggestion, source }, index) => (
                <ActionRow
                  key={suggestion.id}
                  suggestion={suggestion}
                  source={source}
                  isLast={index === actions.length - 1}
                  onPress={() => router.push('/(tabs)/insights')}
                />
              ))}
            </Card>
          </FadeIn>
        )}

        {/* LAB STATUS — keeps the correlation half of the product alive */}
        <FadeIn delay={340} className="mt-6 px-5">
          <SectionHeader
            title="Blood work"
            actionLabel={latestReport ? 'Open latest' : 'Add report'}
            onAction={() =>
              latestReport
                ? router.push({ pathname: '/lab/[id]', params: { id: latestReport.id } })
                : router.push('/upload')
            }
          />
          <LabStatusCard
            report={latestReport}
            flaggedCount={flaggedCount}
            onPress={() =>
              latestReport
                ? router.push({ pathname: '/lab/[id]', params: { id: latestReport.id } })
                : router.push('/upload')
            }
          />
        </FadeIn>

        <Text className="mt-7 px-10 text-center text-[10px] leading-[15px] text-faint">
          Statistical associations in your own data — not medical advice, and not a diagnosis.
        </Text>
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  /**
   * Two very soft radial-ish blooms. On a light canvas these read as ambient
   * light rather than the hard vignettes the dark theme needed.
   */
  glowTop: {
    position: 'absolute',
    top: -SCREEN_WIDTH * 0.55,
    left: -SCREEN_WIDTH * 0.25,
    width: SCREEN_WIDTH * 1.3,
    height: SCREEN_WIDTH * 1.3,
    borderRadius: SCREEN_WIDTH * 0.65,
    backgroundColor: '#CDEBB8',
    opacity: 0.35,
  },
  glowBottom: {
    position: 'absolute',
    bottom: -SCREEN_WIDTH * 0.5,
    right: -SCREEN_WIDTH * 0.35,
    width: SCREEN_WIDTH * 1.1,
    height: SCREEN_WIDTH * 1.1,
    borderRadius: SCREEN_WIDTH * 0.55,
    backgroundColor: '#DCF3C9',
    opacity: 0.3,
  },
});
