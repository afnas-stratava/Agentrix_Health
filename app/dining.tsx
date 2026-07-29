import { useEffect } from 'react';
import { Linking, ScrollView, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useRouter } from 'expo-router';
import * as Haptics from 'expo-haptics';
import {
  CakeSlice,
  ChevronLeft,
  Info,
  MapPin,
  Navigation,
  Plus,
  Salad,
  Star,
} from 'lucide-react-native';

import { Card } from '@/components/ui/Card';
import { IconButton } from '@/components/ui/Button';
import { SectionHeader } from '@/components/ui/SectionHeader';
import { EmptyState } from '@/components/ui/EmptyState';
import { FadeIn } from '@/components/ui/FadeIn';
import { PressableScale } from '@/components/ui/PressableScale';
import { Skeleton } from '@/components/ui/Skeleton';

import type { RestaurantPick } from '@/schemas/dining';
import { useDiningMode, useLocationPermission, useNearbyDining } from '@/features/dining/queries';
import { FIXTURE_DISCLOSURE } from '@/features/dining/fixtures';
import { useTodayProgress } from '@/features/brief/use-brief';
import { useNutritionStore } from '@/store/nutrition.store';
import { slotForTime } from '@/features/nutrition/recognize';
import { palette } from '@/theme/colors';
import { cn } from '@/lib/cn';

/**
 * Nearby restaurants, ranked by what is left in today's budget.
 *
 * The recommendation is the *dish*, not the venue — so every card leads with
 * what to order and what it costs in macros, and the venue is context. Tapping
 * a dish logs it, which closes the loop between "where should I eat" and the
 * food diary that drives tomorrow's brief.
 */
