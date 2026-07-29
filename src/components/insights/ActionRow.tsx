import { memo } from 'react';
import { Pressable, Text, View } from 'react-native';
import { Activity, Apple, Bed, Dumbbell, HeartPulse, Stethoscope } from 'lucide-react-native';
import type { Insight, InsightDomain, Suggestion } from '@/schemas/insights';
import { palette } from '@/theme/colors';

const DOMAIN_ICON: Record<InsightDomain, typeof Activity> = {
  nutrition: Apple,
  training: Dumbbell,
  sleep: Bed,
  recovery: HeartPulse,
  stress: Activity,
  'medical-referral': Stethoscope,
};

const EFFORT_LABEL: Record<Suggestion['effort'], string> = {
  low: 'Easy',
  medium: 'Steady',
  high: 'Committed',
};

const EFFORT_COLOR: Record<Suggestion['effort'], string> = {
  low: palette.optimal,
  medium: palette.borderline,
  high: palette.abnormal,
};

function horizonLabel(days: number): string {
  if (days <= 14) return `${days}d`;
  if (days <= 60) return `${Math.round(days / 7)}w`;
  return `${Math.round(days / 30)}mo`;
}

interface ActionRowProps {
  suggestion: Suggestion;
  source: Insight;
  onPress: () => void;
  isLast?: boolean;
}

/**
 * A single recommended action, sized for scanning in a vertical list rather
 * than a carousel: the title, one line of specifics, and the two facts that
 * decide whether someone will actually do it — how hard it is, and how long
 * before it shows up in their data.
 */
function ActionRowBase({ suggestion, source, onPress, isLast = false }: ActionRowProps) {
  const Icon = DOMAIN_ICON[suggestion.domain];

  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={suggestion.title}
      accessibilityHint={`${EFFORT_LABEL[suggestion.effort]} effort. From: ${source.title}`}
      onPress={onPress}
      className={`flex-row items-start gap-3.5 px-5 py-4 active:opacity-70 ${
        isLast ? '' : 'border-b border-ink/8'
      }`}
    >
      {/* Brand-tinted, matching the icon chips on the stat tiles — a second
          neutral grey chip on the same screen read as a disabled control. */}
      <View className="mt-0.5 h-9 w-9 items-center justify-center rounded-xl bg-brand-50">
        <Icon size={17} color={palette.brand} strokeWidth={2.1} />
      </View>

      <View className="flex-1">
        <Text className="text-[14px] font-semibold leading-[19px] text-ink">
          {suggestion.title}
        </Text>
        <Text className="mt-0.5 text-[12px] font-sans leading-[17px] text-ink/60" numberOfLines={2}>
          {suggestion.detail}
        </Text>

        <View className="mt-2 flex-row items-center gap-2">
          <View
            style={{ backgroundColor: `${EFFORT_COLOR[suggestion.effort]}1A` }}
            className="rounded-pill px-2 py-0.5"
          >
            <Text
              style={{ color: EFFORT_COLOR[suggestion.effort] }}
              className="text-[10px] font-bold uppercase tracking-wide"
            >
              {EFFORT_LABEL[suggestion.effort]}
            </Text>
          </View>
          <Text className="text-[10px] font-sans text-ink/40">
            signal in ~{horizonLabel(suggestion.horizonDays)}
          </Text>
        </View>
      </View>
    </Pressable>
  );
}

export const ActionRow = memo(ActionRowBase);
