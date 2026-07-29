import { useState } from 'react';
import { ScrollView, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useRouter } from 'expo-router';
import { ChevronLeft } from 'lucide-react-native';

import { Button, IconButton } from '@/components/ui/Button';
import { ChoiceRow, Stepper } from '@/components/ui/Choice';
import { useProfileStore } from '@/store/profile.store';
import { useSettingsStore } from '@/store/settings.store';
import { ACTIVITY_META, type ActivityLevel } from '@/schemas/profile';
import { palette } from '@/theme/colors';

/**
 * Height, weight, age and activity level.
 *
 * These four are the entire input to the Mifflin–St Jeor equation, which is
 * what every calorie and macro target downstream is built on. Without them the
 * brief can still describe recovery and blood work, but it cannot prescribe a
 * number — so this screen exists purely to unlock that.
 */

const CURRENT_YEAR = new Date().getFullYear();
const ACTIVITY_LEVELS = Object.keys(ACTIVITY_META) as ActivityLevel[];

export default function BodyStep() {
  const router = useRouter();

  const storedHeight = useProfileStore((s) => s.heightCm);
  const storedWeight = useProfileStore((s) => s.weightKg);
  const storedActivity = useProfileStore((s) => s.activityLevel);
  const setBody = useProfileStore((s) => s.setBody);
  const setActivityLevel = useProfileStore((s) => s.setActivityLevel);

  const storedBirthYear = useSettingsStore((s) => s.birthYear);
  const setBirthYear = useSettingsStore((s) => s.setBirthYear);

  const [heightCm, setHeightCm] = useState<number | null>(storedHeight);
  const [weightKg, setWeightKg] = useState<number | null>(storedWeight);
  const [age, setAge] = useState<number | null>(
    storedBirthYear == null ? null : CURRENT_YEAR - storedBirthYear,
  );
  const [activity, setActivity] = useState<ActivityLevel>(storedActivity);

  const canContinue = heightCm != null && weightKg != null && age != null;

  const persistAndContinue = () => {
    setBody({ heightCm, weightKg });
    setActivityLevel(activity);
    setBirthYear(age == null ? null : CURRENT_YEAR - age);
    router.push('/onboarding/goals');
  };

  return (
    <SafeAreaView className="flex-1" style={{ backgroundColor: palette.bg }}>
      <View className="px-6 pt-2">
        <IconButton icon={ChevronLeft} label="Back" tone="onCanvas" onPress={() => router.back()} />
      </View>

      <ScrollView
        className="flex-1 px-8"
        contentContainerStyle={{ paddingBottom: 24 }}
        showsVerticalScrollIndicator={false}
      >
        <Text className="mt-6 text-[28px] font-bold leading-8 text-ink">
          A few numbers about you
        </Text>
        <Text className="mt-3 text-[13px] font-sans leading-5 text-muted">
          These four figures are what your calorie, protein and hydration targets are calculated
          from. They stay on this device.
        </Text>

        <View className="mt-7">
          <Stepper
            label="Height"
            unit="cm"
            value={heightCm}
            onChange={setHeightCm}
            step={1}
            min={120}
            max={220}
            fallback={170}
          />
          <Stepper
            label="Weight"
            unit="kg"
            value={weightKg}
            onChange={setWeightKg}
            step={0.5}
            min={35}
            max={200}
            fallback={70}
          />
          <Stepper
            label="Age"
            unit="years"
            value={age}
            onChange={setAge}
            step={1}
            min={16}
            max={100}
            fallback={32}
          />
        </View>

        <Text className="mb-3 mt-6 text-[11px] font-semibold uppercase tracking-wider text-muted">
          How active are you?
        </Text>
        <Text className="mb-4 text-[12px] font-sans leading-[17px] text-faint">
          Only used until your watch has a week of data — after that we use what you actually burn
          instead of this estimate.
        </Text>

        {ACTIVITY_LEVELS.map((level) => (
          <ChoiceRow
            key={level}
            label={ACTIVITY_META[level].label}
            hint={ACTIVITY_META[level].hint}
            selected={activity === level}
            onPress={() => setActivity(level)}
          />
        ))}
      </ScrollView>

      <View className="px-8 pb-6 pt-2">
        <Button
          label="Continue"
          size="lg"
          fullWidth
          disabled={!canContinue}
          onPress={persistAndContinue}
        />
        {!canContinue && (
          <Text className="mt-3 text-center text-[11px] font-sans text-faint">
            Set all three to continue — without them we cannot compute a target.
          </Text>
        )}
      </View>
    </SafeAreaView>
  );
}