export default function DiningScreen() {
  const router = useRouter();
  const { state, coords, request } = useLocationPermission();
  const { mode, toggle } = useDiningMode();
  const { picks, isFixture, isLoading } = useNearbyDining(coords, mode);
  const { remainingCalories, remainingProteinG } = useTodayProgress();
  const addMeal = useNutritionStore((s) => s.addMeal);

  // Ask on open rather than on launch: a health app that requests location at
  // first run reads as a tracking app.
  useEffect(() => {
    if (state === 'idle') void request();
  }, [state, request]);

  const logDish = (pick: RestaurantPick, dishIndex: number) => {
    const dish = pick.dishes[dishIndex];
    if (dish == null) return;

    void Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
    addMeal({
      slot: slotForTime(),
      source: 'restaurant',
      foods: [
        {
          foodId: dish.foodId,
          name: dish.name,
          portions: 1,
          macros: dish.macros,
          tags: dish.tags,
        },
      ],
      note: `At ${pick.restaurant.name}`,
    });
  };

  return (
    <SafeAreaView className="flex-1 bg-canvas" edges={['top']}>
      <ScrollView showsVerticalScrollIndicator={false} contentContainerStyle={{ paddingBottom: 48 }}>
        <View className="flex-row items-center justify-between px-5 pt-1">
          <IconButton icon={ChevronLeft} label="Back" tone="onCanvas" onPress={() => router.back()} />
          <Text className="text-[15px] font-bold text-ink">Eat out</Text>
          <View className="w-9" />
        </View>

        {/* BUDGET + MODE */}
        <FadeIn delay={30} className="mt-4 px-5">
          <Card>
            <View className="flex-row items-center justify-between">
              <View className="flex-1">
                <Text className="text-[10px] font-bold uppercase tracking-wider text-faint">
                  {mode === 'cheat' ? 'Cheat day' : 'Left today'}
                </Text>
                <Text className="mt-1 text-[24px] font-bold leading-7 text-ink">
                  {remainingCalories != null ? `${remainingCalories} kcal` : 'No target set'}
                </Text>
                {remainingProteinG != null && remainingProteinG > 0 && (
                  <Text className="mt-0.5 text-[12px] font-sans text-muted">
                    and {Math.round(remainingProteinG)} g of protein to go
                  </Text>
                )}
              </View>

              <PressableScale
                accessibilityRole="switch"
                accessibilityState={{ checked: mode === 'cheat' }}
                accessibilityLabel="Cheat day mode"
                accessibilityHint="Stops down-ranking indulgent dishes. Allergies and diet are still respected."
                onPress={toggle}
                className={cn(
                  'flex-row items-center gap-1.5 rounded-pill border px-3 py-2',
                  mode === 'cheat'
                    ? 'border-accent-strong bg-accent-soft'
                    : 'border-hairline bg-surface',
                )}
              >
                {mode === 'cheat' ? (
                  <CakeSlice size={15} color={palette.ink} strokeWidth={2.2} />
                ) : (
                  <Salad size={15} color={palette.faint} strokeWidth={2.2} />
                )}
                <Text
                  className={cn(
                    'text-[12px] font-semibold',
                    mode === 'cheat' ? 'text-ink' : 'text-muted',
                  )}
                >
                  {mode === 'cheat' ? 'Cheat' : 'On plan'}
                </Text>
              </PressableScale>
            </View>

            <Text className="mt-3 border-t border-hairline pt-3 text-[11px] font-sans leading-4 text-faint">
              {mode === 'cheat'
                ? 'Cheat mode ranks for what you actually want. Your allergies and diet are still hard filters — those never relax.'
                : 'Dishes are ranked against what you have left today, your blood work and your cuisines.'}
            </Text>
          </Card>
        </FadeIn>

        {/* LOCATION STATE */}
        {(state === 'denied' || state === 'unavailable') && (
          <FadeIn delay={60} className="mt-4 px-5">
            <View className="flex-row items-start gap-2.5 rounded-2xl border border-hairline bg-ink/4 px-4 py-3">
              <MapPin size={15} color={palette.faint} strokeWidth={2.2} />
              <Text className="flex-1 text-[11px] font-sans leading-[16px] text-muted">
                {state === 'denied'
                  ? 'Without location we cannot search around you, so these are example venues. You can enable location in Settings.'
                  : 'We could not get a location fix, so these are example venues.'}
              </Text>
            </View>
          </FadeIn>
        )}

        {isFixture && state === 'granted' && (
          <FadeIn delay={60} className="mt-4 px-5">
            <View className="flex-row items-start gap-2.5 rounded-2xl border border-hairline bg-ink/4 px-4 py-3">
              <Info size={15} color={palette.faint} strokeWidth={2.2} />
              <Text className="flex-1 text-[11px] font-sans leading-[16px] text-muted">
                {FIXTURE_DISCLOSURE}
              </Text>
            </View>
          </FadeIn>
        )}

        {/* PICKS */}
        <View className="mt-6 px-5">
          <SectionHeader
            title={mode === 'cheat' ? 'Worth the cheat' : 'Fits your day'}
            count={picks.length}
          />

          {isLoading && picks.length === 0 ? (
            <View className="gap-3">
              <Skeleton className="h-[180px] w-full rounded-card" />
              <Skeleton className="h-[180px] w-full rounded-card" />
            </View>
          ) : picks.length === 0 ? (
            <Card>
              <EmptyState
                icon={Salad}
                tone="onCard"
                title="Nothing we can recommend here"
                body="Every nearby venue serves food that conflicts with your allergies or diet. Widening your cuisines in Settings usually fixes this."
                actionLabel="Open settings"
                onAction={() => router.push('/(tabs)/settings')}
              />
            </Card>
          ) : (
            picks.map((pick, index) => (
              <FadeIn key={pick.restaurant.id} delay={40 * Math.min(index, 6)}>
                <RestaurantPickCard pick={pick} onLogDish={(i) => logDish(pick, i)} />
              </FadeIn>
            ))
          )}
        </View>

        <Text className="mt-6 px-10 text-center text-[10px] font-sans leading-[15px] text-faint">
          Dish suggestions are typical of each cuisine — we do not have these restaurants&apos; menus.
          Check with the venue for ingredients if you have an allergy.
        </Text>
      </ScrollView>
    </SafeAreaView>
  );
}

