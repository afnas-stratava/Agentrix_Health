import { useMemo } from 'react';
import { Alert, ScrollView, Switch, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useRouter } from 'expo-router';
import { CalendarPlus, ChevronLeft, Droplets } from 'lucide-react-native';

import { Card } from '@/components/ui/Card';
import { Button, IconButton } from '@/components/ui/Button';
import { SectionHeader } from '@/components/ui/SectionHeader';
import { ChipGroup, ChoiceChip, ChoiceRow, Stepper } from '@/components/ui/Choice';

import {
  ACTIVITY_META,
  ALLERGEN_LABEL,
  AllergenSchema,
  CONDITION_LABEL,
  ConditionSchema,
  CUISINE_LABEL,
  CuisineSchema,
  DIET_PATTERN_META,
  DietPatternSchema,
  HEALTH_GOAL_META,
  HealthGoalSchema,
  RESTRICTION_LABEL,
  RestrictionSchema,
  bodyMassIndex,
  type ActivityLevel,
} from '@/schemas/profile';
import { useProfileStore } from '@/store/profile.store';
import { useSettingsStore } from '@/store/settings.store';
import { useProfile } from '@/features/profile/use-profile';
import { computeCyclePhase, withPeriodStart } from '@/features/cycle/phase';
import { basalMetabolicRate } from '@/features/nutrition/targets';
import { formatRelativeDay, toIsoDay } from '@/lib/date';
import { palette } from '@/theme/colors';

/**
 * The profile editor.
 *
 * Every field onboarding collects is editable here, in the same order and with
 * the same components — a user who changes their goal should recognise the
 * screen. The cycle section lives here rather than in Settings because it is
 * profile data, and because logging a period start is something people do from
 * wherever they happen to be, not somewhere buried behind a preferences list.
 */

const GOALS = HealthGoalSchema.options;
const CONDITIONS = ConditionSchema.options;
const DIET_PATTERNS = DietPatternSchema.options;
const ALLERGENS = AllergenSchema.options;
const RESTRICTIONS = RestrictionSchema.options;
const CUISINES = CuisineSchema.options;
const ACTIVITY_LEVELS = Object.keys(ACTIVITY_META) as ActivityLevel[];

