import { Pressable, StyleSheet, Text, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useRouter } from 'expo-router';
import * as Haptics from 'expo-haptics';
import type { BottomTabBarProps } from '@react-navigation/bottom-tabs';
import Svg, { Path } from 'react-native-svg';
import { Activity, FlaskConical, Home, Settings } from 'lucide-react-native';

const ACTIVE = '#FCE285';
const INACTIVE = '#A2A1E6';
const BAR = '#403F89';
const FAB_INK = '#2D2B60';

const ICONS = {
  today: Home,
  insights: Activity,
  labs: FlaskConical,
  settings: Settings,
} as const;

type TabName = keyof typeof ICONS;

function isTabName(name: string): name is TabName {
  return name in ICONS;
}

/**
 * Floating pill tab bar with a centre action button.
 *
 * Built as a custom `tabBar` rather than styling the default one because the
 * FAB has to break out above the bar's bounds — something the stock tab bar
 * clips. Routing still goes through React Navigation, so deep links, state
 * restoration and the Android back button all behave normally.
 */
export function PillTabBar({ state, descriptors, navigation }: BottomTabBarProps) {
  const insets = useSafeAreaInsets();
  const router = useRouter();

  const routes = state.routes.filter((route) => isTabName(route.name));
  // Split the tabs either side of the centre action.
  const midpoint = Math.ceil(routes.length / 2);
  const groups = [routes.slice(0, midpoint), routes.slice(midpoint)];

  const renderTab = (route: (typeof routes)[number]) => {
    if (!isTabName(route.name)) return null;

    const routeIndex = state.routes.findIndex((r) => r.key === route.key);
    const isFocused = state.index === routeIndex;
    const Icon = ICONS[route.name];
    const label = descriptors[route.key]?.options.title ?? route.name;

    const onPress = () => {
      void Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);

      const event = navigation.emit({
        type: 'tabPress',
        target: route.key,
        canPreventDefault: true,
      });

      if (!isFocused && !event.defaultPrevented) {
        navigation.navigate(route.name);
      }
    };

    return (
      <Pressable
        key={route.key}
        accessibilityRole="button"
        accessibilityState={isFocused ? { selected: true } : {}}
        accessibilityLabel={label}
        onPress={onPress}
        onLongPress={() => navigation.emit({ type: 'tabLongPress', target: route.key })}
        className="flex-1 items-center justify-center active:opacity-70"
      >
        <View
          className={`h-12 w-12 items-center justify-center rounded-2xl ${
            isFocused ? 'bg-mockup-accent/20' : ''
          }`}
        >
          <Icon
            size={22}
            color={isFocused ? ACTIVE : INACTIVE}
            strokeWidth={isFocused ? 2.6 : 2.2}
          />
        </View>
      </Pressable>
    );
  };

  return (
    <View
      className="absolute bottom-0 w-full px-6"
      style={{ paddingBottom: Math.max(insets.bottom, 16) }}
      pointerEvents="box-none"
    >
      <View
        className="h-20 w-full flex-row items-center justify-between rounded-[30px] px-2"
        style={styles.bar}
      >
        {groups[0]?.map(renderTab)}

        <View style={styles.fabWrapper}>
          <Pressable
            accessibilityRole="button"
            accessibilityLabel="Add a lab report"
            onPress={() => {
              void Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
              router.push('/upload');
            }}
            style={styles.fab}
          >
            <Svg width={24} height={24} viewBox="0 0 24 24" fill="none" stroke={FAB_INK} strokeWidth={3} strokeLinecap="round">
              <Path d="M12 5v14M5 12h14" />
            </Svg>
          </Pressable>
        </View>

        {groups[1]?.map(renderTab)}
      </View>

      {/* Screen-reader-only label; the icons alone carry no text. */}
      <Text accessibilityElementsHidden importantForAccessibility="no-hide-descendants" className="hidden">
        Main navigation
      </Text>
    </View>
  );
}

const styles = StyleSheet.create({
  bar: {
    backgroundColor: BAR,
    shadowColor: '#252456',
    shadowOffset: { width: 0, height: 8 },
    shadowOpacity: 0.3,
    shadowRadius: 16,
    elevation: 8,
  },
  fabWrapper: {
    width: 68,
    height: 68,
    justifyContent: 'center',
    alignItems: 'center',
    top: -24,
  },
  fab: {
    width: 60,
    height: 60,
    borderRadius: 30,
    backgroundColor: ACTIVE,
    justifyContent: 'center',
    alignItems: 'center',
    borderWidth: 5,
    borderColor: BAR,
  },
});
