import { memo, useState } from 'react';
import { Pressable, Text, View, type LayoutChangeEvent } from 'react-native';
import { Link } from 'expo-router';
import { Activity, Flame, Footprints, HeartPulse, Moon, Percent } from 'lucide-react-native';
import type { MetricKey } from '@/schemas/health';
import { METRIC_META, METRIC_POLARITY } from '@/schemas/health';
import type { MetricStats } from '@/features/correlation/context';
import { Sparkline } from './Sparkline';
import { palette } from '@/theme/colors';

const METRIC_ICON: Record<MetricKey, typeof Activity> = {
  hrv: Activity,
  restingHeartRate: HeartPulse,
  sleepDuration: Moon,
  sleepEfficiency: Percent,
  steps: Footprints,
  activeEnergy: Flame,
};

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
  if (stats.deltaPct == null || Math.abs(stats.deltaPct) < 2) return palette.faint;
  const rising = stats.deltaPct > 0;
  const higherIsBetter = METRIC_POLARITY[stats.key] === 'higher-is-better';
  return rising === higherIsBetter ? palette.optimal : palette.abnormal;
}

/**
 * Large stat card for the two metrics that actually drive readiness.
 * Mirrors the reference's "245 kcal" tiles: icon, delta chip, big number,
 * label, then a sparkline for shape.
 */
function StatTileBase({ stats }: { stats: MetricStats }) {
  const meta = METRIC_META[stats.key];
  const Icon = METRIC_ICON[stats.key];
  const color = trendColor(stats);
  const value = formatValue(stats.key, stats.latest);
  const delta = stats.deltaPct == null ? null : Math.round(stats.deltaPct);

  // The tile is `flex-1`, so its width depends on the device. A fixed sparkline
  // width left a dead margin on larger phones; measure the content box instead.
  const [chartWidth, setChartWidth] = useState(0);
  const onChartLayout = (event: LayoutChangeEvent) => {
    const next = Math.round(event.nativeEvent.layout.width);
    if (next > 0 && next !== chartWidth) setChartWidth(next);
  };

  return (
    <Link href={{ pathname: '/metric/[metric]', params: { metric: stats.key } }} asChild>
      <Pressable
        accessibilityRole="button"
        accessibilityLabel={`${meta.label}, ${value} ${meta.unit}${
          delta != null ? `, ${delta} percent versus baseline` : ''
        }`}
        className="flex-1 rounded-card border border-hairline bg-surface p-4 active:opacity-80"
      >
        <View className="flex-row items-center justify-between">
          <View className="h-8 w-8 items-center justify-center rounded-xl bg-brand-50">
            <Icon size={15} color={palette.brand} strokeWidth={2.3} />
          </View>

          {delta != null && delta !== 0 && (
            <View
              style={{ backgroundColor: `${color}1A` }}
              className="flex-row items-center rounded-pill px-2 py-0.5"
            >
              <Text style={{ color }} className="text-[10px] font-bold">
                {delta > 0 ? '+' : ''}
                {delta}%
              </Text>
            </View>
          )}
        </View>

        <View className="mt-3 flex-row items-baseline gap-1">
          <Text className="text-metric-sm font-bold text-ink">{value}</Text>
          {meta.unit.length > 0 && (
            <Text className="text-[11px] font-medium text-faint">{meta.unit}</Text>
          )}
        </View>

        <Text className="mt-0.5 text-[11px] font-medium text-muted" numberOfLines={1}>
          {meta.label}
        </Text>

        {/* Height is reserved up front so measuring the width on first layout
            does not reflow the tile. */}
        <View className="mt-2.5" style={{ height: 30 }} onLayout={onChartLayout}>
          {chartWidth > 0 && (
            <Sparkline
              values={stats.values.slice(-30)}
              width={chartWidth}
              height={30}
              color={color}
              filled
            />
          )}
        </View>
      </Pressable>
    </Link>
  );
}

export const StatTile = memo(StatTileBase);

/**
 * Small chip for the supporting signals — the equivalent of the reference's
 * "Workout Category" row. A value and a direction is all the space earns.
 */
function SignalChipBase({ stats }: { stats: MetricStats }) {
  const meta = METRIC_META[stats.key];
  const Icon = METRIC_ICON[stats.key];
  const color = trendColor(stats);

  return (
    <Link href={{ pathname: '/metric/[metric]', params: { metric: stats.key } }} asChild>
      <Pressable
        accessibilityRole="button"
        accessibilityLabel={`${meta.label}, ${formatValue(stats.key, stats.latest)} ${meta.unit}`}
        className="flex-1 items-center rounded-2xl border border-hairline bg-surface px-1.5 py-3 active:opacity-80"
      >
        <View className="h-9 w-9 items-center justify-center rounded-full bg-brand-50">
          <Icon size={16} color={palette.brand} strokeWidth={2.2} />
        </View>

        <Text className="mt-2 text-[13px] font-bold text-ink" numberOfLines={1}>
          {formatValue(stats.key, stats.latest)}
        </Text>

        <View className="mt-0.5 flex-row items-center gap-1">
          <View style={{ backgroundColor: color }} className="h-1 w-1 rounded-full" />
          <Text className="text-[9px] font-medium text-faint" numberOfLines={1}>
            {meta.short}
          </Text>
        </View>
      </Pressable>
    </Link>
  );
}

export const SignalChip = memo(SignalChipBase);
