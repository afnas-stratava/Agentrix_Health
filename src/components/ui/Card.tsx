import { StyleSheet, View, type ViewProps } from 'react-native';
import { cn } from '@/lib/cn';
import { palette } from '@/theme/colors';

interface CardProps extends ViewProps {
  /**
   * `light` is the default white card on the near-white canvas.
   * `translucent` is a quieter, tinted grouping for secondary content.
   * `accent` is reserved for the single highest-priority item on a screen.
   */
  tone?: 'light' | 'translucent' | 'accent';
  padded?: boolean;
  /** Set false for nested cards, where a second shadow reads as muddy. */
  elevated?: boolean;
}

const TONE_CLASSES = {
  light: 'bg-surface border border-hairline',
  translucent: 'bg-brand-50/60 border border-hairline',
  accent: 'bg-accent',
} as const;

export function Card({
  tone = 'light',
  padded = true,
  elevated = true,
  className,
  style,
  children,
  ...rest
}: CardProps) {
  return (
    <View
      className={cn('rounded-card overflow-hidden', TONE_CLASSES[tone], padded && 'p-5', className)}
      // On a light canvas, separation comes from a soft lift rather than from
      // contrast against a dark background. The hairline border carries the
      // edge for users with shadows reduced.
      style={[elevated && tone !== 'translucent' ? styles.elevated : null, style]}
      {...rest}
    >
      {children}
    </View>
  );
}

const styles = StyleSheet.create({
  elevated: {
    shadowColor: palette.brandDeep,
    shadowOffset: { width: 0, height: 6 },
    shadowOpacity: 0.06,
    shadowRadius: 16,
    elevation: 2,
  },
});
