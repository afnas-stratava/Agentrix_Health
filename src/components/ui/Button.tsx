import { ActivityIndicator, Pressable, Text, View, type PressableProps } from 'react-native';
import * as Haptics from 'expo-haptics';
import type { LucideIcon } from 'lucide-react-native';
import { cn } from '@/lib/cn';
import { palette } from '@/theme/colors';

type Variant = 'primary' | 'secondary' | 'ghost' | 'danger';
type Size = 'sm' | 'md' | 'lg';

interface ButtonProps extends Omit<PressableProps, 'children' | 'style'> {
  label: string;
  variant?: Variant;
  size?: Size;
  icon?: LucideIcon;
  loading?: boolean;
  fullWidth?: boolean;
  className?: string;
  /** Defaults on for primary/danger; opt out for high-frequency taps. */
  haptics?: boolean;
}

const CONTAINER: Record<Variant, string> = {
  primary: 'bg-accent active:opacity-80',
  secondary: 'bg-ink/5 border border-hairline active:opacity-70',
  ghost: 'bg-transparent active:opacity-60',
  danger: 'bg-critical/15 border border-critical/40 active:opacity-70',
};

const LABEL: Record<Variant, string> = {
  primary: 'text-ink',
  secondary: 'text-ink',
  ghost: 'text-ink/80',
  danger: 'text-critical',
};

const ICON_COLOR: Record<Variant, string> = {
  primary: palette.cardText,
  secondary: palette.onBg,
  ghost: palette.onBgMuted,
  danger: palette.critical,
};

const SIZE: Record<Size, { container: string; label: string; icon: number }> = {
  sm: { container: 'h-9 px-3.5 rounded-pill', label: 'text-[13px]', icon: 15 },
  md: { container: 'h-12 px-5 rounded-pill', label: 'text-[15px]', icon: 18 },
  lg: { container: 'h-14 px-6 rounded-pill', label: 'text-base', icon: 20 },
};

export function Button({
  label,
  variant = 'primary',
  size = 'md',
  icon: Icon,
  loading = false,
  fullWidth = false,
  disabled,
  className,
  haptics,
  onPress,
  ...rest
}: ButtonProps) {
  const isDisabled = disabled === true || loading;
  const shouldBuzz = haptics ?? (variant === 'primary' || variant === 'danger');

  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={label}
      accessibilityState={{ disabled: isDisabled, busy: loading }}
      disabled={isDisabled}
      onPress={(event) => {
        if (shouldBuzz) void Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
        onPress?.(event);
      }}
      className={cn(
        'flex-row items-center justify-center gap-2',
        SIZE[size].container,
        CONTAINER[variant],
        fullWidth && 'w-full',
        isDisabled && 'opacity-45',
        className,
      )}
      {...rest}
    >
      {loading ? (
        <ActivityIndicator size="small" color={ICON_COLOR[variant]} />
      ) : (
        Icon && <Icon size={SIZE[size].icon} color={ICON_COLOR[variant]} strokeWidth={2.2} />
      )}
      <Text className={cn('font-semibold', SIZE[size].label, LABEL[variant])} numberOfLines={1}>
        {label}
      </Text>
    </Pressable>
  );
}

/**
 * Circular icon-only affordance used in headers and card corners.
 *
 * `tone` is retained for call-site compatibility but no longer changes much:
 * with a light canvas and white cards, both surfaces want the same ink icon.
 * `onBrand` is the one that genuinely differs — it sits on the green hero.
 */
export function IconButton({
  icon: Icon,
  label,
  onPress,
  tone = 'light',
  busy = false,
  className,
}: {
  icon: LucideIcon;
  label: string;
  onPress?: () => void;
  tone?: 'light' | 'onCanvas' | 'onBrand';
  /** Swaps the glyph for a spinner and blocks repeat taps while work is in flight. */
  busy?: boolean;
  className?: string;
}) {
  const onBrand = tone === 'onBrand';
  const color = onBrand ? palette.onBrand : palette.ink;

  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={label}
      accessibilityState={{ busy, disabled: busy }}
      disabled={busy}
      onPress={() => {
        void Haptics.selectionAsync();
        onPress?.();
      }}
      hitSlop={8}
      className={cn(
        'h-10 w-10 items-center justify-center rounded-full active:opacity-60',
        onBrand ? 'bg-white/15' : 'border border-hairline bg-surface',
        className,
      )}
    >
      <View pointerEvents="none">
        {busy ? (
          <ActivityIndicator size="small" color={color} />
        ) : (
          <Icon size={18} color={color} strokeWidth={2.1} />
        )}
      </View>
    </Pressable>
  );
}
