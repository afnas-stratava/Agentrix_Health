import { useMemo, useState } from 'react';
import {
  Alert,
  Image,
  Pressable,
  ScrollView,
  Text,
  TextInput,
  View,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useRouter } from 'expo-router';
import * as Haptics from 'expo-haptics';
import { Camera, ChevronLeft, ImageIcon, Info, Minus, Plus, Search, X } from 'lucide-react-native';

import { Button, IconButton } from '@/components/ui/Button';
import { Card } from '@/components/ui/Card';
import { SectionHeader } from '@/components/ui/SectionHeader';
import { PressableScale } from '@/components/ui/PressableScale';

import type { FoodDefinition, LoggedFood, MealSlot } from '@/schemas/nutrition';
import { MEAL_SLOT_LABEL, MealSlotSchema, scaleMacros, sumMacros } from '@/schemas/nutrition';
import { findFood, searchFoods } from '@/features/nutrition/food-database';
import { SUGGESTION_BASIS, slotForTime, suggestPlateContents } from '@/features/nutrition/recognize';
import { captureMealPhoto, pickMealPhoto, PhotoCancelled } from '@/features/nutrition/photo';
import { useProfile } from '@/features/profile/use-profile';
import { useNutritionStore } from '@/store/nutrition.store';
import { palette } from '@/theme/colors';
import { cn } from '@/lib/cn';

const SLOTS = MealSlotSchema.options as MealSlot[];

/**
 * Meal logging.
 *
 * Two ways in — photograph the plate, or search — converging on the same
 * confirm-and-adjust list. The photo is attached to the entry and the
 * suggestion list is ranked from the user's own profile and history; the copy
 * is explicit that it is not read from the image, because a food log that
 * quietly invents portions is worse than no food log.
 */
