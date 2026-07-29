import { type ReactNode } from 'react';
import { Pressable, type PressableProps, type StyleProp, type ViewStyle } from 'react-native';
import Animated, {
  Easing,
  useAnimatedStyle,
  useSharedValue,
  withTiming,
} from 'react-native-reanimated';

const AnimatedPressable = Animated.createAnimatedComponent(Pressable);

interface PressableScaleProps extends Omit<PressableProps, 'children' | 'style'> {
  children: ReactNode;
  /** How far to compress on press. Keep this subtle — 0.97 reads as physical. */
  scaleTo?: number;
  /**
   * Static style, merged *under* the animated transform. Needed for anything
   * NativeWind cannot express — shadows in particular, which have to travel
   * with the card so the lift compresses along with it on press.
   */
  style?: StyleProp<ViewStyle>;
  className?: string;
}

/**
 * Pressable with a spring-less scale response.
 *
 * `active:opacity-*` is the cheap way to signal a press, but on large cards it
 * reads as the card *dimming* rather than being pushed. A small scale keeps the
 * colour intact and feels physical. The animation lives on the UI thread, so it
 * stays responsive while the correlation engine recomputes on the JS thread.
 */
export function PressableScale({
  children,
  scaleTo = 0.97,
  style,
  className,
  onPressIn,
  onPressOut,
  ...rest
}: PressableScaleProps) {
  const scale = useSharedValue(1);

  const animatedStyle = useAnimatedStyle(() => ({ transform: [{ scale: scale.value }] }));

  const timing = { duration: 130, easing: Easing.out(Easing.quad) };

  return (
    <AnimatedPressable
      style={[style, animatedStyle]}
      className={className}
      onPressIn={(event) => {
        scale.value = withTiming(scaleTo, timing);
        onPressIn?.(event);
      }}
      onPressOut={(event) => {
        scale.value = withTiming(1, timing);
        onPressOut?.(event);
      }}
      {...rest}
    >
      {children}
    </AnimatedPressable>
  );
}
