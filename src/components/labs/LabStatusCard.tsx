import { memo } from 'react';
import { StyleSheet, Text, View } from 'react-native';
import { ChevronRight, FlaskConical, Plus } from 'lucide-react-native';
import type { LabReport } from '@/schemas/labs';
import { daysBetween, formatDay, toIsoDay } from '@/lib/date';
import { PressableScale } from '@/components/ui/PressableScale';
import { palette } from '@/theme/colors';

/** Beyond this, biomarkers are old enough that the engine heavily discounts them. */
const STALE_AFTER_DAYS = 180;

interface LabStatusCardProps {
  report: LabReport | null;
  flaggedCount: number;
  onPress: () => void;
}

function ageLabel(days: number): string {
  if (days === 0) return 'Collected today';
  if (days === 1) return 'Collected yesterday';
  if (days < 60) return `${days} days ago`;
  if (days < 365) return `${Math.round(days / 30)} months ago`;
  return `${(days / 365).toFixed(1)} years ago`;
}

/**
 * Closes the loop on the dashboard: telemetry updates itself every day, but
 * lab data only changes when the user acts. This is the prompt that keeps the
 * correlation half of the product alive.
 */
function LabStatusCardBase({ report, flaggedCount, onPress }: LabStatusCardProps) {
  if (!report) {
    return (
      <PressableScale
        accessibilityRole="button"
        accessibilityLabel="Find your blood work"
        accessibilityHint="Connects Gmail to import lab reports from your inbox"
        onPress={onPress}
        className="flex-row items-center gap-3.5 rounded-card border border-dashed border-brand-200 bg-surface p-4"
      >
        <View className="h-11 w-11 items-center justify-center rounded-2xl bg-accent-soft">
          <Plus size={20} color={palette.brand} strokeWidth={2.4} />
        </View>
        <View className="flex-1">
          <Text className="text-[14px] font-semibold text-ink">Find your blood work</Text>
          <Text className="mt-0.5 text-[12px] font-sans leading-4 text-muted">
            Connect Gmail and we will pull your lab reports out of your inbox automatically.
          </Text>
        </View>
        <ChevronRight size={17} color={palette.faint} strokeWidth={2.2} />
      </PressableScale>
    );
  }

  const anchor = report.collectedAt ?? report.uploadedAt;
  const ageDays = Math.max(0, daysBetween(new Date(anchor), new Date()));
  const isStale = ageDays > STALE_AFTER_DAYS;
  const accentColor = isStale ? palette.borderline : palette.brand;

  return (
    <PressableScale
      accessibilityRole="button"
      accessibilityLabel={`Lab report from ${formatDay(toIsoDay(new Date(anchor)), 'long')}`}
      accessibilityHint="Opens the full report"
      onPress={onPress}
      className="rounded-card border border-hairline bg-surface p-4"
      style={styles.elevated}
    >
      <View className="flex-row items-center gap-3.5">
        <View
          style={{ backgroundColor: `${accentColor}1A` }}
          className="h-11 w-11 items-center justify-center rounded-2xl"
        >
          <FlaskConical size={19} color={accentColor} strokeWidth={2.1} />
        </View>

        <View className="flex-1">
          <Text className="text-[14px] font-semibold text-ink" numberOfLines={1}>
            {report.panelName ?? 'Blood report'}
          </Text>
          <Text className="mt-0.5 text-[12px] font-sans text-muted" numberOfLines={1}>
            {ageLabel(ageDays)} · {report.biomarkers.length} markers
          </Text>
        </View>

        {/* Off-target count earns its own pill: it is the one number here that
            decides whether the report is worth reopening. */}
        {flaggedCount > 0 && (
          <View
            style={{ backgroundColor: `${palette.abnormal}1A` }}
            className="rounded-pill px-2.5 py-1"
          >
            <Text style={{ color: palette.abnormal }} className="text-[11px] font-bold">
              {flaggedCount} off
            </Text>
          </View>
        )}

        <ChevronRight size={17} color={palette.faint} strokeWidth={2.2} />
      </View>

      {isStale && (
        <View className="mt-3 flex-row items-center gap-2 rounded-xl bg-borderline/12 px-3 py-2">
          <Text className="flex-1 text-[11px] font-sans leading-4 text-ink/70">
            Older than 6 months — findings from it are heavily discounted.
          </Text>
        </View>
      )}
    </PressableScale>
  );
}

const styles = StyleSheet.create({
  // Matches `Card`'s lift so this sits in the same plane as the rest of the feed.
  elevated: {
    shadowColor: palette.brandDeep,
    shadowOffset: { width: 0, height: 6 },
    shadowOpacity: 0.06,
    shadowRadius: 16,
    elevation: 2,
  },
});

export const LabStatusCard = memo(LabStatusCardBase);
