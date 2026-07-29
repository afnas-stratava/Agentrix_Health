import 'react-native-gesture-handler';
import '../global.css';

import { useEffect } from 'react';
import { Platform } from 'react-native';
import { Stack } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { QueryClientProvider } from '@tanstack/react-query';
import { useFonts } from 'expo-font';
import * as SplashScreen from 'expo-splash-screen';
import * as SystemUI from 'expo-system-ui';

import { queryClient } from '@/lib/query-client';
import { palette } from '@/theme/colors';
import { appFonts } from '@/theme/fonts';
import { useHealthObserver, useHealthPermissionSync } from '@/features/health/queries';

// Held until the settings store rehydrates (see app/index.tsx), so the router
// never flashes onboarding at a user who has already completed it.
void SplashScreen.preventAutoHideAsync();
SplashScreen.setOptions({ duration: 400, fade: true });

function AppShell() {
  // Mounted once at the root: HealthKit authorization and background observers
  // are process-level concerns, not per-screen ones.
  useHealthPermissionSync();
  useHealthObserver();

  useEffect(() => {
    void SystemUI.setBackgroundColorAsync(palette.canvas);
  }, []);

  return (
    <Stack
      screenOptions={{
        headerShown: false,
        contentStyle: { backgroundColor: palette.canvas },
        animation: Platform.OS === 'ios' ? 'default' : 'fade_from_bottom',
      }}
    >
      <Stack.Screen name="index" />
      <Stack.Screen name="(tabs)" />
      <Stack.Screen name="onboarding" />

      {/* Modals are declared at the root so they present over the tab bar. */}
      <Stack.Screen
        name="upload"
        options={{
          presentation: 'modal',
          sheetGrabberVisible: true,
          sheetAllowedDetents: [0.6, 0.95],
          sheetCornerRadius: 28,
        }}
      />
      <Stack.Screen
        name="gmail-import"
        options={{ presentation: 'modal', gestureEnabled: false }}
      />
      <Stack.Screen name="metric/[metric]" options={{ presentation: 'modal' }} />
      <Stack.Screen name="lab/[id]" options={{ presentation: 'modal' }} />
    </Stack>
  );
}

export default function RootLayout() {
  // Inter Tight is loaded before anything paints so no screen renders a frame
  // in the system face and then reflows. The splash is already held (see the
  // `preventAutoHideAsync` call above) and `app/index.tsx` hides it once the
  // settings store rehydrates, which cannot happen until this returns a tree.
  // A load failure falls through to the system font rather than blocking boot.
  const [fontsLoaded, fontError] = useFonts(appFonts);

  if (!fontsLoaded && !fontError) return null;

  return (
    <GestureHandlerRootView style={{ flex: 1, backgroundColor: palette.canvas }}>
      <SafeAreaProvider>
        <QueryClientProvider client={queryClient}>
          <StatusBar style="dark" />
          <AppShell />
        </QueryClientProvider>
      </SafeAreaProvider>
    </GestureHandlerRootView>
  );
}
