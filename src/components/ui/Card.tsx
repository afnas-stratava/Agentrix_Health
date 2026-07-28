import { View, type ViewProps } from 'react-native';
import { cn } from '@/lib/cn';

interface CardProps extends ViewProps {
  /**
   * `light` is the default cream card on the purple canvas.
   * `translucent` sits directly on the canvas for secondary groupings.
   * `accent` is reserved for the single highest-priority item on a screen.
   */
  tone?: 'light' | 'translucent' | 'accent';
  padded?: boolean;
}

const TONE_CLASSES = {
  light: 'bg-mockup-card-bg',
  translucent: 'bg-white/10 border border-white/15',
  accent: 'bg-mockup-accent',
} as const;

export function Card({
  tone = 'light',
  padded = true,
  className,
  children,
  ...rest
}: CardProps) {
  return (
    <View
      className={cn('rounded-card overflow-hidden', TONE_CLASSES[tone], padded && 'p-5', className)}
      {...rest}
    >
      {children}
    </View>
  );
}
