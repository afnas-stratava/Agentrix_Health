import { useEffect, type ReactNode } from 'react';
import Animated, {
  Easing,
  useAnimatedStyle,
  useSharedValue,
  withDelay,
  withTiming,
  type SharedValue,
} from 'react-native-reanimated';

interface FadeInProps {
  children: ReactNode;
  /** Stagger offset in ms. Index * ~60ms reads as one cascade, not a queue. */
  delay?: number;
  /** Starting vertical offset in px. */
  offset?: number;
  duration?: number;
  className?: string;
}

/**
 * Entrance transition for dashboard sections.
 *
 * Implemented with explicit shared values rather than Reanimated's `entering=`
 * layout animations: layout animations re-fire on every remount and interact
 * badly with lists and conditional branches, whereas this runs exactly once per
 * mount and is a plain opacity/transform on the UI thread.
 */
export function FadeIn({
  children,
  delay = 0,
  offset = 14,
  duration = 420,
  className,
}: FadeInProps) {
  const progress: SharedValue<number> = useSharedValue(0);

  useEffect(() => {
    progress.value = withDelay(
      delay,
      withTiming(1, { duration, easing: Easing.out(Easing.cubic) }),
    );
  }, [delay, duration, progress]);

  const style = useAnimatedStyle(() => ({
    opacity: progress.value,
    transform: [{ translateY: (1 - progress.value) * offset }],
  }));

  return (
    <Animated.View style={style} className={className}>
      {children}
    </Animated.View>
  );
}
