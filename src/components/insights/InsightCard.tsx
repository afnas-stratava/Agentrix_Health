import { memo, useState } from 'react';
import { Linking, Pressable, Text, View } from 'react-native';
import {
  ChevronDown,
  ChevronUp,
  ExternalLink,
  Activity,
  Apple,
  Bed,
  Dumbbell,
  HeartPulse,
  Stethoscope,
  X,
} from 'lucide-react-native';
import type { Insight, InsightDomain } from '@/schemas/insights';
import { BiomarkerFlagSchema, type BiomarkerFlag } from '@/schemas/labs';
import { METRIC_META } from '@/schemas/health';
import { FLAG_COLOR, SEVERITY_COLOR, SEVERITY_LABEL, palette } from '@/theme/colors';
import { Badge } from '@/components/ui/Badge';
import { SuggestionRow } from './SuggestionRow';

const DOMAIN_ICON: Record<InsightDomain, typeof Activity> = {
  nutrition: Apple,
  training: Dumbbell,
  sleep: Bed,
  recovery: HeartPulse,
  stress: Activity,
  'medical-referral': Stethoscope,
};

interface InsightCardProps {
  insight: Insight;
  onDismiss?: (id: string) => void;
  /** Expanded by default in the detail modal, collapsed in feeds. */
  defaultExpanded?: boolean;
}

/**
 * Evidence flags cross the schema boundary as plain strings (the evidence block
 * is deliberately loose so a future server-authored insight can carry a flag
 * this build has never heard of). Narrow it here rather than casting.
 */
function toFlag(value: string): BiomarkerFlag {
  const parsed = BiomarkerFlagSchema.safeParse(value);
  return parsed.success ? parsed.data : 'unknown';
}

function describeCorrelation(r: number, n: number, metricLabel: string, lagDays: number): string {
  const direction = r > 0 ? 'rises and falls with' : 'moves inversely to';
  const lag = lagDays > 0 ? ` (${lagDays}-day lag)` : '';
  return `${metricLabel} ${direction} this pattern across ${n} days${lag} · r = ${r}`;
}

function InsightCardBase({ insight, onDismiss, defaultExpanded = false }: InsightCardProps) {
  const [expanded, setExpanded] = useState(defaultExpanded);
  const Icon = DOMAIN_ICON[insight.domain];
  const severityColor = SEVERITY_COLOR[insight.severity];

  return (
    <View className="mb-3 overflow-hidden rounded-card bg-surface">
      {/* Severity rail — a colour cue that survives greyscale accessibility modes
          because it is paired with the text badge below. */}
      <View style={{ backgroundColor: severityColor }} className="h-1 w-full" />

      <View className="p-5">
        <View className="flex-row items-start gap-3">
          <View className="h-10 w-10 items-center justify-center rounded-2xl bg-ink/8">
            <Icon size={19} color={palette.cardText} strokeWidth={2} />
          </View>

          <View className="flex-1">
            <Badge label={SEVERITY_LABEL[insight.severity]} color={severityColor} />
            <Text className="mt-2 text-[17px] font-bold leading-6 text-ink">
              {insight.title}
            </Text>
          </View>

          {onDismiss && (
            <Pressable
              accessibilityRole="button"
              accessibilityLabel="Dismiss insight"
              hitSlop={10}
              onPress={() => onDismiss(insight.id)}
              className="h-7 w-7 items-center justify-center rounded-full bg-ink/8 active:opacity-60"
            >
              <X size={13} color={palette.cardText} strokeWidth={2.4} />
            </Pressable>
          )}
        </View>

        <Text className="mt-3 text-sm font-sans leading-[21px] text-ink/70">
          {insight.summary}
        </Text>

        {/* Evidence chips: the biomarkers that fired the rule. */}
        {insight.evidence.biomarkers.length > 0 && (
          <View className="mt-4 flex-row flex-wrap gap-2">
            {insight.evidence.biomarkers.map((biomarker) => {
              const color = FLAG_COLOR[toFlag(biomarker.flag)];
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

        {insight.evidence.telemetryNote && (
          <View className="mt-3 flex-row items-center gap-2 rounded-xl bg-ink/5 px-3 py-2.5">
            <Activity size={14} color={palette.mutedIcon} strokeWidth={2.2} />
            <Text className="flex-1 text-[12px] font-sans leading-4 text-ink/60">
              {insight.evidence.telemetryNote}
            </Text>
          </View>
        )}

        <Pressable
          accessibilityRole="button"
          accessibilityLabel={expanded ? 'Hide details' : 'Show what to do'}
          onPress={() => setExpanded((v) => !v)}
          className="mt-4 flex-row items-center gap-1.5 active:opacity-60"
        >
          <Text className="text-[13px] font-semibold text-ink">
            {expanded ? 'Hide details' : `What to do (${insight.suggestions.length})`}
          </Text>
          {expanded ? (
            <ChevronUp size={15} color={palette.cardText} strokeWidth={2.4} />
          ) : (
            <ChevronDown size={15} color={palette.cardText} strokeWidth={2.4} />
          )}
        </Pressable>

        {expanded && (
          <View className="mt-3 border-t border-ink/10 pt-1">
            {insight.suggestions.map((suggestion) => (
              <SuggestionRow key={suggestion.id} suggestion={suggestion} />
            ))}

            {insight.evidence.correlations.length > 0 && (
              <View className="mt-3 rounded-xl bg-ink/5 p-3">
                <Text className="text-[11px] font-semibold uppercase tracking-wider text-ink/45">
                  Found in your own data
                </Text>
                {insight.evidence.correlations.map((correlation) => (
                  <Text
                    key={`${correlation.metric}-${correlation.lagDays}`}
                    className="mt-1.5 text-[12px] font-sans leading-4 text-ink/65"
                  >
                    {describeCorrelation(
                      correlation.r,
                      correlation.n,
                      METRIC_META[correlation.metric].label,
                      correlation.lagDays,
                    )}
                  </Text>
                ))}
              </View>
            )}

            {insight.evidence.citations.length > 0 && (
              <View className="mt-3">
                {insight.evidence.citations.map((citation) => (
                  <Pressable
                    key={citation.url}
                    accessibilityRole="link"
                    onPress={() => void Linking.openURL(citation.url)}
                    className="mt-1.5 flex-row items-center gap-1.5 active:opacity-60"
                  >
                    <ExternalLink size={12} color={palette.mutedIcon} strokeWidth={2.2} />
                    <Text className="text-[11px] font-sans text-ink/50 underline">
                      {citation.label}
                    </Text>
                  </Pressable>
                ))}
              </View>
            )}
          </View>
        )}
      </View>
    </View>
  );
}

export const InsightCard = memo(InsightCardBase);
