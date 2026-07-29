import { ScrollView, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useRouter } from 'expo-router';
import { ChevronLeft, ShieldAlert } from 'lucide-react-native';

import { Button, IconButton } from '@/components/ui/Button';
import { ChipGroup, ChoiceChip, ChoiceRow } from '@/components/ui/Choice';
import { useProfileStore } from '@/store/profile.store';
import {
  ALLERGEN_LABEL,
  AllergenSchema,
  CUISINE_LABEL,
  CuisineSchema,
  DIET_PATTERN_META,
  DietPatternSchema,
  RESTRICTION_LABEL,
  RestrictionSchema,
  type Allergen,
  type Cuisine,
  type DietPattern,
  type Restriction,
} from '@/schemas/profile';
import { palette } from '@/theme/colors';

/**
 * Diet, allergies and cuisine history.
 *
 * The distinction between the three groups is load-bearing, and the copy says
 * so: allergens and the diet pattern are *hard filters* that food and
 * restaurant recommendations may never violate, restrictions are preferences
 * that down-rank, and cuisines are an ordered preference that decides what
 * floats to the top. Getting a user to understand that in one screen is why
 * they are visually distinct rather than three identical chip rows.
 */

const DIET_PATTERNS = DietPatternSchema.options as DietPattern[];
const ALLERGENS = AllergenSchema.options as Allergen[];
const RESTRICTIONS = RestrictionSchema.options as Restriction[];
const CUISINES = CuisineSchema.options as Cuisine[];

export default function DietStep() {
  const router = useRouter();

  const dietPattern = useProfileStore((s) => s.dietPattern);
  const allergens = useProfileStore((s) => s.allergens);
  const restrictions = useProfileStore((s) => s.restrictions);
  const cuisines = useProfileStore((s) => s.cuisines);

  const setDietPattern = useProfileStore((s) => s.setDietPattern);
  const toggleAllergen = useProfileStore((s) => s.toggleAllergen);
  const toggleRestriction = useProfileStore((s) => s.toggleRestriction);
  const toggleCuisine = useProfileStore((s) => s.toggleCuisine);

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
        <Text className="mt-6 text-[28px] font-bold leading-8 text-ink">How do you eat?</Text>
        <Text className="mt-3 text-[13px] font-sans leading-5 text-muted">
          Nothing we recommend — a meal, a dish, a restaurant — will ever contradict what you set
          here.
        </Text>

        <Text className="mb-3 mt-7 text-[11px] font-semibold uppercase tracking-wider text-muted">
          Diet
        </Text>
        {DIET_PATTERNS.map((pattern) => (
          <ChoiceRow
            key={pattern}
            label={DIET_PATTERN_META[pattern].label}
            hint={DIET_PATTERN_META[pattern].hint}
            selected={dietPattern === pattern}
            onPress={() => setDietPattern(pattern)}
          />
        ))}

        <View className="mb-3 mt-7 flex-row items-center gap-2">
          <ShieldAlert size={15} color={palette.critical} strokeWidth={2.3} />
          <Text className="text-[11px] font-semibold uppercase tracking-wider text-muted">
            Allergies
          </Text>
        </View>
        <Text className="mb-3 text-[12px] font-sans leading-[17px] text-faint">
          Anything selected here is excluded outright, everywhere in the app.
        </Text>
        <ChipGroup>
          {ALLERGENS.map((allergen) => (
            <ChoiceChip
              key={allergen}
              label={ALLERGEN_LABEL[allergen]}
              tone="critical"
              selected={allergens.includes(allergen)}
              onPress={() => toggleAllergen(allergen)}
            />
          ))}
        </ChipGroup>

        <Text className="mb-3 mt-7 text-[11px] font-semibold uppercase tracking-wider text-muted">
          Preferences
        </Text>
        <Text className="mb-3 text-[12px] font-sans leading-[17px] text-faint">
          Softer than an allergy — these push options down the list rather than removing them.
        </Text>
        <ChipGroup>
          {RESTRICTIONS.map((restriction) => (
            <ChoiceChip
              key={restriction}
              label={RESTRICTION_LABEL[restriction]}
              selected={restrictions.includes(restriction)}
              onPress={() => toggleRestriction(restriction)}
            />
          ))}
        </ChipGroup>

        <Text className="mb-3 mt-7 text-[11px] font-semibold uppercase tracking-wider text-muted">
          Cuisines you eat most
        </Text>
        <Text className="mb-3 text-[12px] font-sans leading-[17px] text-faint">
          Tap in order of preference — the first one you pick carries the most weight when we
          suggest somewhere to eat.
        </Text>
        <ChipGroup>
          {CUISINES.map((cuisine) => {
            const rank = cuisines.indexOf(cuisine);
            return (
              <ChoiceChip
                key={cuisine}
                label={CUISINE_LABEL[cuisine]}
                selected={rank !== -1}
                rank={rank === -1 ? null : rank + 1}
                onPress={() => toggleCuisine(cuisine)}
              />
            );
          })}
        </ChipGroup>
      </ScrollView>

      <View className="px-8 pb-6 pt-2">
        <Button
          label="Continue"
          size="lg"
          fullWidth
          onPress={() => router.push('/onboarding/permissions')}
        />
        <Text className="mt-3 text-center text-[11px] font-sans text-faint">
          {cuisines.length === 0
            ? 'Skipping cuisines is fine — recommendations will just be less tailored.'
            : `${cuisines.length} cuisine${cuisines.length === 1 ? '' : 's'} selected.`}
        </Text>
      </View>
    </SafeAreaView>
  );
}
