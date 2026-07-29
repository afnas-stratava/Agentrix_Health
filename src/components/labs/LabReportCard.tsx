import { memo, useMemo } from 'react';
import { ActivityIndicator, Pressable, Text, View } from 'react-native';
import { Link } from 'expo-router';
import { AlertCircle, ChevronRight, FileText, Image as ImageIcon } from 'lucide-react-native';
import type { LabReport } from '@/schemas/labs';
import { needsAttention } from '@/features/labs/reference-ranges';
import { formatDay, formatRelativeDay, toIsoDay } from '@/lib/date';
import { Badge } from '@/components/ui/Badge';
import { palette } from '@/theme/colors';

const STATUS_COPY: Record<LabReport['status'], { label: string; color: string }> = {
  pending: { label: 'Queued', color: palette.mutedIcon },
  uploading: { label: 'Uploading', color: palette.normal },
  parsing: { label: 'Reading report', color: palette.normal },
  'needs-review': { label: 'Needs review', color: palette.borderline },
  ready: { label: 'Parsed', color: palette.optimal },
  failed: { label: 'Failed', color: palette.critical },
};

function LabReportCardBase({ report }: { report: LabReport }) {
  const flagged = useMemo(
    () => report.biomarkers.filter((b) => needsAttention(b.flag)).length,
    [report.biomarkers],
  );

  const status = STATUS_COPY[report.status];
  const isBusy = report.status === 'parsing' || report.status === 'uploading';
  const dateLabel = report.collectedAt
    ? formatDay(toIsoDay(new Date(report.collectedAt)), 'long')
    : `Uploaded ${formatRelativeDay(toIsoDay(new Date(report.uploadedAt)))}`;

  return (
    <Link href={{ pathname: '/lab/[id]', params: { id: report.id } }} asChild>
      <Pressable
        accessibilityRole="button"
        accessibilityLabel={`${report.panelName ?? 'Lab report'}, ${status.label}`}
        className="mb-3 flex-row items-center gap-4 rounded-card bg-surface p-4 active:opacity-80"
      >
        <View className="h-12 w-12 items-center justify-center rounded-2xl bg-ink/8">
          {isBusy ? (
            <ActivityIndicator size="small" color={palette.cardText} />
          ) : report.status === 'failed' ? (
            <AlertCircle size={20} color={palette.critical} strokeWidth={2} />
          ) : report.source === 'pdf' ? (
            <FileText size={20} color={palette.cardText} strokeWidth={2} />
          ) : (
            <ImageIcon size={20} color={palette.cardText} strokeWidth={2} />
          )}
        </View>

        <View className="flex-1">
          <Text className="text-[15px] font-semibold text-ink" numberOfLines={1}>
            {report.panelName ?? report.fileName ?? 'Lab report'}
          </Text>
          <Text className="mt-0.5 text-xs font-sans text-ink/50" numberOfLines={1}>
            {report.labName ? `${report.labName} · ${dateLabel}` : dateLabel}
          </Text>

          <View className="mt-2 flex-row items-center gap-2">
            <Badge label={status.label} color={status.color} />
            {report.status === 'ready' || report.status === 'needs-review' ? (
              <Text className="text-[11px] font-sans text-ink/45">
                {report.biomarkers.length} markers
                {flagged > 0 ? ` · ${flagged} outside optimal` : ''}
              </Text>
            ) : null}
          </View>

          {report.status === 'failed' && report.error && (
            <Text className="mt-1.5 text-[11px] font-sans text-critical" numberOfLines={2}>
              {report.error}
            </Text>
          )}
        </View>

        <ChevronRight size={18} color={palette.mutedIcon} strokeWidth={2} />
      </Pressable>
    </Link>
  );
}

export const LabReportCard = memo(LabReportCardBase);
