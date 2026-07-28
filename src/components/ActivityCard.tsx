import React from 'react';
import { View, Text, Dimensions } from 'react-native';
import Animated, {
  useAnimatedStyle,
  interpolate,
  Extrapolation,
  type SharedValue,
} from 'react-native-reanimated';
import Svg, { Circle, G, Path, Rect } from 'react-native-svg';

const { width: SCREEN_WIDTH } = Dimensions.get('window');
export const CARD_WIDTH = Math.round(SCREEN_WIDTH * 0.52);
export const CARD_HEIGHT = Math.round(CARD_WIDTH * 1.6);
export const ITEM_SIZE = CARD_WIDTH + 16; // width + horizontal margins

// Custom SVGs for the mockup-perfect aesthetics.
// NOTE: react-native-svg only recognises the capitalised components (G, Rect,
// Circle…). Lowercase `<g>`/`<rect>` are silently dropped on native, which is
// why the pill icon previously rendered as an empty card.

const StethoscopeIcon = ({ color }: { color: string }) => (
  <Svg width={48} height={48} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth={2} strokeLinecap="round" strokeLinejoin="round">
    <Path d="M4.8 2.3A.3.3 0 1 0 5 2h-.2Z" />
    <Path d="M10 2v10a4 4 0 0 0 8 0V2" />
    <Path d="M12 2h4" />
    <Path d="M3 14a6 6 0 0 0 12 0v-2" />
    <Circle cx={18} cy={16} r={2} />
    <Path d="M18 18v2a2 2 0 0 1-2 2h-4" />
  </Svg>
);

const UtensilsIcon = ({ color }: { color: string }) => (
  <Svg width={48} height={48} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth={2} strokeLinecap="round" strokeLinejoin="round">
    <Path d="M3 2v7a2 2 0 0 0 2 2h4a2 2 0 0 0 2-2V2" />
    <Path d="M7 2v20" />
    <Path d="M21 15V2v0a5 5 0 0 0-5 5v6c0 1.1.9 2 2 2h3Z" />
    <Path d="M18 15v7" />
  </Svg>
);

// Three-capsule layout from the mockup.
const PillsIcon = ({ color }: { color: string }) => (
  <Svg width={64} height={64} viewBox="0 0 64 64" fill="none">
    <G transform="translate(18, 38) rotate(-45)">
      <Rect x={-6} y={-16} width={12} height={32} rx={6} fill={color} />
      <Rect x={-5} y={-15} width={10} height={14} rx={5} fill="#FFFFFF" opacity={0.35} />
    </G>
    <G transform="translate(42, 26) rotate(45)">
      <Rect x={-6} y={-16} width={12} height={32} rx={6} fill={color} />
      <Rect x={-5} y={-15} width={10} height={14} rx={5} fill="#FFFFFF" opacity={0.35} />
    </G>
    <G transform="translate(44, 46) rotate(-35)">
      <Rect x={-6} y={-16} width={12} height={32} rx={6} fill={color} />
      <Rect x={-5} y={-15} width={10} height={14} rx={5} fill="#FFFFFF" opacity={0.35} />
    </G>
  </Svg>
);

const PawIcon = ({ color }: { color: string }) => (
  <Svg width={48} height={48} viewBox="0 0 24 24" fill={color}>
    <Circle cx={12} cy={14} r={4} />
    <Circle cx={6} cy={9} r={2.2} />
    <Circle cx={10} cy={5} r={2.2} />
    <Circle cx={14} cy={5} r={2.2} />
    <Circle cx={18} cy={9} r={2.2} />
  </Svg>
);

const MoonIcon = ({ color }: { color: string }) => (
  <Svg width={48} height={48} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth={2} strokeLinecap="round" strokeLinejoin="round">
    <Path d="M12 3a6 6 0 0 0 9 9 9 9 0 1 1-9-9Z" />
    <Path d="M19 3v4M21 5h-4" strokeWidth={1.5} />
    <Path d="M15 8v2M16 9h-2" strokeWidth={1.5} />
  </Svg>
);

