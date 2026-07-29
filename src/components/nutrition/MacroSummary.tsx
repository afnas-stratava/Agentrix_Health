import { Text, View } from 'react-native';
import Svg, { Circle } from 'react-native-svg';
import type { Macros, MacroTargets } from '@/schemas/nutrition';
import { palette } from '@/theme/colors';
import { cn } from '@/lib/cn';

/**
 * Today's intake against today's targets.
 *
 * A solid ring is right here — unlike the readiness gauge, which encodes a
 * statistical estimate, a calorie total is a straight sum of things the user
 * explicitly logged. The precision the ring implies is precision the number
 * actually has.
 */

interface CalorieRingProps {
  consumed: number;
  target: number;
  size?: number;
  strokeWidth?: number;
  /** Renders the remainder rather than the total in the centre. */
  showRemaining?: boolean;
}

export function CalorieRing({
  consumed,
  target,
  size = 152,
  strokeWidth = 12,
  showRemaining = true,
}: CalorieRingProps) {
  const radius = (size - strokeWidth) / 2;
  const circumference = 2 * Math.PI * radius;
  const ratio = target > 0 ? consumed / target : 0;
  // Cap the sweep at a full turn; overshoot is communicated by colour, not by
  // a second lap, which would read as "back to nearly empty".
  const progress = Math.min(1, Math.max(0, ratio));

  const over = ratio > 1.02;
  const ringColor = over ? palette.abnormal : ratio > 0.85 ? palette.optimal : palette.brand;
  const remaining = Math.max(0, target - consumed);

  return (
    <View style={{ width: size, height: size }} className="items-center justify-center">
      <Svg width={size} height={size} style={{ position: 'absolute' }}>
        <Circle
          cx={size / 2}
          cy={size / 2}
          r={radius}
          stroke={palette.hairline}
          strokeWidth={strokeWidth}
          fill="none"
        />
        <Circle
          cx={size / 2}
          cy={size / 2}
          r={radius}
          stroke={ringColor}
          strokeWidth={strokeWidth}
          fill="none"
          strokeLinecap="round"
          strokeDasharray={circumference}
          strokeDashoffset={circumference * (1 - progress)}
          // Start the sweep at 12 o'clock rather than 3.
          transform={`rotate(-90 ${size / 2} ${size / 2})`}
        />
      </Svg>

      <Text className="text-[32px] font-bold leading-9 text-ink">
        {showRemaining ? remaining : consumed}
      </Text>
      <Text className="mt-0.5 text-[10px] font-semibold uppercase tracking-wider text-faint">
        {over ? 'over target' : showRemaining ? 'kcal left' : 'kcal eaten'}
      </Text>
      <Text className="mt-1 text-[11px] font-sans text-muted">
        {consumed} / {target}
      </Text>
    </View>
  );
}

interface MacroBarProps {
  label: string;
  consumed: number;
  target: number;
  unit?: string;
  color: string;
  /** Above-target is a *problem* for sugar and sodium, not for protein. */
  overIsBad?: boolean;
}

export function MacroBar({
  label,
  consumed,
  target,
  unit = 'g',
  color,
  overIsBad = false,
}: MacroBarProps) {
  const ratio = target > 0 ? consumed / target : 0;
  const width = `${Math.min(100, Math.max(0, ratio * 100))}%` as const;
  const isOver = ratio > 1;
  const barColor = isOver && overIsBad ? palette.abnormal : color;

  return (
    <View className="mb-2.5">
      <View className="mb-1 flex-row items-baseline justify-between">
        <Text className="text-[12px] font-semibold text-ink">{label}</Text>
        <Text className={cn('text-[11px] font-sans', isOver && overIsBad ? 'text-abnormal' : 'text-muted')}>
          {Math.round(consumed)}
          {unit} <Text className="text-faint">/ {Math.round(target)}{unit}</Text>
        </Text>
      </View>
      <View className="h-1.5 w-full overflow-hidden rounded-full bg-ink/8">
        <View style={{ width, backgroundColor: barColor }} className="h-full rounded-full" />
      </View>
    </View>
  );
}

interface MacroBarsProps {
  consumed: Macros;
  targets: MacroTargets;
  sugarCeilingG: number;
}

export function MacroBars({ consumed, targets, sugarCeilingG }: MacroBarsProps) {
  return (
    <View>
      <MacroBar label="Protein" consumed={consumed.proteinG} target={targets.proteinG} color={palette.brand} />
      <MacroBar label="Carbs" consumed={consumed.carbsG} target={targets.carbsG} color={palette.normal} />
      <MacroBar label="Fat" consumed={consumed.fatG} target={targets.fatG} color={palette.borderline} />
      <MacroBar label="Fibre" consumed={consumed.fibreG} target={targets.fibreG} color={palette.optimal} />
      <MacroBar
        label="Added sugar"
        consumed={consumed.addedSugarG}
        target={sugarCeilingG}
        color={palette.accentStrong}
        overIsBad
      />
    </View>
  );
}

interface WaterTrackerProps {
  ml: number;
  targetMl: number;
  onAdd: (ml: number) => void;
}

/** Glasses rather than a bar — water is logged in discrete, tappable units. */
export function WaterTracker({ ml, targetMl, onAdd }: WaterTrackerProps) {
  const glassMl = 250;
  const targetGlasses = Math.max(1, Math.round(targetMl / glassMl));
  const filled = Math.floor(ml / glassMl);

  return (
    <View>
      <View className="mb-2 flex-row items-baseline justify-between">
        <Text className="text-[13px] font-semibold text-ink">Water</Text>
        <Text className="text-[11px] font-sans text-muted">
          {(ml / 1000).toFixed(1)} L <Text className="text-faint">/ {(targetMl / 1000).toFixed(1)} L</Text>
        </Text>
      </View>

      <View className="flex-row flex-wrap gap-1.5">
        {Array.from({ length: Math.min(12, targetGlasses) }, (_, index) => (
          <View
            key={index}
            accessible
            accessibilityLabel={`Glass ${index + 1} of ${targetGlasses}`}
            className={cn(
              'h-8 w-6 rounded-md border',
              index < filled ? 'border-brand-400 bg-brand-400' : 'border-hairline bg-surface',
            )}
          />
        ))}
      </View>

      <View className="mt-3 flex-row gap-2">
        {[250, 500].map((amount) => (
          <Text
            key={amount}
            accessibilityRole="button"
            accessibilityLabel={`Add ${amount} millilitres of water`}
            onPress={() => onAdd(amount)}
            className="rounded-pill border border-hairline bg-surface px-3 py-1.5 text-[12px] font-semibold text-brand-700"
          >
            +{amount} ml
          </Text>
        ))}
      </View>
    </View>
  );
}
