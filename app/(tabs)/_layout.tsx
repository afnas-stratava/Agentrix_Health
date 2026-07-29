import { Tabs } from 'expo-router';
import { PillTabBar } from '@/components/navigation/PillTabBar';
import { palette } from '@/theme/colors';

/**
 * The tab bar itself is a custom component (`PillTabBar`) so the centre action
 * button can float above the bar, matching the design. Navigation semantics
 * still come from React Navigation.
 */
export default function TabsLayout() {
  return (
    <Tabs
      tabBar={(props) => <PillTabBar {...props} />}
      screenOptions={{
        headerShown: false,
        sceneStyle: { backgroundColor: palette.bg },
      }}
    >
      <Tabs.Screen name="today" options={{ title: 'Today' }} />
      <Tabs.Screen name="food" options={{ title: 'Food' }} />
      <Tabs.Screen name="insights" options={{ title: 'Insights' }} />
      <Tabs.Screen name="labs" options={{ title: 'Labs' }} />
      {/*
        Settings stays a tab route so `/(tabs)/settings` resolves everywhere,
        but it is deliberately absent from `PillTabBar`'s icon map: with five
        icons the bar gets cramped, and settings already has a permanent home
        in the Today header.
      */}
      <Tabs.Screen name="settings" options={{ title: 'Settings' }} />
    </Tabs>
  );
}
