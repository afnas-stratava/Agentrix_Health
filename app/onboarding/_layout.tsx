import { Stack } from 'expo-router';
import { palette } from '@/theme/colors';

export default function OnboardingLayout() {
  return (
    <Stack
      screenOptions={{
        headerShown: false,
        contentStyle: { backgroundColor: palette.bg },
        // Forward-only flow; the back gesture is handled by explicit controls
        // so a half-configured profile cannot be left behind.
        gestureEnabled: false,
      }}
    >
      <Stack.Screen name="index" />
      <Stack.Screen name="profile" />
      <Stack.Screen name="permissions" />
    </Stack>
  );
}
