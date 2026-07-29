import { Text, View } from 'react-native';
import { cn } from '@/lib/cn';
import { palette } from '@/theme/colors';

interface BadgeProps {
  label: string;
  /** Any hex from the theme; the pill derives its fill from it. */
  color: string;
  className?: string;
  size?: 'sm' | 'md';
}

export function Badge({ label, color, className, size = 'sm' }: BadgeProps) {
  return (
    <View
      // Alpha-blended fill keeps the pill legible on both the cream card and
      // the purple canvas without needing two colour sets.
      style={{ backgroundColor: `${color}22`, borderColor: `${color}55` }}
      className={cn(
        'self-start rounded-pill border',
        size === 'sm' ? 'px-2 py-0.5' : 'px-3 py-1',
        className,
      )}
    >
      <Text
        style={{ color }}
        className={cn('font-semibold', size === 'sm' ? 'text-[11px]' : 'text-xs')}
      >
        {label}
      </Text>
    </View>
  );
}

/** Small ▲/▼ delta chip used on metric cards. */
export function DeltaBadge({
  deltaPct,
  goodDirection,
}: {
  deltaPct: number | null;
  goodDirection: 'up' | 'down';
}) {
  if (deltaPct == null || !Number.isFinite(deltaPct)) return null;

  const rounded = Math.round(deltaPct);
  if (rounded === 0) {
    return <Badge label="Steady" color={palette.faint} />;
  }

  const isUp = rounded > 0;
  const isGood = (isUp && goodDirection === 'up') || (!isUp && goodDirection === 'down');

  return (
    <Badge
      label={`${isUp ? '▲' : '▼'} ${Math.abs(rounded)}%`}
      color={isGood ? palette.optimal : palette.abnormal}
    />
  );
}
