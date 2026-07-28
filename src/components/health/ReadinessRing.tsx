import { useEffect } from 'react';
import { Text, View } from 'react-native';
import Svg, { Circle, Defs, LinearGradient, Stop } from 'react-native-svg';
import Animated, {
  useAnimatedProps,
  useSharedValue,
  withTiming,
  Easing,
} from 'react-native-reanimated';
import type { Readiness } from '@/schemas/insights';
import { palette } from '@/theme/colors';

const AnimatedCircle = Animated.createAnimatedComponent(Circle);

const BAND_COLOR: Record<Readiness['band'], string> = {
  compromised: palette.critical,
  low: palette.abnormal,
  moderate: palette.accent,
  primed: palette.optimal,
};

interface ReadinessRingProps {
  readiness: Readiness | null;
  size?: number;
  strokeWidth?: number;
}

/**
 * The arc is animated through `animatedProps` on the SVG circle, which keeps
 * the interpolation on the UI thread — a `setState`-driven version drops
 * frames whenever the engine recomputes at the same moment.
 */
export function ReadinessRing({ readiness, size = 132, strokeWidth = 11 }: ReadinessRingProps) {
  const radius = (size - strokeWidth) / 2;
  const circumference = 2 * Math.PI * radius;
  const progress = useSharedValue(0);

  const score = readiness?.score ?? 0;

  useEffect(() => {
    progress.value = withTiming(score / 100, {
      duration: 900,
      easing: Easing.out(Easing.cubic),
    });
  }, [score, progress]);

  const animatedProps = useAnimatedProps(() => ({
    strokeDashoffset: circumference * (1 - progress.value),
  }));

  const color = readiness ? BAND_COLOR[readiness.band] : palette.mutedIcon;

  return (
    <View style={{ width: size, height: size }} className="items-center justify-center">
      <Svg width={size} height={size} style={{ position: 'absolute' }}>
        <Defs>
          <LinearGradient id="readiness" x1="0" y1="0" x2="1" y2="1">
            <Stop offset="0" stopColor={color} stopOpacity={1} />
            <Stop offset="1" stopColor={color} stopOpacity={0.55} />
          </LinearGradient>
        </Defs>

        <Circle
          cx={size / 2}
          cy={size / 2}
          r={radius}
          stroke="rgba(255,255,255,0.14)"
          strokeWidth={strokeWidth}
          fill="none"
        />

        <AnimatedCircle
          cx={size / 2}
          cy={size / 2}
          r={radius}
          stroke="url(#readiness)"
          strokeWidth={strokeWidth}
          strokeLinecap="round"
          fill="none"
          strokeDasharray={circumference}
          animatedProps={animatedProps}
          // Start the arc at 12 o'clock rather than 3.
          transform={`rotate(-90 ${size / 2} ${size / 2})`}
        />
      </Svg>

      <View className="items-center">
        {readiness ? (
          <>
            <Text className="text-metric font-bold text-white">{readiness.score}</Text>
            <Text
              style={{ color }}
              className="mt-0.5 text-[11px] font-semibold uppercase tracking-wider"
            >
              {readiness.band}
            </Text>
          </>
        ) : (
          <>
            <Text className="text-2xl font-bold text-white/40">—</Text>
            <Text className="mt-1 max-w-[86px] text-center text-[10px] leading-3 text-white/45">
              Needs 7 days of data
            </Text>
          </>
        )}
      </View>
    </View>
  );
}
