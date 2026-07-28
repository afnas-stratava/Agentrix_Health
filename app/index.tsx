import { useEffect, useState } from 'react';
import { View } from 'react-native';
import { Redirect } from 'expo-router';
import * as SplashScreen from 'expo-splash-screen';
import { useSettingsStore, selectHasOnboarded } from '@/store/settings.store';
import { palette } from '@/theme/colors';

/**
 * Entry gate.
 *
 * Zustand's `persist` rehydrates asynchronously, so `hasOnboarded` reads as
 * `false` on the first frame regardless of what is stored. Redirecting on that
 * frame would bounce returning users back into onboarding, so the splash is
 * held until hydration resolves.
 *
 * The dashboard lives at `/(tabs)/today` rather than `/(tabs)/index`
 * specifically so this route can own `/`.
 */
export default function Index() {
  const hasOnboarded = useSettingsStore(selectHasOnboarded);
  const [hydrated, setHydrated] = useState(() => useSettingsStore.persist.hasHydrated());

  useEffect(() => {
    if (hydrated) return undefined;
    return useSettingsStore.persist.onFinishHydration(() => setHydrated(true));
  }, [hydrated]);

  useEffect(() => {
    if (hydrated) void SplashScreen.hideAsync();
  }, [hydrated]);

  if (!hydrated) {
    return <View style={{ flex: 1, backgroundColor: palette.bg }} />;
  }

  return <Redirect href={hasOnboarded ? '/(tabs)/today' : '/onboarding'} />;
}
