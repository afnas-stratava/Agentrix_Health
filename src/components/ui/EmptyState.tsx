import { Text, View } from 'react-native';
import type { LucideIcon } from 'lucide-react-native';
import { Button } from './Button';
import { palette } from '@/theme/colors';

interface EmptyStateProps {
  icon: LucideIcon;
  title: string;
  body: string;
  actionLabel?: string;
  onAction?: () => void;
  tone?: 'onCanvas' | 'onCard';
}

export function EmptyState({
  icon: Icon,
  title,
  body,
  actionLabel,
  onAction,
  tone = 'onCanvas',
}: EmptyStateProps) {
  const isCanvas = tone === 'onCanvas';

  return (
    <View className="items-center px-6 py-10">
      <View
        className={
          isCanvas
            ? 'h-16 w-16 items-center justify-center rounded-full bg-ink/5'
            : 'h-16 w-16 items-center justify-center rounded-full bg-ink/8'
        }
      >
        <Icon size={26} color={isCanvas ? palette.accent : palette.cardText} strokeWidth={1.9} />
      </View>

      <Text
        className={`mt-5 text-center text-lg font-semibold ${isCanvas ? 'text-ink' : 'text-ink'}`}
      >
        {title}
      </Text>
      <Text
        className={`mt-2 max-w-[300px] text-center text-sm font-sans leading-5 ${
          isCanvas ? 'text-muted' : 'text-ink/60'
        }`}
      >
        {body}
      </Text>

      {actionLabel && onAction && (
        <Button label={actionLabel} onPress={onAction} className="mt-6" />
      )}
    </View>
  );
}
