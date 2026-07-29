import { useEffect } from 'react';
import { View } from 'react-native';
import Animated, {
  Easing,
  useAnimatedStyle,
  useSharedValue,
  withRepeat,
  withTiming,
  cancelAnimation,
} from 'react-native-reanimated';
import { cn } from '@/lib/cn';

/**
 * Shimmer runs entirely on the UI thread via Reanimated worklets, so loading
 * states stay at 60fps even while the correlation engine is chewing through a
 * 90-day window on the JS thread.
 */
export function Skeleton({ className }: { className?: string }) {
  const opacity = useSharedValue(0.35);

  useEffect(() => {
    opacity.value = withRepeat(
      withTiming(0.85, { duration: 900, easing: Easing.inOut(Easing.quad) }),
      -1,
      true,
    );
    return () => cancelAnimation(opacity);
  }, [opacity]);

  const style = useAnimatedStyle(() => ({ opacity: opacity.value }));

  return (
    <Animated.View style={style} className={cn('rounded-xl bg-ink/8', className)} />
  );
}

export function MetricCardSkeleton() {
  return (
    <View className="flex-1 rounded-card bg-ink/5 p-4">
      <Skeleton className="h-3 w-16" />
      <Skeleton className="mt-4 h-8 w-20" />
      <Skeleton className="mt-3 h-3 w-12" />
    </View>
  );
}

export function InsightCardSkeleton() {
  return (
    <View className="rounded-card bg-ink/5 p-5">
      <Skeleton className="h-4 w-24" />
      <Skeleton className="mt-4 h-5 w-full" />
      <Skeleton className="mt-2 h-5 w-3/4" />
      <Skeleton className="mt-5 h-3 w-full" />
      <Skeleton className="mt-2 h-3 w-5/6" />
    </View>
  );
}
