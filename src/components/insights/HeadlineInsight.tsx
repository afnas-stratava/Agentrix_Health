import { memo } from 'react';
import { Text, View } from 'react-native';
import { Activity, ArrowRight, Sparkles } from 'lucide-react-native';
import type { Insight } from '@/schemas/insights';
import { BiomarkerFlagSchema } from '@/schemas/labs';
import { PressableScale } from '@/components/ui/PressableScale';
import { FLAG_COLOR, SEVERITY_COLOR, SEVERITY_LABEL, palette } from '@/theme/colors';

/**
 * The single most important finding, given the most prominent slot on the
 * dashboard after readiness.
 *
 * It leads with the *evidence* — the biomarker value and the telemetry drift
 * side by side — because that pairing is the only thing here that neither
 * Apple Health nor a lab portal can show you on its own.
 */
interface HeadlineInsightProps {
  insight: Insight;
  onPress: () => void;
}

function HeadlineInsightBase({ insight, onPress }: HeadlineInsightProps) {
  const severityColor = SEVERITY_COLOR[insight.severity];

  return (
    <PressableScale
      accessibilityRole="button"
      accessibilityLabel={`${SEVERITY_LABEL[insight.severity]}: ${insight.title}`}
      accessibilityHint="Opens the full finding and what to do about it"
      onPress={onPress}
      className="overflow-hidden rounded-card border border-hairline bg-surface"
    >
      {/* Severity is carried by both the rail and the text badge, so the cue
          survives greyscale and colour-blind viewing. */}
      <View style={{ backgroundColor: severityColor }} className="h-1 w-full" />

      <View className="p-5">
        <View className="flex-row items-center gap-2">
          <View
            style={{ backgroundColor: `${severityColor}1F`, borderColor: `${severityColor}55` }}
            className="flex-row items-center gap-1.5 self-start rounded-pill border px-2.5 py-1"
          >
            <Sparkles size={11} color={severityColor} strokeWidth={2.4} />
            <Text style={{ color: severityColor }} className="text-[10px] font-bold uppercase tracking-wider">
              {SEVERITY_LABEL[insight.severity]}
            </Text>
          </View>
        </View>

        <Text className="mt-2.5 text-[18px] font-bold leading-[24px] text-ink">
          {insight.title}
        </Text>

        <Text className="mt-2 text-[13px] font-sans leading-[19px] text-ink/65" numberOfLines={3}>
          {insight.summary}
        </Text>

        {/* Evidence: lab side */}
        {insight.evidence.biomarkers.length > 0 && (
          <View className="mt-3.5 flex-row flex-wrap gap-1.5">
            {insight.evidence.biomarkers.slice(0, 3).map((biomarker) => {
              const parsed = BiomarkerFlagSchema.safeParse(biomarker.flag);
              const color = FLAG_COLOR[parsed.success ? parsed.data : 'unknown'];
              return (
                <View
                  key={biomarker.code}
                  style={{ borderColor: `${color}55` }}
                  className="flex-row items-center gap-1.5 rounded-pill border bg-white px-2.5 py-1"
                >
                  <Text className="text-[11px] font-medium text-ink/60">
                    {biomarker.displayName}
                  </Text>
                  <Text style={{ color }} className="text-[11px] font-bold">
                    {biomarker.value} {biomarker.unit}
                  </Text>
                </View>
              );
            })}
          </View>
        )}

        {/* Evidence: telemetry side */}
        {insight.evidence.telemetryNote && (
          <View className="mt-2 flex-row items-center gap-2 rounded-xl bg-ink/5 px-3 py-2">
            <Activity size={13} color={palette.faint} strokeWidth={2.2} />
            <Text className="flex-1 text-[11px] font-sans leading-4 text-ink/60" numberOfLines={2}>
              {insight.evidence.telemetryNote}
            </Text>
          </View>
        )}

        <View className="mt-4 flex-row items-center gap-1.5">
          <Text className="text-[13px] font-semibold text-ink">
            See what to do ({insight.suggestions.length})
          </Text>
          <ArrowRight size={14} color={palette.ink} strokeWidth={2.4} />
        </View>
      </View>
    </PressableScale>
  );
}

export const HeadlineInsight = memo(HeadlineInsightBase);