const DumbbellIcon = ({ color }: { color: string }) => (
  <Svg width={48} height={48} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth={2} strokeLinecap="round" strokeLinejoin="round">
    <Path d="M14.4 14.4 9.6 9.6" />
    <Path d="M18.657 21.485a2 2 0 1 1-2.829-2.828l-1.767 1.768a2 2 0 1 1-2.829-2.829l6.364-6.364a2 2 0 1 1 2.829 2.829l-1.768 1.767a2 2 0 1 1 2.828 2.829z" />
    <Path d="m21.5 21.5-1.4-1.4M3.9 3.9 2.5 2.5" />
    <Path d="M6.404 12.768a2 2 0 1 1-2.829-2.829l1.768-1.767a2 2 0 1 1-2.828-2.829l2.828-2.828a2 2 0 1 1 2.829 2.828l1.767-1.768a2 2 0 1 1 2.829 2.829z" />
  </Svg>
);

const HeartPulseIcon = ({ color }: { color: string }) => (
  <Svg width={48} height={48} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth={2} strokeLinecap="round" strokeLinejoin="round">
    <Path d="M19 14c1.49-1.46 3-3.21 3-5.5A5.5 5.5 0 0 0 16.5 3c-1.76 0-3 .5-4.5 2-1.5-1.5-2.74-2-4.5-2A5.5 5.5 0 0 0 2 8.5c0 2.3 1.5 4.05 3 5.5l7 7Z" />
    <Path d="M3.22 12H9.5l.5-1 2 4.5 2-7 1.5 3.5h5.27" />
  </Svg>
);

const LeafIcon = ({ color }: { color: string }) => (
  <Svg width={48} height={48} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth={2} strokeLinecap="round" strokeLinejoin="round">
    <Path d="M11 20A7 7 0 0 1 9.8 6.1C15.5 5 17 4.48 19 2c1 2 2 4.18 2 8 0 5.5-4.78 10-10 10Z" />
    <Path d="M2 21c0-3 1.85-5.36 5.08-6C9.5 14.52 12 13 13 12" />
  </Svg>
);

export type ActivityType =
  | 'doctor'
  | 'lunch'
  | 'pills'
  | 'paw'
  | 'sleep'
  | 'training'
  | 'recovery'
  | 'nutrition';

export interface Activity {
  id: string;
  /** Left slot: a clock time for schedule items, or a short tag like "EASY". */
  time: string;
  title: string;
  subtitle?: string;
  type: ActivityType;
  /** Optional tint for the icon; defaults to the card's ink colour. */
  accent?: string;
}

interface ActivityCardProps {
  activity: Activity;
  index: number;
  scrollX: SharedValue<number>;
  totalItems: number;
  onPress?: (activity: Activity) => void;
}

const INK = '#5A59AA';

