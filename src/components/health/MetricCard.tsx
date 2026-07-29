import { memo } from 'react';
import { Pressable, Text, View } from 'react-native';
import { Link } from 'expo-router';
import type { MetricKey } from '@/schemas/health';
import { METRIC_META, METRIC_POLARITY } from '@/schemas/health';
import type { MetricStats } from '@/features/correlation/context';
import { DeltaBadge } from '@/components/ui/Badge';
import { Sparkline } from './Sparkline';
import { palette } from '@/theme/colors';

function formatValue(key: MetricKey, value: number | null): string {
  if (value == null) return '—';
  if (key === 'steps') return Math.round(value).toLocaleString();
  return value.toFixed(METRIC_META[key].precision);
}

/**
 * Colour follows the *trend*, not the absolute value: a good number that is
 * falling is more actionable than a mediocre one holding steady.
 */
function trendColor(stats: MetricStats): string {
  if (stats.deltaPct == null || Math.abs(stats.deltaPct) < 2) return palette.mutedIcon;
  const rising = stats.deltaPct > 0;
  const higherIsBetter = METRIC_POLARITY[stats.key] === 'higher-is-better';
  return rising === higherIsBetter ? palette.optimal : palette.abnormal;
}

interface MetricCardProps {
  stats: MetricStats;
  /**
   * `primary` is for the two metrics that actually drive readiness (HRV and
   * resting HR) — full sparkline and baseline context. `compact` is a
   * four-up strip for the supporting signals, where a value and a direction
   * is all the space earns.
   */
  variant?: 'primary' | 'compact';
}

function MetricCardBase({ stats, variant = 'primary' }: MetricCardProps) {
  const meta = METRIC_META[stats.key];
  const color = trendColor(stats);
  const value = formatValue(stats.key, stats.latest);

  const a11yLabel = `${meta.label}, ${value} ${meta.unit}${
    stats.deltaPct != null ? `, ${Math.round(stats.deltaPct)} percent versus baseline` : ''
  }`;

  if (variant === 'compact') {
    return (
      <Link href={{ pathname: '/metric/[metric]', params: { metric: stats.key } }} asChild>
        <Pressable
          accessibilityRole="button"
          accessibilityLabel={a11yLabel}
          className="flex-1 rounded-2xl bg-surface px-2.5 py-3 active:opacity-80"
        >
          <Text
            className="text-[10px] font-semibold uppercase tracking-wider text-ink/45"
            numberOfLines={1}
          >
            {meta.short}
          </Text>

          <Text className="mt-1.5 text-[17px] font-bold leading-5 text-ink" numberOfLines={1}>
            {value}
          </Text>

          <View className="mt-1 flex-row items-center gap-1">
            <View style={{ backgroundColor: color }} className="h-1.5 w-1.5 rounded-full" />
            <Text className="text-[10px] font-sans text-ink/45" numberOfLines={1}>
              {stats.deltaPct == null
                ? meta.unit || '—'
                : `${stats.deltaPct > 0 ? '+' : ''}${Math.round(stats.deltaPct)}%`}
            </Text>
          </View>
        </Pressable>
      </Link>
    );
  }

  return (
    <Link href={{ pathname: '/metric/[metric]', params: { metric: stats.key } }} asChild>
      <Pressable
        accessibilityRole="button"
        accessibilityLabel={a11yLabel}
        className="flex-1 rounded-card bg-surface p-4 active:opacity-80"
      >
        <View className="flex-row items-start justify-between">
          <Text className="text-[11px] font-semibold uppercase tracking-wider text-ink/50">
            {meta.short}
          </Text>
          <DeltaBadge
            deltaPct={stats.deltaPct}
            goodDirection={METRIC_POLARITY[stats.key] === 'higher-is-better' ? 'up' : 'down'}
          />
        </View>

        <View className="mt-2.5 flex-row items-baseline gap-1">
          <Text className="text-metric-sm font-bold text-ink">{value}</Text>
          {meta.unit.length > 0 && (
            <Text className="text-xs font-medium text-ink/45">{meta.unit}</Text>
          )}
        </View>

        <View className="mt-2.5">
          <Sparkline values={stats.values.slice(-30)} width={132} height={32} color={color} filled />
        </View>

        <Text className="mt-2 text-[10px] font-sans text-ink/40" numberOfLines={1}>
          {stats.baselineMean != null
            ? `baseline ${formatValue(stats.key, stats.baselineMean)}`
            : 'building baseline'}
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
