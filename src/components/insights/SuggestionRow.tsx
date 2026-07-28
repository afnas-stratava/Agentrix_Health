import { memo } from 'react';
import { Text, View } from 'react-native';
import { Clock, Gauge } from 'lucide-react-native';
import type { Suggestion } from '@/schemas/insights';
import { palette } from '@/theme/colors';

const EFFORT_LABEL: Record<Suggestion['effort'], string> = {
  low: 'Easy',
  medium: 'Moderate',
  high: 'Committed',
};

const EFFORT_COLOR: Record<Suggestion['effort'], string> = {
  low: palette.optimal,
  medium: palette.borderline,
  high: palette.abnormal,
};

function horizonLabel(days: number): string {
  if (days <= 14) return `${days} days`;
  if (days <= 60) return `${Math.round(days / 7)} weeks`;
  return `${Math.round(days / 30)} months`;
}

function SuggestionRowBase({ suggestion }: { suggestion: Suggestion }) {
  return (
    <View className="border-b border-mockup-card-text/8 py-3.5 last:border-b-0">
      <Text className="text-[14px] font-semibold text-mockup-card-text">{suggestion.title}</Text>
      <Text className="mt-1 text-[13px] leading-[19px] text-mockup-card-text/65">
        {suggestion.detail}
      </Text>

      <View className="mt-2.5 flex-row items-center gap-4">
        <View className="flex-row items-center gap-1.5">
          <Gauge size={12} color={EFFORT_COLOR[suggestion.effort]} strokeWidth={2.2} />
          <Text style={{ color: EFFORT_COLOR[suggestion.effort] }} className="text-[11px] font-semibold">
            {EFFORT_LABEL[suggestion.effort]}
          </Text>
        </View>

        <View className="flex-row items-center gap-1.5">
          <Clock size={12} color={palette.mutedIcon} strokeWidth={2.2} />
          <Text className="text-[11px] text-mockup-card-text/50">
            Signal in ~{horizonLabel(suggestion.horizonDays)}
          </Text>
        </View>
      </View>
    </View>
  );
}

export const SuggestionRow = memo(SuggestionRowBase);
