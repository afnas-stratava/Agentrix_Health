import { useMemo } from 'react';
import { ScrollView, Text, View, useWindowDimensions } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Redirect, useLocalSearchParams, useRouter } from 'expo-router';
import { X } from 'lucide-react-native';

import { MetricKeySchema, METRIC_META, METRIC_POLARITY } from '@/schemas/health';
import { Sparkline } from '@/components/health/Sparkline';
import { Card } from '@/components/ui/Card';
import { Badge, DeltaBadge } from '@/components/ui/Badge';
import { IconButton } from '@/components/ui/Button';
import { useHealthSeries } from '@/features/health/queries';
import { buildEngineContext } from '@/features/correlation/context';
import { useSettingsStore, selectSex } from '@/store/settings.store';
import { compact, mean, median, stdDev } from '@/features/correlation/stats';
import { formatDay } from '@/lib/date';
import { palette } from '@/theme/colors';

/** Metrics we test the selected metric against, with a physiological lag. */
const COMPARISONS = [
  { metric: 'sleepDuration', lag: 0, label: 'Same-night sleep' },
  { metric: 'activeEnergy', lag: 1, label: "Previous day's load" },
  { metric: 'steps', lag: 1, label: "Previous day's steps" },
  { metric: 'sleepEfficiency', lag: 0, label: 'Same-night sleep quality' },
] as const;

