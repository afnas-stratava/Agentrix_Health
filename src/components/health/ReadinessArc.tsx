import { useMemo } from 'react';
import { Text, View } from 'react-native';
import Svg, { G, Line } from 'react-native-svg';
import { palette } from '@/theme/colors';

/**
 * Segmented radial gauge — a ring of discrete ticks rather than a solid arc.
 *
 * Discrete ticks are the right call for a score built from a handful of
 * weighted z-scores: a smooth sweep implies a precision the underlying data
 * does not have, whereas 40 steps reads honestly as "roughly here". It also
 * matches the reference design's dashed-arc treatment.
 */
interface ReadinessArcProps {
  /** 0–100. `null` renders the empty track with a placeholder. */
  score: number | null;
  size?: number;
  /** Total sweep in degrees, centred on 12 o'clock. */
  sweep?: number;
  tickCount?: number;
  /** Colour of filled ticks. */
  color?: string;
  trackColor?: string;
  label?: string;
  /** Rendered under the number, e.g. "READINESS". */
  caption?: string;
}

export function ReadinessArc({
  score,
  size = 168,
  sweep = 260,
  tickCount = 40,
  color = palette.accent,
  trackColor = 'rgba(255,255,255,0.18)',
  label,
  caption,
}: ReadinessArcProps) {
  const center = size / 2;
  const outerRadius = center - 4;
  const tickLength = size * 0.11;
  const innerRadius = outerRadius - tickLength;

  const ticks = useMemo(() => {
    const filledCount = score == null ? 0 : Math.round((score / 100) * tickCount);
    const startAngle = -sweep / 2;
    const step = sweep / (tickCount - 1);

    return Array.from({ length: tickCount }, (_, index) => ({
      // 0° points at 12 o'clock; SVG rotation is applied about the centre.
      angle: startAngle + index * step,
      filled: index < filledCount,
      // Ticks thicken slightly toward the filled end for a sense of direction.
      width: 2.5 + (index / tickCount) * 1.6,
    }));
  }, [score, sweep, tickCount]);

  return (
    <View style={{ width: size, height: size }} className="items-center justify-center">
      <Svg width={size} height={size} style={{ position: 'absolute' }}>
        {ticks.map((tick, index) => (
          <G key={index} transform={`rotate(${tick.angle} ${center} ${center})`}>
            <Line
              x1={center}
              y1={center - outerRadius}
              x2={center}
              y2={center - innerRadius}
              stroke={tick.filled ? color : trackColor}
              strokeWidth={tick.width}
              strokeLinecap="round"
            />
          </G>
        ))}
      </Svg>

      <View className="items-center">
        {score == null ? (
          <>
            <Text className="text-[34px] font-bold text-white/40">—</Text>
            {caption && (
              <Text className="mt-0.5 max-w-[92px] text-center text-[9px] font-medium uppercase tracking-wider text-white/45">
                {caption}
              </Text>
            )}
          </>
        ) : (
          <>
            <View className="flex-row items-start">
              <Text
                className="font-bold text-white"
                style={{ fontSize: size * 0.27, lineHeight: size * 0.3 }}
              >
                {score}
              </Text>
              <Text
                className="font-semibold text-white/55"
                style={{ fontSize: size * 0.11, lineHeight: size * 0.16 }}
              >
                %
              </Text>
            </View>
            {(label ?? caption) && (
              <Text className="text-[10px] font-semibold uppercase tracking-wider text-white/60">
                {label ?? caption}
              </Text>
            )}
          </>
        )}
      </View>
    </View>
  );
}
