import { useMemo } from 'react';
import { ScrollView, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useRouter } from 'expo-router';
import {
  CakeSlice,
  ChevronRight,
  MapPin,
  Plus,
  TrendingUp,
  UtensilsCrossed,
} from 'lucide-react-native';

import { Card } from '@/components/ui/Card';
import { Button } from '@/components/ui/Button';
import { SectionHeader } from '@/components/ui/SectionHeader';
import { EmptyState } from '@/components/ui/EmptyState';
import { FadeIn } from '@/components/ui/FadeIn';
import { PressableScale } from '@/components/ui/PressableScale';
import { CalorieRing, MacroBars, WaterTracker } from '@/components/nutrition/MacroSummary';
import { MealRow } from '@/components/nutrition/MealRow';

import { useTodayProgress } from '@/features/brief/use-brief';
import { analyseWeek } from '@/features/nutrition/patterns';
import { useDiningMode } from '@/features/dining/queries';
import { useNutritionStore } from '@/store/nutrition.store';
import { toIsoDay } from '@/lib/date';
import { palette } from '@/theme/colors';
import { cn } from '@/lib/cn';

/**
 * The food tab: today at the top, the week's patterns underneath.
 *
 * Ordered that way because logging is a today-shaped activity and analysis is a
 * week-shaped one — putting the weekly chart first would mean the primary
 * action (log something) sits below the fold on every launch.
 */
