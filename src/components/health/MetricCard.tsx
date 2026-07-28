import { memo } from 'react';
import { Pressable, Text, View } from 'react-native';
import { Link } from 'expo-router';
import type { MetricKey } from '@/schemas/health';
import { METRIC_META, METRIC_POLARITY } from '@/schemas/health';
import type { MetricStats } from '@/features/correlation/context';
import { DeltaBadge } from '@/components/ui/Badge';
import { Sparkline } from './Sparkline';
import { palette } from '@/theme/colors';

interface MetricCardProps {
  stats: MetricStats;
  /** Compact tiles sit two-up in a grid; wide ones span the row. */
  variant?: 'tile' | 'wide';
}

function formatValue(key: MetricKey, value: number | null): string {
  if (value == null) return '—';
  const { precision } = METRIC_META[key];
  if (key === 'steps') return Math.round(value).toLocaleString();
  return value.toFixed(precision);
}

function MetricCardBase({ stats, variant = 'tile' }: MetricCardProps) {
  const meta = METRIC_META[stats.key];
  const goodDirection = METRIC_POLARITY[stats.key] === 'higher-is-better' ? 'up' : 'down';

  // Colour the trend, not the value: a "good" absolute number that is falling
  // is more actionable than a mediocre one holding steady.
  const trendColor =
    stats.deltaPct == null || Math.abs(stats.deltaPct) < 2
      ? palette.mutedIcon
      : (stats.deltaPct > 0) === (goodDirection === 'up')
        ? palette.optimal
        : palette.abnormal;

  return (
    <Link href={{ pathname: '/metric/[metric]', params: { metric: stats.key } }} asChild>
      <Pressable
        accessibilityRole="button"
        accessibilityLabel={`${meta.label}, ${formatValue(stats.key, stats.latest)} ${meta.unit}`}
        className={`rounded-card bg-mockup-card-bg p-4 active:opacity-80 ${
          variant === 'tile' ? 'flex-1' : 'w-full'
        }`}
      >
        <View className="flex-row items-center justify-between">
          <Text className="text-[11px] font-semibold uppercase tracking-wider text-mockup-card-text/55">
            {meta.short}
          </Text>
          <DeltaBadge deltaPct={stats.deltaPct} goodDirection={goodDirection} />
        </View>

        <View className="mt-3 flex-row items-baseline gap-1">
          <Text className="text-metric-sm font-bold text-mockup-card-text">
            {formatValue(stats.key, stats.latest)}
          </Text>
          {meta.unit.length > 0 && (
            <Text className="text-xs font-medium text-mockup-card-text/50">{meta.unit}</Text>
          )}
        </View>

        <View className="mt-3">
          <Sparkline
            values={stats.values.slice(-30)}
            width={variant === 'tile' ? 130 : 300}
            height={34}
            color={trendColor}
            filled
          />
        </View>

        <Text className="mt-2 text-[11px] text-mockup-card-text/45">
          {stats.baselineMean != null
            ? `28-day baseline ${formatValue(stats.key, stats.baselineMean)}${meta.unit ? ` ${meta.unit}` : ''}`
            : 'Building your baseline'}
        </Text>
      </Pressable>
    </Link>
  );
}

/**
 * Memoised on the stats object identity. `buildEngineContext` produces a fresh
 * object only when the underlying series changes, so this holds across the
 * frequent re-renders caused by unrelated store writes.
 */
export const MetricCard = memo(MetricCardBase);