export default function ProfileScreen() {
  const router = useRouter();
  const profile = useProfile();

  const store = useProfileStore();
  const setBirthYear = useSettingsStore((s) => s.setBirthYear);

  const phase = useMemo(() => computeCyclePhase(profile.cycle), [profile.cycle]);
  const bmi = bodyMassIndex(profile);
  const bmr = basalMetabolicRate(profile);

  const logPeriodToday = () => {
    const day = toIsoDay(new Date());
    if (profile.cycle.periodStarts.includes(day)) {
      Alert.alert('Already logged', 'Today is already recorded as a period start.');
      return;
    }
    store.updateCycle(withPeriodStart(profile.cycle, day));
  };

  return (
    <SafeAreaView className="flex-1 bg-canvas" edges={['top']}>
      <ScrollView showsVerticalScrollIndicator={false} contentContainerStyle={{ paddingBottom: 60 }}>
        <View className="flex-row items-center justify-between px-5 pt-1">
          <IconButton icon={ChevronLeft} label="Back" tone="onCanvas" onPress={() => router.back()} />
          <Text className="text-[15px] font-bold text-ink">Your profile</Text>
          <View className="w-9" />
        </View>

        {/* BODY */}
        <View className="mt-5 px-5">
          <SectionHeader title="Body" />
          <Stepper
            label="Height"
            unit="cm"
            value={profile.heightCm}
            onChange={(heightCm) => store.setBody({ heightCm })}
            step={1}
            min={120}
            max={220}
            fallback={170}
          />
          <Stepper
            label="Weight"
            unit="kg"
            value={profile.weightKg}
            onChange={(weightKg) => store.setBody({ weightKg })}
            step={0.5}
            min={35}
            max={200}
            fallback={70}
          />
          <Stepper
            label="Age"
            unit="years"
            value={profile.ageYears}
            onChange={(age) => setBirthYear(new Date().getFullYear() - age)}
            step={1}
            min={16}
            max={100}
            fallback={32}
          />

          {(bmi != null || bmr != null) && (
            <Card className="mt-1">
              <View className="flex-row">
                {bmi != null && (
                  <View className="flex-1">
                    <Text className="text-[10px] font-semibold uppercase tracking-wider text-faint">
                      BMI
                    </Text>
                    <Text className="mt-0.5 text-[19px] font-bold text-ink">{bmi}</Text>
                  </View>
                )}
                {bmr != null && (
                  <View className="flex-1">
                    <Text className="text-[10px] font-semibold uppercase tracking-wider text-faint">
                      Resting burn
                    </Text>
                    <Text className="mt-0.5 text-[19px] font-bold text-ink">
                      {Math.round(bmr)} kcal
                    </Text>
                  </View>
                )}
              </View>
              <Text className="mt-2 text-[11px] font-sans leading-4 text-faint">
                BMI is a population screening tool, not a diagnosis — it says nothing about body
                composition, and a muscular person will read &ldquo;overweight&rdquo; on it.
              </Text>
            </Card>
          )}
        </View>

        {/* GOAL */}
        <View className="mt-6 px-5">
          <SectionHeader title="Goal" />
          {GOALS.map((goal) => (
            <ChoiceRow
              key={goal}
              label={HEALTH_GOAL_META[goal].label}
              hint={HEALTH_GOAL_META[goal].hint}
              selected={profile.goal === goal}
              onPress={() => store.setGoal(goal)}
            />
          ))}

          {(profile.goal === 'weight-loss' || profile.goal === 'muscle-gain') && (
            <Stepper
              label="Target weight"
              unit="kg"
              value={profile.targetWeightKg}
              onChange={(targetWeightKg) => store.setBody({ targetWeightKg })}
              step={0.5}
              min={35}
              max={200}
              fallback={profile.weightKg ?? 70}
            />
          )}
        </View>

        {/* ACTIVITY */}
        <View className="mt-6 px-5">
          <SectionHeader title="Activity level" />
          {ACTIVITY_LEVELS.map((level) => (
            <ChoiceRow
              key={level}
              label={ACTIVITY_META[level].label}
              hint={ACTIVITY_META[level].hint}
              selected={profile.activityLevel === level}
              onPress={() => store.setActivityLevel(level)}
            />
          ))}
        </View>

        {/* CONDITIONS */}
        <View className="mt-6 px-5">
          <SectionHeader title="Managing" />
          <ChipGroup>
            {CONDITIONS.map((condition) => (
              <ChoiceChip
                key={condition}
                label={CONDITION_LABEL[condition]}
                selected={profile.conditions.includes(condition)}
                onPress={() => store.toggleCondition(condition)}
              />
            ))}
          </ChipGroup>
        </View>

        {/* DIET */}
        <View className="mt-6 px-5">
          <SectionHeader title="Diet" />
          {DIET_PATTERNS.map((pattern) => (
            <ChoiceRow
              key={pattern}
              label={DIET_PATTERN_META[pattern].label}
              hint={DIET_PATTERN_META[pattern].hint}
              selected={profile.dietPattern === pattern}
              onPress={() => store.setDietPattern(pattern)}
            />
          ))}
        </View>

        {/* ALLERGENS */}
        <View className="mt-6 px-5">
          <SectionHeader title="Allergies" />
          <Text className="mb-3 text-[12px] font-sans leading-[17px] text-faint">
            Excluded outright from every food and restaurant recommendation, including on a cheat
            day.
          </Text>
          <ChipGroup>
            {ALLERGENS.map((allergen) => (
              <ChoiceChip
                key={allergen}
                label={ALLERGEN_LABEL[allergen]}
                tone="critical"
                selected={profile.allergens.includes(allergen)}
                onPress={() => store.toggleAllergen(allergen)}
              />
            ))}
          </ChipGroup>
        </View>

        {/* RESTRICTIONS */}
        <View className="mt-6 px-5">
          <SectionHeader title="Preferences" />
          <ChipGroup>
            {RESTRICTIONS.map((restriction) => (
              <ChoiceChip
                key={restriction}
                label={RESTRICTION_LABEL[restriction]}
                selected={profile.restrictions.includes(restriction)}
                onPress={() => store.toggleRestriction(restriction)}
              />
            ))}
          </ChipGroup>
        </View>

        {/* CUISINES */}
        <View className="mt-6 px-5">
          <SectionHeader title="Cuisines" />
          <Text className="mb-3 text-[12px] font-sans leading-[17px] text-faint">
            Tapped in order of preference — the first carries the most weight when we suggest
            somewhere to eat.
          </Text>
          <ChipGroup>
            {CUISINES.map((cuisine) => {
              const rank = profile.cuisines.indexOf(cuisine);
              return (
                <ChoiceChip
                  key={cuisine}
                  label={CUISINE_LABEL[cuisine]}
                  selected={rank !== -1}
                  rank={rank === -1 ? null : rank + 1}
                  onPress={() => store.toggleCuisine(cuisine)}
                />
              );
            })}
          </ChipGroup>
        </View>

        {/* CYCLE */}
        <View className="mt-6 px-5">
          <SectionHeader title="Menstrual cycle" />
          <Card>
            <View className="flex-row items-center gap-3">
              <View className="h-10 w-10 items-center justify-center rounded-2xl bg-brand-50">
                <Droplets size={18} color={palette.brand} strokeWidth={2.2} />
              </View>
              <View className="flex-1">
                <Text className="text-[14px] font-semibold text-ink">Track my cycle</Text>
                <Text className="mt-0.5 text-[11px] font-sans leading-4 text-muted">
                  Adjusts training, calorie and food guidance by phase.
                </Text>
              </View>
              <Switch
                value={profile.cycle.tracks}
                onValueChange={(tracks) => store.updateCycle({ tracks })}
                trackColor={{ true: palette.brand, false: '#D6E4D8' }}
                thumbColor="#FFFFFF"
                accessibilityLabel="Track menstrual cycle"
              />
            </View>

            {profile.cycle.tracks && (
              <View className="mt-4 border-t border-hairline pt-4">
                {phase != null ? (
                  <View className="mb-3">
                    <Text className="text-[15px] font-semibold text-ink">{phase.label}</Text>
                    <Text className="mt-1 text-[12px] font-sans leading-[17px] text-muted">
                      {phase.summary}
                    </Text>
                    <Text className="mt-1.5 text-[11px] font-sans text-faint">
                      {phase.isMeasuredLength
                        ? `Using your measured ${phase.cycleLengthDays}-day cycle.`
                        : `Using an assumed ${phase.cycleLengthDays}-day cycle — log two periods and we measure it instead.`}
                    </Text>
                  </View>
                ) : (
                  <Text className="mb-3 text-[12px] font-sans leading-[17px] text-muted">
                    Log the first day of your period and we can place you in a phase. Apple Health
                    records this, but the library we use to read HealthKit does not expose the
                    menstrual-flow category — so it has to be logged here.
                  </Text>
                )}

                <Button
                  label="My period started today"
                  icon={CalendarPlus}
                  variant="secondary"
                  size="sm"
                  fullWidth
                  onPress={logPeriodToday}
                />

                {profile.cycle.periodStarts.length > 0 && (
                  <View className="mt-3">
                    <Text className="mb-1.5 text-[10px] font-bold uppercase tracking-wider text-faint">
                      Logged starts
                    </Text>
                    {[...profile.cycle.periodStarts]
                      .sort()
                      .reverse()
                      .slice(0, 4)
                      .map((day) => (
                        <Text key={day} className="text-[12px] font-sans text-muted">
                          • {formatRelativeDay(day)}
                        </Text>
                      ))}
                  </View>
                )}

                <View className="mt-4 border-t border-hairline pt-3">
                  <View className="flex-row items-center justify-between">
                    <Text className="flex-1 text-[13px] font-semibold text-ink">
                      Hormonal contraception
                    </Text>
                    <Switch
                      value={profile.cycle.hormonalContraception}
                      onValueChange={(hormonalContraception) =>
                        store.updateCycle({ hormonalContraception })
                      }
                      trackColor={{ true: palette.brand, false: '#D6E4D8' }}
                      thumbColor="#FFFFFF"
                      accessibilityLabel="On hormonal contraception"
                    />
                  </View>
                  <Text className="mt-1 text-[11px] font-sans leading-4 text-faint">
                    If this is on we keep phase guidance but mark it low-confidence — a withdrawal
                    bleed is not the same hormonal cycle.
                  </Text>
                </View>
              </View>
            )}
          </Card>
        </View>
      </ScrollView>
    </SafeAreaView>
  );
}