export default function MetricDetail() {
  const router = useRouter();
  const { width } = useWindowDimensions();
  const params = useLocalSearchParams<{ metric: string }>();
  const sex = useSettingsStore(selectSex);
  const { data: series } = useHealthSeries();

  const parsed = MetricKeySchema.safeParse(params.metric);

  const context = useMemo(() => {
    if (!series || series.length === 0) return null;
    return buildEngineContext({
      series,
      biomarkers: [],
      labReportId: null,
      labCollectedAt: null,
      sex,
    });
  }, [series, sex]);

  // A malformed deep link should land somewhere sensible, not on a blank modal.
  if (!parsed.success) return <Redirect href="/(tabs)/today" />;

  const key = parsed.data;
  const meta = METRIC_META[key];
  const stats = context?.metrics[key];
  const values = stats?.values ?? [];
  const present = compact(values);

  const correlations = context
    ? COMPARISONS.filter((c) => c.metric !== key)
        .map((c) => ({ ...c, result: context.correlate(c.metric, key, c.lag) }))
        .filter((c) => c.result !== null && c.result.strength !== 'none')
    : [];

  const firstDay = context?.days[0] ?? null;
  const lastDay = context && context.days.length > 1 ? (context.days[context.days.length - 1] ?? null) : null;

  const format = (value: number | null | undefined): string => {
    if (value == null || !Number.isFinite(value)) return '—';
    if (key === 'steps') return Math.round(value).toLocaleString();
    return value.toFixed(meta.precision);
  };

  return (
    <SafeAreaView className="flex-1 bg-mockup-bg">
      <ScrollView contentContainerStyle={{ padding: 24, paddingBottom: 48 }}>
        <View className="flex-row items-start justify-between">
          <View className="flex-1 pr-4">
            <Text className="text-[26px] font-bold text-white">{meta.label}</Text>
            <Text className="mt-1 text-[13px] text-white/50">
              {values.length} days · {present.length} with data
            </Text>
          </View>
          <IconButton icon={X} label="Close" tone="onCanvas" onPress={() => router.back()} />
        </View>

        <Card className="mt-6">
          <View className="flex-row items-end justify-between">
            <View>
              <Text className="text-[11px] font-semibold uppercase tracking-wider text-mockup-card-text/50">
                Latest
              </Text>
              <View className="mt-1 flex-row items-baseline gap-1">
                <Text className="text-metric font-bold text-mockup-card-text">
                  {format(stats?.latest)}
                </Text>
                <Text className="text-sm text-mockup-card-text/45">{meta.unit}</Text>
              </View>
            </View>
            <DeltaBadge
              deltaPct={stats?.deltaPct ?? null}
              goodDirection={METRIC_POLARITY[key] === 'higher-is-better' ? 'up' : 'down'}
            />
          </View>

          <View className="mt-5">
            <Sparkline
              values={values}
              width={width - 88}
              height={110}
              color={palette.cardText}
              filled
              strokeWidth={2.5}
            />
          </View>

          {firstDay && lastDay && (
            <View className="mt-2 flex-row justify-between">
              <Text className="text-[10px] text-mockup-card-text/40">{formatDay(firstDay)}</Text>
              <Text className="text-[10px] text-mockup-card-text/40">{formatDay(lastDay)}</Text>
            </View>
          )}
        </Card>

        <View className="mt-3 flex-row gap-3">
          <Card className="flex-1">
            <Text className="text-[11px] font-semibold uppercase tracking-wider text-mockup-card-text/50">
              7-day mean
            </Text>
            <Text className="mt-1.5 text-metric-sm font-bold text-mockup-card-text">
              {format(stats?.recentMean)}
            </Text>
          </Card>
          <Card className="flex-1">
            <Text className="text-[11px] font-semibold uppercase tracking-wider text-mockup-card-text/50">
              28-day baseline
            </Text>
            <Text className="mt-1.5 text-metric-sm font-bold text-mockup-card-text">
              {format(stats?.baselineMean)}
            </Text>
          </Card>
        </View>

        <Card className="mt-3">
          <Text className="text-[11px] font-semibold uppercase tracking-wider text-mockup-card-text/50">
            Distribution
          </Text>
          <View className="mt-3 flex-row justify-between">
            {[
              { label: 'Min', value: present.length > 0 ? Math.min(...present) : null },
              { label: 'Median', value: present.length > 0 ? median(present) : null },
              { label: 'Mean', value: present.length > 0 ? mean(present) : null },
              { label: 'Max', value: present.length > 0 ? Math.max(...present) : null },
              { label: 'SD', value: present.length > 1 ? stdDev(present) : null },
            ].map((item) => (
              <View key={item.label} className="items-center">
                <Text className="text-[10px] uppercase tracking-wider text-mockup-card-text/40">
                  {item.label}
                </Text>
                <Text className="mt-1 text-[15px] font-bold text-mockup-card-text">
                  {format(item.value)}
                </Text>
              </View>
            ))}
          </View>
        </Card>

        <Text className="mb-3 mt-7 text-[11px] font-semibold uppercase tracking-wider text-white/50">
          What moves this metric
        </Text>

        {correlations.length === 0 ? (
          <Card>
            <Text className="text-[13px] leading-[19px] text-mockup-card-text/60">
              No statistically meaningful relationship found yet. Correlations need at least 10
              paired days and a p-value under 0.05 before we will show them — weak links on thin
              data are worse than none.
            </Text>
          </Card>
        ) : (
          correlations.map(({ metric, label, result }) => (
            <Card key={`${metric}-${label}`} className="mb-3">
              <View className="flex-row items-center justify-between">
                <Text className="flex-1 text-[14px] font-semibold text-mockup-card-text">
                  {label}
                </Text>
                <Badge
                  label={result!.strength}
                  color={
                    result!.strength === 'strong'
                      ? palette.optimal
                      : result!.strength === 'moderate'
                        ? palette.normal
                        : palette.borderline
                  }
                />
              </View>
              <Text className="mt-2 text-[12px] leading-[18px] text-mockup-card-text/60">
                {METRIC_META[metric].label}{' '}
                {result!.direction === 'positive' ? 'rises with' : 'moves against'} your{' '}
                {meta.short.toLowerCase()} across {result!.n} paired days
                {result!.lagDays > 0 ? ` at a ${result!.lagDays}-day lag` : ''}.
              </Text>
              <Text className="mt-1.5 font-mono text-[11px] text-mockup-card-text/40">
                r = {result!.r} · p = {result!.p < 0.001 ? '<0.001' : result!.p} · n = {result!.n}
              </Text>
            </Card>
          ))
        )}

        <Text className="mt-4 text-center text-[11px] leading-4 text-white/30">
          Correlation is not causation. These relationships describe your own history and can be
          confounded by anything not measured here.
        </Text>
      </ScrollView>
    </SafeAreaView>
  );
}
