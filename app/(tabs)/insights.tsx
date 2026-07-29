import { useCallback } from 'react';
import { RefreshControl, ScrollView, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useRouter } from 'expo-router';
import { useQueryClient } from '@tanstack/react-query';
import { Lightbulb, RotateCcw } from 'lucide-react-native';

import { InsightCard } from '@/components/insights/InsightCard';
import { InsightCardSkeleton } from '@/components/ui/Skeleton';
import { EmptyState } from '@/components/ui/EmptyState';
import { Button } from '@/components/ui/Button';
import { useInsights } from '@/features/insights/use-insights';
import { useHealthSeries } from '@/features/health/queries';
import { useSettingsStore } from '@/store/settings.store';
import { queryKeys } from '@/lib/query-client';
import { palette } from '@/theme/colors';

export default function InsightsScreen() {
  const router = useRouter();
  const queryClient = useQueryClient();

  const { insights, dismissed, isLoading, hasLabData, hasTelemetry } = useInsights();
  const { isFetching, refetch } = useHealthSeries();
  const dismissInsight = useSettingsStore((s) => s.dismissInsight);
  const clearDismissed = useSettingsStore((s) => s.clearDismissed);

  const onRefresh = useCallback(() => {
    void refetch();
    void queryClient.invalidateQueries({ queryKey: queryKeys.insights.all });
  }, [refetch, queryClient]);

  const urgentCount = insights.filter((i) => i.severity === 'urgent').length;

  return (
    <SafeAreaView className="flex-1 bg-canvas" edges={['top']}>
      <ScrollView
        showsVerticalScrollIndicator={false}
        contentContainerStyle={{ paddingBottom: 140 }}
        refreshControl={
          <RefreshControl refreshing={isFetching} onRefresh={onRefresh} tintColor={palette.accent} />
        }
      >
        <View className="px-6 pt-2">
          <View className="flex-row items-start justify-between gap-3">
            <View className="flex-1">
              <Text className="text-3xl font-bold text-ink">Insights</Text>
              <Text className="mt-1.5 text-[13px] font-sans leading-5 text-muted">
                {hasLabData
                  ? 'Where your blood work and your daily telemetry agree. Nothing here is a diagnosis.'
                  : 'Patterns found in your telemetry. Add a blood report to unlock the correlations.'}
              </Text>
            </View>

            <Button
              label="Refresh"
              icon={RotateCcw}
              variant="secondary"
              size="sm"
              onPress={onRefresh}
            />
          </View>

          {urgentCount > 0 && (
            <View className="mt-4 flex-row items-center gap-2.5 rounded-2xl border border-critical/30 bg-critical/12 px-4 py-3">
              <View className="h-2 w-2 rounded-full bg-critical" />
              <Text className="flex-1 text-[12px] font-sans leading-4 text-ink/80">
                {urgentCount === 1
                  ? 'One finding is worth taking to a clinician.'
                  : `${urgentCount} findings are worth taking to a clinician.`}
              </Text>
            </View>
          )}
        </View>

        <View className="mt-5 px-6">
          {isLoading ? (
            <>
              <InsightCardSkeleton />
              <View className="h-3" />
              <InsightCardSkeleton />
            </>
          ) : insights.length === 0 ? (
            <EmptyState
              icon={Lightbulb}
              title={hasTelemetry ? 'Nothing to flag right now' : 'No data to analyse yet'}
              body={
                hasTelemetry
                  ? 'Your telemetry is tracking your baseline and no lab value is out of band. We will surface something the moment that changes.'
                  : 'Connect Apple Health and add a blood report — insights appear once there is something to correlate.'
              }
              actionLabel={hasLabData ? undefined : 'Add a blood report'}
              onAction={hasLabData ? undefined : () => router.push('/upload')}
            />
          ) : (
            insights.map((insight) => (
              <InsightCard key={insight.id} insight={insight} onDismiss={dismissInsight} />
            ))
          )}
        </View>

        {dismissed.length > 0 && (
          <View className="mt-4 px-6">
            <Button
              label={`Restore ${dismissed.length} dismissed`}
              variant="secondary"
              size="sm"
              icon={RotateCcw}
              fullWidth
              onPress={clearDismissed}
            />
          </View>
        )}

        {insights.length > 0 && (
          <Text className="mt-6 px-8 text-center text-[11px] font-sans leading-4 text-faint/80">
            These are statistical associations in your own data, not medical advice. Discuss any
            change to medication or treatment with a clinician.
          </Text>
        )}
      </ScrollView>
    </SafeAreaView>
  );
}
