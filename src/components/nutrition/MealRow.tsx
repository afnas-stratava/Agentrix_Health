import { Image, Text, View } from 'react-native';
import { Camera, ChevronRight, PenLine, Utensils } from 'lucide-react-native';
import type { MealEntry } from '@/schemas/nutrition';
import { MEAL_SLOT_LABEL, mealMacros } from '@/schemas/nutrition';
import { PressableScale } from '@/components/ui/PressableScale';
import { palette } from '@/theme/colors';
import { cn } from '@/lib/cn';

const SOURCE_ICON = {
  photo: Camera,
  manual: PenLine,
  database: Utensils,
  restaurant: Utensils,
  seed: Utensils,
} as const;

interface MealRowProps {
  meal: MealEntry;
  isLast?: boolean;
  onPress?: () => void;
}

export function MealRow({ meal, isLast = false, onPress }: MealRowProps) {
  const macros = mealMacros(meal);
  const Icon = SOURCE_ICON[meal.source];
  const names = meal.foods.map((food) =>
    food.portions === 1 ? food.name : `${food.portions}× ${food.name}`,
  );

  const time = new Date(meal.loggedAt).toLocaleTimeString(undefined, {
    hour: 'numeric',
    minute: '2-digit',
  });

  return (
    <PressableScale
      scaleTo={0.985}
      accessibilityRole="button"
      accessibilityLabel={`${MEAL_SLOT_LABEL[meal.slot]}: ${names.join(', ')}, ${macros.calories} calories`}
      onPress={onPress}
      className={cn('flex-row items-center gap-3 px-4 py-3.5', !isLast && 'border-b border-hairline')}
    >
      {meal.photoUri != null ? (
        <Image
          source={{ uri: meal.photoUri }}
          className="h-11 w-11 rounded-xl"
          accessibilityIgnoresInvertColors
        />
      ) : (
        <View className="h-11 w-11 items-center justify-center rounded-xl bg-brand-50">
          <Icon size={17} color={palette.brand} strokeWidth={2.1} />
        </View>
      )}

      <View className="flex-1">
        <View className="flex-row items-center gap-1.5">
          <Text className="text-[10px] font-bold uppercase tracking-wider text-faint">
            {MEAL_SLOT_LABEL[meal.slot]}
          </Text>
          <View className="h-[3px] w-[3px] rounded-full bg-faint" />
          <Text className="text-[10px] font-medium text-faint">{time}</Text>
          {meal.confidence < 1 && (
            // An unconfirmed photo entry is a guess the user has not signed off
            // on; saying so is cheaper than being quietly wrong in the totals.
            <>
              <View className="h-[3px] w-[3px] rounded-full bg-faint" />
              <Text className="text-[10px] font-medium text-borderline">unconfirmed</Text>
            </>
          )}
        </View>

        <Text className="mt-0.5 text-[14px] font-semibold leading-[18px] text-ink" numberOfLines={1}>
          {names.join(', ')}
        </Text>

        <Text className="mt-0.5 text-[11px] font-sans text-muted">
          {macros.calories} kcal · {Math.round(macros.proteinG)}P · {Math.round(macros.carbsG)}C ·{' '}
          {Math.round(macros.fatG)}F
        </Text>
      </View>

      {onPress != null && <ChevronRight size={16} color={palette.faint} strokeWidth={2.2} />}
    </PressableScale>
  );
}
