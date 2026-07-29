import { Pressable, StyleSheet, Text, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useRouter } from 'expo-router';
import * as Haptics from 'expo-haptics';
import type { BottomTabBarProps } from '@react-navigation/bottom-tabs';
import { Activity, FlaskConical, Home, Plus, UtensilsCrossed } from 'lucide-react-native';
import { palette } from '@/theme/colors';

/**
 * Only the four routes named here get a slot in the bar. `settings` is a tab
 * route but is intentionally omitted — five icons plus the centre action reads
 * as cramped, and settings is always one tap away from the Today header.
 */
const ICONS = {
  today: Home,
  food: UtensilsCrossed,
  insights: Activity,
  labs: FlaskConical,
} as const;

type TabName = keyof typeof ICONS;

function isTabName(name: string): name is TabName {
  return name in ICONS;
}

/**
 * Floating tab bar with a centre action button.
 *
 * Built as a custom `tabBar` rather than styling the default one because the
 * action button breaks out above the bar's bounds — something the stock tab bar
 * clips. Routing still goes through React Navigation, so deep links, state
 * restoration and the Android back button all behave normally.
 *
 * The focused tab reveals its label; the others stay icon-only. That keeps the
 * bar quiet while still naming where you are.
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
        className="flex-1 items-center justify-center rounded-2xl py-2 active:opacity-70"
      >
        <View
          className={isFocused ? 'items-center justify-center rounded-full bg-brand-50 p-2' : 'items-center justify-center rounded-full p-2'}
        >
          <Icon
            size={21}
            color={isFocused ? palette.brand : palette.faint}
            strokeWidth={isFocused ? 2.6 : 2.1}
          />
        </View>
        {isFocused && (
          <Text className="mt-1 text-[9px] font-bold uppercase tracking-wide text-brand-600">
            {label}
          </Text>
        )}
      </Pressable>
    );
  };

  return (
    <View
      className="absolute bottom-0 w-full px-5"
      style={{ paddingBottom: Math.max(insets.bottom, 14), paddingTop: 8, overflow: 'visible' }}
      pointerEvents="box-none"
    >
      <View
        className="h-[72px] w-full flex-row items-center justify-between rounded-[28px] bg-surface px-2"
        style={styles.bar}
      >
        {groups[0]?.map(renderTab)}

        <View style={styles.fabWrapper}>
          <Pressable
            accessibilityRole="button"
            accessibilityLabel="Log a meal"
            accessibilityHint="Opens meal logging. Lab reports are uploaded from the Labs tab."
            onPress={() => {
              void Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
              // Meal logging is the several-times-a-day action; uploading a lab
              // report is a monthly one and lives on the Labs tab.
              router.push('/meal/log');
            }}
            style={styles.fab}
          >
            <Plus size={24} color={palette.ink} strokeWidth={3} />
          </Pressable>
        </View>

        {groups[1]?.map(renderTab)}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  bar: {
    // Soft lift rather than an outline — the light theme reads as floating
    // cards, so a hard border here would fight everything else on screen.
    shadowColor: palette.brandDeep,
    shadowOffset: { width: 0, height: 6 },
    shadowOpacity: 0.1,
    shadowRadius: 16,
    elevation: 10,
  },
  fabWrapper: {
    width: 62,
    height: 62,
    justifyContent: 'center',
    alignItems: 'center',
    top: -20,
  },
  fab: {
    width: 56,
    height: 56,
    borderRadius: 28,
    backgroundColor: palette.accent,
    justifyContent: 'center',
    alignItems: 'center',
    // A surface-coloured ring punches the button visually out of the bar.
    borderWidth: 5,
    borderColor: palette.surface,
  },
});
