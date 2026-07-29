import { Pressable, Text, View } from 'react-native';
import { ChevronRight } from 'lucide-react-native';
import { palette } from '@/theme/colors';

interface SectionHeaderProps {
  title: string;
  /** Optional right-hand affordance, e.g. "See all". */
  actionLabel?: string;
  onAction?: () => void;
  count?: number;
}

export function SectionHeader({ title, actionLabel, onAction, count }: SectionHeaderProps) {
  return (
    <View className="mb-3 flex-row items-center justify-between">
      <View className="flex-row items-center gap-2">
        <Text className="text-[11px] font-semibold uppercase tracking-wider text-muted">
          {title}
        </Text>
        {count != null && count > 0 && (
          <View className="h-[18px] min-w-[18px] items-center justify-center rounded-full bg-ink/5 px-1.5">
            <Text className="text-[10px] font-bold text-ink/80">{count}</Text>
          </View>
        )}
      </View>

      {actionLabel && onAction && (
        <Pressable
          accessibilityRole="button"
          accessibilityLabel={actionLabel}
          onPress={onAction}
          hitSlop={8}
          className="flex-row items-center gap-0.5 active:opacity-60"
        >
          <Text className="text-[12px] font-semibold text-brand-600">{actionLabel}</Text>
          <ChevronRight size={13} color={palette.brand} strokeWidth={2.4} />
        </Pressable>
      )}
    </View>
  );
}
