import { Dimensions, StyleSheet, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useRouter } from 'expo-router';
import { Activity, FileText, Sparkles } from 'lucide-react-native';

import { Button } from '@/components/ui/Button';
import { palette } from '@/theme/colors';

const { width: SCREEN_WIDTH } = Dimensions.get('window');

const POINTS = [
  {
    icon: Activity,
    title: 'Your daily telemetry',
    body: 'HRV, resting heart rate, sleep stages, steps and active energy, read straight from Apple Health.',
  },
  {
    icon: FileText,
    title: 'Your blood work',
    body: 'Upload a lab PDF or photograph the printout. We extract every biomarker and flag it against evidence-based optimal bands.',
  },
  {
    icon: Sparkles,
    title: 'The intersection',
    body: 'A ferritin of 21 is "normal". A ferritin of 21 alongside three weeks of falling HRV is a reason to act.',
  },
];

export default function Welcome() {
  const router = useRouter();

  return (
    <SafeAreaView className="flex-1" style={{ backgroundColor: palette.bg }}>
      <View style={styles.glow} pointerEvents="none" />

      <View className="flex-1 justify-center px-8">
        <Text className="text-[40px] font-bold leading-[46px] text-ink">
          Your labs.{'\n'}Your wearable.{'\n'}
          <Text className="font-sans" style={{ color: palette.accent }}>One picture.</Text>
        </Text>

        <View className="mt-10">
          {POINTS.map(({ icon: Icon, title, body }) => (
            <View key={title} className="mb-6 flex-row gap-4">
              <View className="mt-0.5 h-10 w-10 items-center justify-center rounded-2xl bg-ink/5">
                <Icon size={19} color={palette.brand} strokeWidth={2} />
              </View>
              <View className="flex-1">
                <Text className="text-[15px] font-semibold text-ink">{title}</Text>
                <Text className="mt-1 text-[13px] font-sans leading-[19px] text-muted">{body}</Text>
              </View>
            </View>
          ))}
        </View>
      </View>

      <View className="px-8 pb-6">
        <Button label="Get started" size="lg" fullWidth onPress={() => router.push('/onboarding/profile')} />
        <Text className="mt-4 text-center text-[11px] font-sans leading-4 text-faint/80">
          Vitals is not a medical device and does not diagnose. Always discuss results with a
          qualified clinician.
        </Text>
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  glow: {
    position: 'absolute',
    top: -SCREEN_WIDTH * 0.5,
    right: -SCREEN_WIDTH * 0.3,
    width: SCREEN_WIDTH * 1.3,
    height: SCREEN_WIDTH * 1.3,
    borderRadius: SCREEN_WIDTH * 0.65,
    backgroundColor: '#CDEBB8',
    opacity: 0.35,
  },
});
