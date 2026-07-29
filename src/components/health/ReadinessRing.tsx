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
  moderate: palette.normal,
  primed: palette.optimal,
};

interface ReadinessRingProps {
  readiness: Readiness | null;
  size?: number;
  strokeWidth?: number;
  /** Determines the track and label colours; the arc is always band-coloured. */
  tone?: 'onCanvas' | 'onCard';
}

/**
 * The arc animates through `animatedProps` on the SVG circle, keeping the
 * interpolation on the UI thread — a `setState`-driven version drops frames
 * whenever the engine recomputes at the same moment.
 */
export function ReadinessRing({
  readiness,
  size = 132,
  strokeWidth = 11,
  tone = 'onCanvas',
}: ReadinessRingProps) {
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
  const onCard = tone === 'onCard';
  const trackColor = onCard ? 'rgba(90,89,170,0.12)' : 'rgba(255,255,255,0.14)';

  return (
    <View style={{ width: size, height: size }} className="items-center justify-center">
      <Svg width={size} height={size} style={{ position: 'absolute' }}>
        <Defs>
          <LinearGradient id={`readiness-${tone}`} x1="0" y1="0" x2="1" y2="1">
            <Stop offset="0" stopColor={color} stopOpacity={1} />
            <Stop offset="1" stopColor={color} stopOpacity={0.55} />
          </LinearGradient>
        </Defs>

        <Circle
          cx={size / 2}
          cy={size / 2}
          r={radius}
          stroke={trackColor}
          strokeWidth={strokeWidth}
          fill="none"
        />

        <AnimatedCircle
          cx={size / 2}
          cy={size / 2}
          r={radius}
          stroke={`url(#readiness-${tone})`}
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
            <Text
              className={`font-bold ${onCard ? 'text-ink' : 'text-white'}`}
              style={{ fontSize: size * 0.3, lineHeight: size * 0.34 }}
            >
              {readiness.score}
            </Text>
            <Text
              className={`text-[10px] font-semibold uppercase tracking-wider ${
                onCard ? 'text-ink/40' : 'text-faint'
              }`}
            >
              / 100
            </Text>
          </>
        ) : (
          <>
            <Text
              className={`text-2xl font-bold ${onCard ? 'text-ink/30' : 'text-faint'}`}
            >
              —
            </Text>
            <Text
              className={`mt-1 max-w-[80px] text-center text-[10px] font-sans leading-3 ${
                onCard ? 'text-ink/40' : 'text-faint'
              }`}
            >
              7 days needed
            </Text>
          </>
        )}
      </View>
    </View>
  );
}