function RestaurantPickCard({
  pick,
  onLogDish,
}: {
  pick: RestaurantPick;
  onLogDish: (dishIndex: number) => void;
}) {
  const { restaurant, dishes, comboMacros, reasons } = pick;

  return (
    <Card className="mb-3" padded={false}>
      {/* VENUE */}
      <View className="flex-row items-start gap-3 px-4 pb-3 pt-4">
        <View className="flex-1">
          <Text className="text-[16px] font-bold leading-[20px] text-ink">{restaurant.name}</Text>

          <View className="mt-1 flex-row flex-wrap items-center gap-x-2 gap-y-1">
            {restaurant.rating != null && (
              <View className="flex-row items-center gap-1">
                <Star size={11} color={palette.borderline} strokeWidth={2.4} fill={palette.borderline} />
                <Text className="text-[11px] font-semibold text-muted">
                  {restaurant.rating.toFixed(1)}
                </Text>
              </View>
            )}
            {restaurant.distanceMetres != null && (
              <>
                <View className="h-[3px] w-[3px] rounded-full bg-faint" />
                <Text className="text-[11px] font-medium text-muted">
                  {restaurant.distanceMetres < 1000
                    ? `${restaurant.distanceMetres} m`
                    : `${(restaurant.distanceMetres / 1000).toFixed(1)} km`}
                </Text>
              </>
            )}
            {restaurant.priceLevel != null && (
              <>
                <View className="h-[3px] w-[3px] rounded-full bg-faint" />
                <Text className="text-[11px] font-medium text-muted">
                  {'₹'.repeat(restaurant.priceLevel)}
                </Text>
              </>
            )}
            {restaurant.source === 'fixture' && (
              <>
                <View className="h-[3px] w-[3px] rounded-full bg-faint" />
                <Text className="text-[11px] font-medium text-borderline">example venue</Text>
              </>
            )}
          </View>

          {reasons.length > 0 && (
            <Text className="mt-1.5 text-[11px] font-sans leading-[16px] text-muted">
              {reasons.join(' · ')}
            </Text>
          )}
        </View>

        {restaurant.mapsUri != null && (
          <IconButton
            icon={Navigation}
            label={`Directions to ${restaurant.name}`}
            onPress={() => void Linking.openURL(restaurant.mapsUri!)}
          />
        )}
      </View>

      {/* DISHES */}
      <View className="border-t border-hairline">
        {dishes.map((dish, index) => (
          <View
            key={dish.foodId}
            className={cn(
              'flex-row items-center gap-3 px-4 py-3',
              index !== dishes.length - 1 && 'border-b border-hairline',
            )}
          >
            <View className="flex-1">
              <View className="flex-row items-center gap-2">
                {index === 0 && (
                  <View className="rounded-pill bg-brand-600 px-1.5 py-[1px]">
                    <Text className="text-[8px] font-bold uppercase tracking-wider text-white">
                      Top pick
                    </Text>
                  </View>
                )}
                <Text className="flex-1 text-[14px] font-semibold text-ink" numberOfLines={1}>
                  {dish.name}
                </Text>
              </View>

              <Text className="mt-0.5 text-[11px] font-sans text-muted">
                {dish.portionLabel} · {dish.macros.calories} kcal ·{' '}
                {Math.round(dish.macros.proteinG)} g protein
              </Text>
              <Text className="mt-0.5 text-[11px] font-sans leading-[15px] text-faint">
                {dish.rationale}
              </Text>
            </View>

            <PressableScale
              accessibilityRole="button"
              accessibilityLabel={`Log ${dish.name}`}
              accessibilityHint="Adds this dish to today's food log"
              onPress={() => onLogDish(index)}
              className="h-9 w-9 items-center justify-center rounded-full bg-brand-50"
            >
              <Plus size={17} color={palette.brand} strokeWidth={2.5} />
            </PressableScale>
          </View>
        ))}
      </View>

      {/* COMBO */}
      {comboMacros.calories > 0 && (
        <View className="border-t border-hairline bg-brand-50/60 px-4 py-2.5">
          <Text className="text-[11px] font-sans leading-4 text-brand-800">
            Ordering the top {pick.dishes.length > 1 ? 'two' : 'pick'}:{' '}
            <Text className="font-semibold">{comboMacros.calories} kcal</Text>,{' '}
            {Math.round(comboMacros.proteinG)} g protein, {Math.round(comboMacros.fibreG)} g fibre.
          </Text>
        </View>
      )}
    </Card>
  );
}
