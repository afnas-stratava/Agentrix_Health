import { View } from 'react-native';
import { Stack, useRouter } from 'expo-router';
import { Compass } from 'lucide-react-native';
import { EmptyState } from '@/components/ui/EmptyState';

export default function NotFound() {
  const router = useRouter();

  return (
    <>
      <Stack.Screen options={{ title: 'Not found' }} />
      <View className="flex-1 items-center justify-center bg-mockup-bg">
        <EmptyState
          icon={Compass}
          title="This screen doesn't exist"
          body="The link you followed points somewhere the app doesn't have a route for."
          actionLabel="Back to dashboard"
          onAction={() => router.replace('/(tabs)/today')}
        />
      </View>
    </>
  );
}