export default function LogMealScreen() {
  const router = useRouter();
  const profile = useProfile();

  const addMeal = useNutritionStore((s) => s.addMeal);
  const recentFoodIds = useNutritionStore((s) => s.recentFoodIds);

  const [slot, setSlot] = useState<MealSlot>(slotForTime());
  const [photoUri, setPhotoUri] = useState<string | null>(null);
  const [query, setQuery] = useState('');
  const [selected, setSelected] = useState<LoggedFood[]>([]);

  const suggestions = useMemo(
    () =>
      suggestPlateContents({
        slot,
        cuisines: profile.cuisines,
        dietPattern: profile.dietPattern,
        allergens: profile.allergens,
        recentFoodIds: recentFoodIds(),
        seed: photoUri ?? '',
      }),
    // `recentFoodIds` is a stable store action; the meals it reads change with
    // the store, which is what re-runs this.
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [slot, profile.cuisines, profile.dietPattern, profile.allergens, photoUri],
  );

  const results = useMemo(() => (query.trim().length > 1 ? searchFoods(query, 12) : []), [query]);

  const total = useMemo(() => sumMacros(selected.map((food) => food.macros)), [selected]);

  const addFood = (definition: FoodDefinition) => {
    void Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    setSelected((current) => {
      // Tapping the same dish twice means a second helping, not a duplicate row.
      const existing = current.findIndex((food) => food.foodId === definition.id);
      if (existing !== -1) {
        return current.map((food, index) =>
          index === existing ? withPortions(food, definition, food.portions + 1) : food,
        );
      }

      return [
        ...current,
        {
          foodId: definition.id,
          name: definition.name,
          portions: 1,
          macros: definition.macros,
          tags: definition.tags,
        },
      ];
    });
    setQuery('');
  };

  const changePortions = (index: number, delta: number) => {
    setSelected((current) =>
      current
        .map((food, i) => {
          if (i !== index) return food;
          const next = Math.round((food.portions + delta) * 2) / 2;
          if (next <= 0) return null;
          const definition = definitionFor(food);
          return definition ? withPortions(food, definition, next) : food;
        })
        .filter((food): food is LoggedFood => food != null),
    );
  };

  const attachPhoto = async (source: 'camera' | 'library') => {
    try {
      const uri = source === 'camera' ? await captureMealPhoto() : await pickMealPhoto();
      setPhotoUri(uri);
    } catch (error) {
      if (error instanceof PhotoCancelled) return;
      Alert.alert(
        'Could not attach the photo',
        error instanceof Error ? error.message : 'Something went wrong.',
      );
    }
  };

  const save = () => {
    if (selected.length === 0) return;
    void Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);

    addMeal({
      slot,
      foods: selected,
      source: photoUri != null ? 'photo' : 'database',
      photoUri,
      // Confirmed by the user in this screen, so the entry is fully trusted
      // regardless of how the foods got onto the list.
      confidence: 1,
    });

    router.back();
  };

  return (
    <SafeAreaView className="flex-1 bg-canvas" edges={['top']}>
      <View className="flex-row items-center justify-between px-5 pt-1">
        <IconButton icon={ChevronLeft} label="Back" tone="onCanvas" onPress={() => router.back()} />
        <Text className="text-[15px] font-bold text-ink">Log a meal</Text>
        <View className="w-9" />
      </View>

      <ScrollView
        className="flex-1"
        contentContainerStyle={{ paddingBottom: 140 }}
        keyboardShouldPersistTaps="handled"
        showsVerticalScrollIndicator={false}
      >
        {/* SLOT */}
        <View className="mt-4 flex-row gap-1.5 px-5">
          {SLOTS.map((option) => (
            <Pressable
              key={option}
              accessibilityRole="radio"
              accessibilityState={{ selected: slot === option }}
              onPress={() => setSlot(option)}
              className={cn(
                'flex-1 items-center rounded-pill border py-2 active:opacity-70',
                slot === option ? 'border-brand-600 bg-brand-600' : 'border-hairline bg-surface',
              )}
            >
              <Text
                className={cn(
                  'text-[12px] font-semibold',
                  slot === option ? 'text-white' : 'text-muted',
                )}
              >
                {MEAL_SLOT_LABEL[option]}
              </Text>
            </Pressable>
          ))}
        </View>

        {/* PHOTO */}
        <View className="mt-5 px-5">
          {photoUri != null ? (
            <View>
              <Image
                source={{ uri: photoUri }}
                className="h-44 w-full rounded-card"
                resizeMode="cover"
                accessibilityIgnoresInvertColors
              />
              <Pressable
                accessibilityRole="button"
                accessibilityLabel="Remove photo"
                onPress={() => setPhotoUri(null)}
                className="absolute right-3 top-3 h-8 w-8 items-center justify-center rounded-full bg-ink/70"
              >
                <X size={16} color="#FFFFFF" strokeWidth={2.5} />
              </Pressable>
            </View>
          ) : (
            <View className="flex-row gap-2.5">
              <Button
                label="Take photo"
                icon={Camera}
                variant="secondary"
                className="flex-1"
                onPress={() => void attachPhoto('camera')}
              />
              <Button
                label="From library"
                icon={ImageIcon}
                variant="secondary"
                className="flex-1"
                onPress={() => void attachPhoto('library')}
              />
            </View>
          )}
        </View>

        {/* SELECTED */}
        {selected.length > 0 && (
          <View className="mt-6 px-5">
            <SectionHeader title="On your plate" count={selected.length} />
            <Card padded={false}>
              {selected.map((food, index) => (
                <View
                  key={`${food.foodId}-${index}`}
                  className={cn(
                    'flex-row items-center gap-3 px-4 py-3',
                    index !== selected.length - 1 && 'border-b border-hairline',
                  )}
                >
                  <View className="flex-1">
                    <Text className="text-[14px] font-semibold text-ink">{food.name}</Text>
                    <Text className="mt-0.5 text-[11px] font-sans text-muted">
                      {food.macros.calories} kcal · {Math.round(food.macros.proteinG)} g protein
                    </Text>
                  </View>

                  <View className="flex-row items-center gap-2">
                    <Pressable
                      accessibilityRole="button"
                      accessibilityLabel={`Less ${food.name}`}
                      onPress={() => changePortions(index, -0.5)}
                      className="h-7 w-7 items-center justify-center rounded-full bg-ink/5 active:opacity-60"
                    >
                      <Minus size={13} color={palette.ink} strokeWidth={2.6} />
                    </Pressable>
                    <Text className="min-w-[26px] text-center text-[13px] font-bold text-ink">
                      {food.portions}
                    </Text>
                    <Pressable
                      accessibilityRole="button"
                      accessibilityLabel={`More ${food.name}`}
                      onPress={() => changePortions(index, 0.5)}
                      className="h-7 w-7 items-center justify-center rounded-full bg-brand-600 active:opacity-80"
                    >
                      <Plus size={13} color="#FFFFFF" strokeWidth={2.6} />
                    </Pressable>
                  </View>
                </View>
              ))}
            </Card>
          </View>
        )}

        {/* SEARCH */}
        <View className="mt-6 px-5">
          <SectionHeader title="Add food" />
          <View className="flex-row items-center gap-2 rounded-card border border-hairline bg-surface px-3.5 py-2.5">
            <Search size={16} color={palette.faint} strokeWidth={2.2} />
            <TextInput
              value={query}
              onChangeText={setQuery}
              placeholder="Search dal, dosa, salmon…"
              placeholderTextColor={palette.faint}
              autoCorrect={false}
              className="flex-1 text-[14px] text-ink"
              accessibilityLabel="Search foods"
            />
            {query.length > 0 && (
              <Pressable accessibilityRole="button" accessibilityLabel="Clear" onPress={() => setQuery('')}>
                <X size={15} color={palette.faint} strokeWidth={2.4} />
              </Pressable>
            )}
          </View>

          {results.length > 0 && (
            <Card padded={false} className="mt-2.5">
              {results.map((item, index) => (
                <PressableScale
                  key={item.id}
                  scaleTo={0.985}
                  accessibilityRole="button"
                  accessibilityLabel={`Add ${item.name}`}
                  onPress={() => addFood(item)}
                  className={cn(
                    'flex-row items-center gap-3 px-4 py-3',
                    index !== results.length - 1 && 'border-b border-hairline',
                  )}
                >
                  <View className="flex-1">
                    <Text className="text-[14px] font-semibold text-ink">{item.name}</Text>
                    <Text className="mt-0.5 text-[11px] font-sans text-muted">
                      {item.portionLabel} · {item.macros.calories} kcal
                    </Text>
                  </View>
                  <Plus size={16} color={palette.brand} strokeWidth={2.4} />
                </PressableScale>
              ))}
            </Card>
          )}
        </View>

        {/* SUGGESTIONS */}
        {results.length === 0 && (
          <View className="mt-6 px-5">
            <SectionHeader title={`Likely at ${MEAL_SLOT_LABEL[slot].toLowerCase()}`} />

            <View className="mb-3 flex-row items-start gap-2 rounded-2xl border border-hairline bg-ink/4 px-3.5 py-2.5">
              <Info size={14} color={palette.faint} strokeWidth={2.2} />
              <Text className="flex-1 text-[11px] font-sans leading-[16px] text-muted">
                {SUGGESTION_BASIS}
              </Text>
            </View>

            <Card padded={false}>
              {suggestions.map((suggestion, index) => (
                <PressableScale
                  key={suggestion.food.id}
                  scaleTo={0.985}
                  accessibilityRole="button"
                  accessibilityLabel={`Add ${suggestion.food.name}`}
                  onPress={() => addFood(suggestion.food)}
                  className={cn(
                    'flex-row items-center gap-3 px-4 py-3',
                    index !== suggestions.length - 1 && 'border-b border-hairline',
                  )}
                >
                  <View className="flex-1">
                    <Text className="text-[14px] font-semibold text-ink">{suggestion.food.name}</Text>
                    <Text className="mt-0.5 text-[11px] font-sans text-muted">
                      {suggestion.food.portionLabel} · {suggestion.food.macros.calories} kcal ·{' '}
                      {suggestion.reason}
                    </Text>
                  </View>
                  <Plus size={16} color={palette.brand} strokeWidth={2.4} />
                </PressableScale>
              ))}
            </Card>
          </View>
        )}
      </ScrollView>

      {/* SAVE BAR */}
      <View className="absolute bottom-0 w-full border-t border-hairline bg-surface px-5 pb-7 pt-3">
        <View className="mb-2.5 flex-row items-baseline justify-between">
          <Text className="text-[13px] font-semibold text-ink">
            {total.calories} kcal
            {selected.length > 0 && (
              <Text className="font-sans text-muted">
                {'  '}
                {Math.round(total.proteinG)}P · {Math.round(total.carbsG)}C · {Math.round(total.fatG)}F
              </Text>
            )}
          </Text>
          <Text className="text-[11px] font-sans text-faint">
            {selected.length} item{selected.length === 1 ? '' : 's'}
          </Text>
        </View>

        <Button
          label={selected.length === 0 ? 'Add something first' : 'Save meal'}
          size="lg"
          fullWidth
          disabled={selected.length === 0}
          onPress={save}
        />
      </View>
    </SafeAreaView>
  );
}

/** Rescales a logged food's macros when its portion count changes. */
function withPortions(
  food: LoggedFood,
  definition: FoodDefinition,
  portions: number,
): LoggedFood {
  return { ...food, portions, macros: scaleMacros(definition.macros, portions) };
}

/**
 * Portion maths has to rescale from the *definition*, not from the current
 * (already-scaled) macros, or repeated adjustments compound rounding error.
 */
function definitionFor(food: LoggedFood): FoodDefinition | null {
  return food.foodId == null ? null : findFood(food.foodId);
}
