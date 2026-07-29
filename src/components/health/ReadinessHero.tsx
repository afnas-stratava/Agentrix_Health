import { memo, useMemo } from 'react';
import { Text, View } from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import { ArrowRight, TrendingDown, TrendingUp } from 'lucide-react-native';
import type { Readiness } from '@/schemas/insights';
import { METRIC_META } from '@/schemas/health';
import { READINESS_COPY } from '@/features/correlation/readiness';
import { PressableScale } from '@/components/ui/PressableScale';
import { ReadinessArc } from './ReadinessArc';
import { HERO_GRADIENT, palette } from '@/theme/colors';

/**
 * Band colours for the hero surface only — these sit on deep green, so they are
 * lighter and warmer than the on-canvas status ramp in `theme/colors.ts`.
 */
const BAND_COLOR: Record<Readiness['band'], string> = {
  compromised: '#FF8A8A',
  low: '#FFB27A',
  moderate: palette.accent,
  primed: palette.accent,
};

const NEGATIVE = '#FFB27A';

/**
 * Compact diverging bar for one readiness driver.
 *
 * Right of centre means the metric is helping today, left means it is dragging.
 * A bare score is not actionable; "HRV is costing you 14 points" points
 * straight at tonight's decision.
 */
function DriverBar({
  label,
  contribution,
  scale,
}: {
  label: string;
  contribution: number;
  scale: number;
}) {
  const magnitude = Math.min(1, Math.abs(contribution) / scale);
  const isPositive = contribution >= 0;
  const color = isPositive ? palette.accent : NEGATIVE;

  return (
    <View className="flex-row items-center gap-2.5 py-1">
      <Text className="w-[52px] text-[10px] font-medium text-white/60" numberOfLines={1}>
        {label}
      </Text>

      <View className="h-1 flex-1 flex-row overflow-hidden rounded-pill bg-white/15">
        <View className="h-full w-1/2 items-end">
          {!isPositive && (
            <View
              style={{ width: `${magnitude * 100}%`, backgroundColor: color }}
              className="h-full rounded-l-pill"
            />
          )}
        </View>
        <View className="h-full w-1/2">
          {isPositive && (
            <View
              style={{ width: `${magnitude * 100}%`, backgroundColor: color }}
              className="h-full rounded-r-pill"
            />
          )}
        </View>
      </View>

      <Text style={{ color }} className="w-[26px] text-right text-[10px] font-bold">
        {isPositive ? '+' : '−'}
        {Math.abs(Math.round(contribution))}
      </Text>
    </View>
  );
}

interface ReadinessHeroProps {
  readiness: Readiness | null;
  /** Copy shown in place of drivers when there is no baseline yet. */
  fallbackHint: string;
  onPress?: () => void;
}

function ReadinessHeroBase({ readiness, fallbackHint, onPress }: ReadinessHeroProps) {
  const copy = readiness ? READINESS_COPY[readiness.band] : null;

  // Normalise bar lengths against the largest driver so the chart uses its full
  // width, with a floor so a genuinely flat day does not render maxed-out bars
  // off tiny differences.
  const scale = useMemo(() => {
    if (!readiness || readiness.drivers.length === 0) return 10;
    return Math.max(10, ...readiness.drivers.map((d) => Math.abs(d.contribution)));
  }, [readiness]);

  const topDriver = readiness?.drivers[0] ?? null;
  const isDragging = topDriver != null && topDriver.contribution < 0;

  return (
    <View
      className="overflow-hidden rounded-card"
      style={{
        shadowColor: palette.brandDeep,
        shadowOpacity: 0.18,
        shadowRadius: 18,
        shadowOffset: { width: 0, height: 10 },
        elevation: 8,
      }}
    >
      <LinearGradient
        colors={[...HERO_GRADIENT]}
        start={{ x: 0, y: 0 }}
        end={{ x: 1, y: 1 }}
        style={{ padding: 20 }}
      >
        <View className="flex-row items-start justify-between">
          <View className="flex-1 pr-2">
            {/* Band chip — the qualitative read, ahead of the number */}
            <View
              style={{ backgroundColor: 'rgba(255,255,255,0.16)' }}
              className="self-start rounded-pill px-2.5 py-1"
            >
              <Text
                style={{ color: readiness ? BAND_COLOR[readiness.band] : 'rgba(255,255,255,0.75)' }}
                className="text-[9px] font-bold uppercase tracking-wider"
              >
                {copy?.label ?? 'No baseline'}
              </Text>
            </View>

            <Text className="mt-2.5 text-[25px] font-bold leading-[29px] text-white">
              Readiness
            </Text>

            <View className="mt-1.5 flex-row items-center gap-1.5">
              {readiness ? (
                <>
                  {isDragging ? (
                    <TrendingDown size={12} color={NEGATIVE} strokeWidth={2.5} />
                  ) : (
                    <TrendingUp size={12} color={palette.accent} strokeWidth={2.5} />
                  )}
                  <Text className="text-[11px] text-white/65">
                    vs. {readiness.baselineDays}-day baseline
                  </Text>
                </>
              ) : (
                <Text className="text-[11px] text-white/65">Building your baseline</Text>
              )}
            </View>
          </View>

          <ReadinessArc
            score={readiness?.score ?? null}
            size={130}
            color={readiness ? BAND_COLOR[readiness.band] : palette.accent}
            {...(readiness ? {} : { caption: 'needs 7 days' })}
          />
        </View>

        {/* Drivers, or the reason there are none */}
        {readiness && readiness.drivers.length > 0 ? (
          <View className="mt-3 border-t border-white/15 pt-2.5">
            {readiness.drivers.slice(0, 4).map((driver) => (
              <DriverBar
                key={driver.metric}
                label={METRIC_META[driver.metric].short}
                contribution={driver.contribution}
                scale={scale}
              />
            ))}
          </View>
        ) : (
          <Text className="mt-3 border-t border-white/15 pt-3 text-[11px] leading-4 text-white/65">
            {fallbackHint}
          </Text>
        )}

        {/* CTA, mirroring the reference's "Continue" pill */}
        {readiness && onPress && (
          <PressableScale
            scaleTo={0.94}
            accessibilityRole="button"
            accessibilityLabel={`Readiness ${copy?.label}. ${copy?.blurb ?? ''}`}
            onPress={onPress}
            className="mt-3.5 flex-row items-center gap-1.5 self-start rounded-pill bg-accent px-4 py-2.5"
          >
            <Text className="text-[12px] font-bold text-ink">What to do today</Text>
            <ArrowRight size={13} color={palette.ink} strokeWidth={2.6} />
          </PressableScale>
        )}
      </LinearGradient>
    </View>
  );
}

export const ReadinessHero = memo(ReadinessHeroBase);
