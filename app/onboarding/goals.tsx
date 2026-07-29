import { useState } from 'react';
import { ScrollView, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useRouter } from 'expo-router';
import { ChevronLeft } from 'lucide-react-native';

import { Button, IconButton } from '@/components/ui/Button';
import { ChipGroup, ChoiceChip, ChoiceRow, Stepper } from '@/components/ui/Choice';
import { useProfileStore } from '@/store/profile.store';
import {
  CONDITION_LABEL,
  ConditionSchema,
  HEALTH_GOAL_META,
  HealthGoalSchema,
  type Condition,
  type HealthGoal,
} from '@/schemas/profile';
import { palette } from '@/theme/colors';

/**
 * The goal, and anything being managed.
 *
 * The goal sets the calorie offset and the protein floor; conditions tighten
 * the carbohydrate share and the added-sugar ceiling. Both feed the restaurant
 * ranker as well, which is why they are asked once here rather than buried in
 * settings.
 */

const GOALS = HealthGoalSchema.options as HealthGoal[];
const CONDITIONS = ConditionSchema.options as Condition[];

export default function GoalsStep() {
  const router = useRouter();

  const storedGoal = useProfileStore((s) => s.goal);
  const storedConditions = useProfileStore((s) => s.conditions);
  const storedTarget = useProfileStore((s) => s.targetWeightKg);
  const weightKg = useProfileStore((s) => s.weightKg);

  const setGoal = useProfileStore((s) => s.setGoal);
  const toggleCondition = useProfileStore((s) => s.toggleCondition);
  const setBody = useProfileStore((s) => s.setBody);

  const [goal, setLocalGoal] = useState<HealthGoal>(storedGoal);
  const [targetWeight, setTargetWeight] = useState<number | null>(storedTarget);

  const wantsTargetWeight = goal === 'weight-loss' || goal === 'muscle-gain';

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
          What are you working towards?
        </Text>
        <Text className="mt-3 text-[13px] font-sans leading-5 text-muted">
          This sets your calorie offset and how much protein we hold you to. You can change it any
          time.
        </Text>

        <View className="mt-7">
          {GOALS.map((option) => (
            <ChoiceRow
              key={option}
              label={HEALTH_GOAL_META[option].label}
              hint={HEALTH_GOAL_META[option].hint}
              selected={goal === option}
              onPress={() => setLocalGoal(option)}
            />
          ))}
        </View>

        {wantsTargetWeight && (
          <View className="mt-4">
            <Text className="mb-3 text-[11px] font-semibold uppercase tracking-wider text-muted">
              Target weight
            </Text>
            <Stepper
              label="Goal weight"
              unit="kg"
              value={targetWeight}
              onChange={setTargetWeight}
              step={0.5}
              min={35}
              max={200}
              fallback={
                // Start a realistic distance from where they are rather than at
                // an arbitrary round number.
                weightKg == null ? 70 : Math.round((goal === 'weight-loss' ? weightKg - 5 : weightKg + 3) * 2) / 2
              }
            />
          </View>
        )}

        <Text className="mb-2 mt-6 text-[11px] font-semibold uppercase tracking-wider text-muted">
          Anything you are managing?
        </Text>
        <Text className="mb-4 text-[12px] font-sans leading-[17px] text-faint">
          Optional. If you pick something here we tighten the relevant targets — carbohydrate share
          for glucose, sugar and sodium ceilings — and factor it into food recommendations. We do
          not treat it as a diagnosis.
        </Text>

        <ChipGroup>
          {CONDITIONS.map((condition) => (
            <ChoiceChip
              key={condition}
              label={CONDITION_LABEL[condition]}
              selected={storedConditions.includes(condition)}
              onPress={() => toggleCondition(condition)}
            />
          ))}
        </ChipGroup>
      </ScrollView>

      <View className="px-8 pb-6 pt-2">
        <Button
          label="Continue"
          size="lg"
          fullWidth
          onPress={() => {
            setGoal(goal);
            if (wantsTargetWeight) setBody({ targetWeightKg: targetWeight });
            router.push('/onboarding/diet');
          }}
        />
      </View>
    </SafeAreaView>
  );
}