export const ActivityCard: React.FC<ActivityCardProps> = ({ activity, index, scrollX }) => {
  const animatedStyle = useAnimatedStyle(() => {
    // Distance from the active scroll index, in card units.
    const position = (index * ITEM_SIZE - scrollX.value) / ITEM_SIZE;

    const scale = interpolate(position, [-2, -1, 0, 1, 2], [0.72, 0.86, 1.0, 0.86, 0.72], Extrapolation.CLAMP);

    // Fan effect: left cards tilt counter-clockwise, right cards clockwise.
    const rotateZ = interpolate(position, [-2, -1, 0, 1, 2], [-20, -10, 0, 10, 20], Extrapolation.CLAMP);

    // Side cards drop away to form a curved arch.
    const translateY = interpolate(position, [-2, -1, 0, 1, 2], [85, 30, 0, 30, 85], Extrapolation.CLAMP);

    // Squeeze side cards toward the centre so they overlap.
    const translateX = interpolate(position, [-2, -1, 0, 1, 2], [70, 35, 0, -35, -70], Extrapolation.CLAMP);

    const opacity = interpolate(position, [-2, -1, 0, 1, 2], [0.3, 0.65, 1.0, 0.65, 0.3], Extrapolation.CLAMP);

    return {
      transform: [{ translateX }, { translateY }, { scale }, { rotate: `${rotateZ}deg` }],
      opacity,
      // Keep the centre card above its neighbours.
      zIndex: Math.round(10 - Math.abs(position) * 3),
    };
  });

  const activeOverlayStyle = useAnimatedStyle(() => {
    const position = (index * ITEM_SIZE - scrollX.value) / ITEM_SIZE;
    return {
      opacity: interpolate(position, [-0.5, 0, 0.5], [0, 1, 0], Extrapolation.CLAMP),
    };
  });

  const renderIcon = (color: string) => {
    switch (activity.type) {
      case 'doctor':
        return <StethoscopeIcon color={color} />;
      case 'lunch':
        return <UtensilsIcon color={color} />;
      case 'pills':
        return <PillsIcon color={color} />;
      case 'paw':
        return <PawIcon color={color} />;
      case 'sleep':
        return <MoonIcon color={color} />;
      case 'training':
        return <DumbbellIcon color={color} />;
      case 'recovery':
        return <HeartPulseIcon color={color} />;
      case 'nutrition':
        return <LeafIcon color={color} />;
    }
  };

  const iconColor = activity.accent ?? INK;

  return (
    <Animated.View
      style={[animatedStyle, { width: CARD_WIDTH, height: CARD_HEIGHT, marginHorizontal: 8 }]}
      className="shadow-2xl shadow-indigo-900/60"
    >
      {/* Resting card */}
      <View
        className="h-full w-full flex-col items-center justify-between rounded-[24px] border border-white/20 px-4 py-8"
        style={{ backgroundColor: '#F4F5FC' }}
      >
        <Text className="text-2xl font-bold tracking-tight" style={{ color: INK, opacity: 0.6 }}>
          {activity.time}
        </Text>

        <View className="my-auto items-center justify-center">{renderIcon(iconColor)}</View>

        <View className="items-center">
          <Text
            className="text-center text-lg font-bold leading-6"
            style={{ color: INK }}
            numberOfLines={2}
          >
            {activity.title}
          </Text>
          {activity.subtitle && (
            <Text
              className="mt-1 text-center text-sm font-semibold"
              style={{ color: INK, opacity: 0.65 }}
              numberOfLines={2}
            >
              {activity.subtitle}
            </Text>
          )}
        </View>
      </View>

      {/* Centre card: crossfades to pure white with a deeper shadow */}
      <Animated.View
        style={[activeOverlayStyle, { position: 'absolute', top: 0, left: 0, right: 0, bottom: 0 }]}
        pointerEvents="none"
      >
        <View
          className="h-full w-full flex-col items-center justify-between rounded-[24px] bg-white px-4 py-8"
          style={{
            shadowColor: '#3C3B87',
            shadowOffset: { width: 0, height: 12 },
            shadowOpacity: 0.25,
            shadowRadius: 20,
            elevation: 10,
          }}
        >
          <Text className="text-2xl font-black tracking-tight" style={{ color: INK }}>
            {activity.time}
          </Text>

          <View className="my-auto items-center justify-center">{renderIcon(iconColor)}</View>

          <View className="items-center">
            <Text
              className="text-center text-lg font-extrabold leading-6"
              style={{ color: INK }}
              numberOfLines={2}
            >
              {activity.title}
            </Text>
            {activity.subtitle && (
              <Text
                className="mt-1 text-center text-sm font-semibold"
                style={{ color: INK, opacity: 0.7 }}
                numberOfLines={2}
              >
                {activity.subtitle}
              </Text>
            )}
          </View>
        </View>
      </Animated.View>
    </Animated.View>
  );
};
