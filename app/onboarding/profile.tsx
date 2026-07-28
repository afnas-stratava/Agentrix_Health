import { useState } from 'react';
import { Pressable, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useRouter } from 'expo-router';
import { ChevronLeft } from 'lucide-react-native';

import { Button, IconButton } from '@/components/ui/Button';
import { useSettingsStore } from '@/store/settings.store';
import type { BiologicalSex } from '@/features/labs/reference-ranges';
import { palette } from '@/theme/colors';

const OPTIONS: Array<{ value: BiologicalSex; label: string; hint: string }> = [
  {
    value: 'female',
    label: 'Female',
    hint: 'Applies female intervals for ferritin, haemoglobin, HDL, testosterone and ALT',
  },
  {
    value: 'male',
    label: 'Male',
    hint: 'Applies male intervals for ferritin, haemoglobin, HDL, testosterone and ALT',
  },
  {
    value: 'unspecified',
    label: 'Prefer not to say',
    hint: 'Uses the wider combined interval — some values may be flagged less precisely',
  },
];

export default function Profile() {
  const router = useRouter();
  const storedSex = useSettingsStore((s) => s.sex);
  const setSex = useSettingsStore((s) => s.setSex);
  const [selected, setSelected] = useState<BiologicalSex>(storedSex);

  return (
    <SafeAreaView className="flex-1" style={{ backgroundColor: palette.bg }}>
      <View className="px-6 pt-2">
        <IconButton icon={ChevronLeft} label="Back" tone="onCanvas" onPress={() => router.back()} />
      </View>

      <View className="flex-1 px-8 pt-8">
        <Text className="text-[28px] font-bold leading-8 text-white">
          Which reference ranges should we use?
        </Text>
        <Text className="mt-3 text-[13px] leading-5 text-white/60">
          Lab reference intervals differ by biological sex. This is only used to flag your results
          correctly — it is stored on your device and never sent anywhere.
        </Text>

        <View className="mt-8">
          {OPTIONS.map((option) => {
            const isSelected = selected === option.value;
            return (
              <Pressable
                key={option.value}
                accessibilityRole="radio"
                accessibilityState={{ selected: isSelected }}
                onPress={() => setSelected(option.value)}
                className={`mb-3 rounded-card border p-4 active:opacity-80 ${
                  isSelected ? 'border-mockup-accent bg-white/12' : 'border-white/15 bg-white/5'
                }`}
              >
                <View className="flex-row items-center gap-3">
                  <View
                    className={`h-5 w-5 items-center justify-center rounded-full border-2 ${
                      isSelected ? 'border-mockup-accent' : 'border-white/30'
                    }`}
                  >
                    {isSelected && <View className="h-2.5 w-2.5 rounded-full bg-mockup-accent" />}
                  </View>
                  <Text className="text-[15px] font-semibold text-white">{option.label}</Text>
                </View>
                <Text className="ml-8 mt-1 text-[12px] leading-4 text-white/50">{option.hint}</Text>
              </Pressable>
            );
          })}
        </View>
      </View>

      <View className="px-8 pb-6">
        <Button
          label="Continue"
          size="lg"
          fullWidth
          onPress={() => {
            setSex(selected);
            router.push('/onboarding/permissions');
          }}
        />
      </View>
    </SafeAreaView>
  );
}
