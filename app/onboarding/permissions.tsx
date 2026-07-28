import { Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useRouter } from 'expo-router';
import { Activity, Bed, ChevronLeft, Flame, Footprints, HeartPulse, Lock } from 'lucide-react-native';

import { Button, IconButton } from '@/components/ui/Button';
import { useRequestHealthAccess } from '@/features/health/queries';
import { useHealthStore } from '@/store/health.store';
import { useSettingsStore } from '@/store/settings.store';
import { palette } from '@/theme/colors';

const SCOPES = [
  { icon: Activity, label: 'Heart rate variability', why: 'The primary recovery signal' },
  { icon: HeartPulse, label: 'Resting heart rate', why: 'Confirms what HRV is telling us' },
  { icon: Bed, label: 'Sleep analysis', why: 'Duration, stages and consistency' },
  { icon: Flame, label: 'Active energy', why: 'Training load against recovery' },
  { icon: Footprints, label: 'Steps', why: 'Baseline movement volume' },
];

export default function Permissions() {
  const router = useRouter();
  const requestAccess = useRequestHealthAccess();
  const markPrimerSeen = useHealthStore((s) => s.markPrimerSeen);
  const completeOnboarding = useSettingsStore((s) => s.completeOnboarding);

  const finish = () => {
    completeOnboarding();
    router.replace('/(tabs)/today');
  };

  /**
   * The system sheet can only be shown once per install. This screen exists to
   * explain *why* before that single shot is spent — a denial here is
   * effectively permanent short of a trip into iOS Settings.
   */
  const connect = async () => {
    markPrimerSeen();
    await requestAccess.mutateAsync();
    finish();
  };

  return (
    <SafeAreaView className="flex-1" style={{ backgroundColor: palette.bg }}>
      <View className="px-6 pt-2">
        <IconButton icon={ChevronLeft} label="Back" tone="onCanvas" onPress={() => router.back()} />
      </View>

      <View className="flex-1 px-8 pt-8">
        <Text className="text-[28px] font-bold leading-8 text-white">
          Connect Apple Health
        </Text>
        <Text className="mt-3 text-[13px] leading-5 text-white/60">
          We read five metrics, and we only read — Vitals requests no permission to write anything
          back to Health.
        </Text>

        <View className="mt-8">
          {SCOPES.map(({ icon: Icon, label, why }) => (
            <View key={label} className="mb-4 flex-row items-center gap-3.5">
              <View className="h-10 w-10 items-center justify-center rounded-2xl bg-white/12">
                <Icon size={18} color={palette.accent} strokeWidth={2} />
              </View>
              <View className="flex-1">
                <Text className="text-[14px] font-semibold text-white">{label}</Text>
                <Text className="text-[12px] text-white/45">{why}</Text>
              </View>
            </View>
          ))}
        </View>

        <View className="mt-4 flex-row items-start gap-3 rounded-2xl border border-white/10 bg-white/5 p-4">
          <Lock size={16} color={palette.optimal} strokeWidth={2.1} />
          <Text className="flex-1 text-[12px] leading-[17px] text-white/60">
            Health data is processed entirely on this device. It is never uploaded, and the
            correlation engine runs locally.
          </Text>
        </View>
      </View>

      <View className="px-8 pb-6">
        <Button
          label="Connect Apple Health"
          size="lg"
          fullWidth
          loading={requestAccess.isPending}
          onPress={() => void connect()}
        />
        <Button
          label="Skip for now"
          variant="ghost"
          size="sm"
          fullWidth
          onPress={finish}
          className="mt-2"
        />
      </View>
    </SafeAreaView>
  );
}
