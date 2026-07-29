import type { LucideIcon } from 'lucide-react-native';
import { Pressable, Text, View } from 'react-native';
import { cn } from '@/lib/cn';
import { palette } from '@/theme/colors';

/**
 * Selection primitives shared by onboarding and settings.
 *
 * Two shapes, deliberately: a `ChoiceRow` for mutually-exclusive decisions that
 * need a sentence of explanation (goal, diet pattern), and a `ChoiceChip` for
 * multi-select sets where the label alone is enough (cuisines, allergens). A
 * screen that mixes the two arbitrarily is a screen where nothing reads as more
 * important than anything else.
 */

interface ChoiceRowProps {
  label: string;
  hint?: string;
  selected: boolean;
  onPress: () => void;
  icon?: LucideIcon;
  /** Radio renders a dot, checkbox a tick — matching single vs multi select. */
  control?: 'radio' | 'checkbox';
}

export function ChoiceRow({
  label,
  hint,
  selected,
  onPress,
  icon: Icon,
  control = 'radio',
}: ChoiceRowProps) {
  return (
    <Pressable
      accessibilityRole={control === 'radio' ? 'radio' : 'checkbox'}
      accessibilityState={{ selected }}
      accessibilityLabel={label}
      accessibilityHint={hint ?? ''}
      onPress={onPress}
      className={cn(
        'mb-2.5 rounded-card border p-4 active:opacity-80',
        selected ? 'border-brand-400 bg-brand-50' : 'border-hairline bg-surface',
      )}
    >
      <View className="flex-row items-center gap-3">
        <View
          className={cn(
            'items-center justify-center border-2',
            control === 'radio' ? 'h-5 w-5 rounded-full' : 'h-5 w-5 rounded-md',
            selected ? 'border-brand-600 bg-brand-600' : 'border-hairline',
          )}
        >
          {selected && (
            <View
              className={cn(
                control === 'radio' ? 'h-2 w-2 rounded-full bg-surface' : 'h-2 w-2 rounded-sm bg-surface',
              )}
            />
          )}
        </View>

        {Icon && <Icon size={17} color={selected ? palette.brand : palette.faint} strokeWidth={2.1} />}

        <Text className="flex-1 text-[15px] font-semibold text-ink">{label}</Text>
      </View>

      {hint != null && (
        <Text className="ml-8 mt-1 text-[12px] font-sans leading-4 text-muted">{hint}</Text>
      )}
    </Pressable>
  );
}

interface ChoiceChipProps {
  label: string;
  selected: boolean;
  onPress: () => void;
  /** Shows the selection order — used where order is preference weight. */
  rank?: number | null;
  tone?: 'brand' | 'critical';
}

export function ChoiceChip({ label, selected, onPress, rank = null, tone = 'brand' }: ChoiceChipProps) {
  const selectedClasses =
    tone === 'critical' ? 'border-critical/40 bg-critical/10' : 'border-brand-400 bg-brand-50';

  return (
    <Pressable
      accessibilityRole="checkbox"
      accessibilityState={{ selected }}
      accessibilityLabel={label}
      onPress={onPress}
      className={cn(
        'mb-2 mr-2 flex-row items-center gap-1.5 rounded-pill border px-3.5 py-2 active:opacity-70',
        selected ? selectedClasses : 'border-hairline bg-surface',
      )}
    >
      {rank != null && selected && (
        <View className="h-4 w-4 items-center justify-center rounded-full bg-brand-600">
          <Text className="text-[9px] font-bold text-white">{rank}</Text>
        </View>
      )}
      <Text
        className={cn(
          'text-[13px] font-semibold',
          selected ? (tone === 'critical' ? 'text-critical' : 'text-brand-700') : 'text-muted',
        )}
      >
        {label}
      </Text>
    </Pressable>
  );
}

/** Horizontal wrap container for chips. */
export function ChipGroup({ children }: { children: React.ReactNode }) {
  return <View className="flex-row flex-wrap">{children}</View>;
}

interface StepperProps {
  label: string;
  value: number | null;
  unit: string;
  onChange: (value: number) => void;
  step: number;
  min: number;
  max: number;
  /** Value used when the field is still empty and the user taps + or −. */
  fallback: number;
}

/**
 * Numeric entry without a keyboard.
 *
 * Height and weight are the two fields most likely to be abandoned during
 * onboarding, and a numeric keypad on a small screen is why. Stepping from a
 * sensible default gets to a usable figure in a couple of taps.
 */
export function Stepper({ label, value, unit, onChange, step, min, max, fallback }: StepperProps) {
  const current = value ?? fallback;

  const adjust = (delta: number) => {
    const next = Math.min(max, Math.max(min, Math.round((current + delta) * 10) / 10));
    onChange(next);
  };

  return (
    <View className="mb-3 flex-row items-center justify-between rounded-card border border-hairline bg-surface px-4 py-3">
      <View>
        <Text className="text-[13px] font-semibold text-ink">{label}</Text>
        <Text className="mt-0.5 text-[11px] font-sans text-faint">
          {value == null ? 'Not set' : `${value} ${unit}`}
        </Text>
      </View>

      <View className="flex-row items-center gap-3">
        <Pressable
          accessibilityRole="button"
          accessibilityLabel={`Decrease ${label}`}
          onPress={() => adjust(-step)}
          className="h-9 w-9 items-center justify-center rounded-full bg-ink/5 active:opacity-60"
        >
          <Text className="text-[18px] font-bold text-ink">−</Text>
        </Pressable>

        <Text className="min-w-[56px] text-center text-[17px] font-bold text-ink">
          {value == null ? '—' : value}
        </Text>

        <Pressable
          accessibilityRole="button"
          accessibilityLabel={`Increase ${label}`}
          onPress={() => adjust(step)}
          className="h-9 w-9 items-center justify-center rounded-full bg-brand-600 active:opacity-80"
        >
          <Text className="text-[18px] font-bold text-white">+</Text>
        </Pressable>
      </View>
    </View>
  );
}