export default function FoodScreen() {
  const router = useRouter();
  const day = toIsoDay(new Date());

  const { targets, consumed, waterMl, remainingCalories } = useTodayProgress();
  const meals = useNutritionStore((s) => s.meals);
  const hydration = useNutritionStore((s) => s.hydration);
  const addWater = useNutritionStore((s) => s.addWater);
  const { mode, toggle: toggleCheat } = useDiningMode();

  const todayMeals = useMemo(
    () => meals.filter((meal) => meal.day === day).sort((a, b) => a.loggedAt.localeCompare(b.loggedAt)),
    [meals, day],
  );

  const week = useMemo(() => analyseWeek(meals, hydration, targets), [meals, hydration, targets]);

  if (targets == null) {
    return (
      <SafeAreaView className="flex-1 bg-canvas" edges={['top']}>
        <View className="flex-1 justify-center">
          <EmptyState
            icon={UtensilsCrossed}
            title="Tell us a little about you first"
            body="Calorie and macro targets need your height, weight and age. It takes about thirty seconds."
            actionLabel="Complete your profile"
            onAction={() => router.push('/(tabs)/settings')}
          />
        </View>
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView className="flex-1 bg-canvas" edges={['top']}>
      <ScrollView showsVerticalScrollIndicator={false} contentContainerStyle={{ paddingBottom: 130 }}>
        {/* HEADER */}
        <View className="mt-1 flex-row items-end justify-between px-5">
          <View>
            <Text className="text-[11px] font-medium text-muted">Today</Text>
            <Text className="mt-0.5 text-[25px] font-bold leading-[30px] text-ink">Food</Text>
          </View>

          <PressableScale
            accessibilityRole="switch"
            accessibilityState={{ checked: mode === 'cheat' }}
            accessibilityLabel="Cheat day"
            accessibilityHint="Raises your calorie target by 15% and stops down-ranking indulgent food"
            onPress={toggleCheat}
            className={cn(
              'flex-row items-center gap-1.5 rounded-pill border px-3 py-1.5',
              mode === 'cheat' ? 'border-accent-strong bg-accent-soft' : 'border-hairline bg-surface',
            )}
          >
            <CakeSlice
              size={14}
              color={mode === 'cheat' ? palette.ink : palette.faint}
              strokeWidth={2.2}
            />
            <Text
              className={cn(
                'text-[12px] font-semibold',
                mode === 'cheat' ? 'text-ink' : 'text-muted',
              )}
            >
              Cheat day
            </Text>
          </PressableScale>
        </View>

        {/* TODAY'S BUDGET */}
        <FadeIn delay={40} className="mt-4 px-5">
          <Card>
            <View className="flex-row items-center gap-4">
              <CalorieRing consumed={consumed.calories} target={targets.calories} size={132} />

              <View className="flex-1">
                <MacroBars
                  consumed={consumed}
                  targets={targets.macros}
                  sugarCeilingG={targets.addedSugarCeilingG}
                />
              </View>
            </View>

            <View className="mt-3 border-t border-hairline pt-3">
              <Text className="text-[11px] font-sans leading-4 text-faint">
                {targets.energyBasis === 'measured'
                  ? 'Target built from what your watch measured you burn this week.'
                  : 'Target estimated from your profile — it sharpens once your watch has a week of data.'}
                {targets.isCheatDay ? ' Cheat day is on: +15% calories.' : ''}
              </Text>
            </View>
          </Card>
        </FadeIn>

        {/* WATER */}
        <FadeIn delay={100} className="mt-4 px-5">
          <Card>
            <WaterTracker
              ml={waterMl}
              targetMl={targets.waterMl}
              onAdd={(amount) => addWater(amount)}
            />
          </Card>
        </FadeIn>

        {/* LOG ACTIONS */}
        <FadeIn delay={160} className="mt-5 px-5">
          <View className="flex-row gap-2.5">
            <Button
              label="Log a meal"
              icon={Plus}
              className="flex-1"
              onPress={() => router.push('/meal/log')}
            />
            <Button
              label="Eat out"
              icon={MapPin}
              variant="secondary"
              className="flex-1"
              onPress={() => router.push('/dining')}
            />
          </View>
        </FadeIn>

        {/* TODAY'S MEALS */}
        <FadeIn delay={220} className="mt-6 px-5">
          <SectionHeader
            title="Today's meals"
            count={todayMeals.length}
            {...(remainingCalories != null && remainingCalories > 0
              ? { actionLabel: `${remainingCalories} kcal left` }
              : {})}
          />

          {todayMeals.length === 0 ? (
            <Card>
              <EmptyState
                icon={UtensilsCrossed}
                tone="onCard"
                title="Nothing logged yet"
                body="Photograph your plate or pick from the food list — it takes a couple of taps and it is what makes the weekly patterns work."
                actionLabel="Log your first meal"
                onAction={() => router.push('/meal/log')}
              />
            </Card>
          ) : (
            <Card padded={false}>
              {todayMeals.map((meal, index) => (
                <MealRow key={meal.id} meal={meal} isLast={index === todayMeals.length - 1} />
              ))}
            </Card>
          )}
        </FadeIn>

        {/* WEEKLY PATTERNS */}
        <FadeIn delay={280} className="mt-6 px-5">
          <SectionHeader title="This week" count={week.patterns.length} />

          {week.isSparse ? (
            <Card>
              <View className="flex-row items-start gap-3">
                <TrendingUp size={18} color={palette.faint} strokeWidth={2.1} />
                <View className="flex-1">
                  <Text className="text-[14px] font-semibold text-ink">
                    {week.loggedDays} of 7 days logged
                  </Text>
                  <Text className="mt-1 text-[12px] font-sans leading-[17px] text-muted">
                    Pattern analysis needs at least three days before it says anything — three clean
                    days and four heavy ones average out to &ldquo;fine&rdquo;, which is exactly the
                    conclusion worth avoiding.
                  </Text>
                </View>
              </View>
            </Card>
          ) : (
            <Card padded={false}>
              {week.patterns.map((pattern, index) => (
                <View
                  key={pattern.id}
                  className={cn(
                    'px-4 py-3.5',
                    index !== week.patterns.length - 1 && 'border-b border-hairline',
                  )}
                >
                  <View className="flex-row items-center gap-2">
                    <View
                      className="h-1.5 w-1.5 rounded-full"
                      style={{
                        backgroundColor:
                          pattern.tone === 'concern' ? palette.abnormal : palette.optimal,
                      }}
                    />
                    <Text className="flex-1 text-[14px] font-semibold leading-[18px] text-ink">
                      {pattern.title}
                    </Text>
                  </View>
                  <Text className="ml-3.5 mt-1 text-[12px] font-sans leading-[17px] text-muted">
                    {pattern.detail}
                  </Text>
                </View>
              ))}

              {week.patterns.length === 0 && (
                <View className="px-4 py-5">
                  <Text className="text-[13px] font-semibold text-ink">
                    Nothing to flag this week
                  </Text>
                  <Text className="mt-1 text-[12px] font-sans leading-[17px] text-muted">
                    Across {week.loggedDays} logged days, no macro, sugar, sodium or timing pattern
                    crossed a threshold worth mentioning.
                  </Text>
                </View>
              )}
            </Card>
          )}
        </FadeIn>

        {/* WEEK AVERAGES */}
        {!week.isSparse && (
          <FadeIn delay={340} className="mt-6 px-5">
            <SectionHeader title="Daily average" actionLabel={`${week.loggedDays} logged days`} />
            <Card>
              <View className="flex-row flex-wrap">
                {[
                  { label: 'Calories', value: `${week.averages.calories}` },
                  { label: 'Protein', value: `${week.averages.proteinG} g` },
                  { label: 'Carbs', value: `${week.averages.carbsG} g` },
                  { label: 'Fat', value: `${week.averages.fatG} g` },
                  { label: 'Fibre', value: `${week.averages.fibreG} g` },
                  { label: 'Added sugar', value: `${week.averages.addedSugarG} g` },
                ].map((stat) => (
                  <View key={stat.label} className="w-1/3 py-2">
                    <Text className="text-[10px] font-semibold uppercase tracking-wider text-faint">
                      {stat.label}
                    </Text>
                    <Text className="mt-0.5 text-[17px] font-bold text-ink">{stat.value}</Text>
                  </View>
                ))}
              </View>
            </Card>
          </FadeIn>
        )}

        <PressableScale
          accessibilityRole="button"
          accessibilityLabel="See restaurant recommendations"
          onPress={() => router.push('/dining')}
          className="mx-5 mt-6 flex-row items-center gap-2.5 rounded-2xl border border-hairline bg-surface px-4 py-3.5"
        >
          <MapPin size={17} color={palette.brand} strokeWidth={2.2} />
          <Text className="flex-1 text-[13px] font-semibold text-ink">
            {remainingCalories != null && remainingCalories > 200
              ? `Eating out? ${remainingCalories} kcal left today`
              : 'Find somewhere to eat nearby'}
          </Text>
          <ChevronRight size={16} color={palette.faint} strokeWidth={2.2} />
        </PressableScale>
      </ScrollView>
    </SafeAreaView>
  );
}
