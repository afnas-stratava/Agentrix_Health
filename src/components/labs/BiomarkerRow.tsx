import { memo, useMemo } from 'react';
import { Text, View } from 'react-native';
import { AlertTriangle } from 'lucide-react-native';
import type { Biomarker } from '@/schemas/labs';
import { FLAG_COLOR, FLAG_LABEL, palette } from '@/theme/colors';
import { Badge } from '@/components/ui/Badge';

/**
 * Positions a value on its reference interval.
 *
 * The bar is drawn over `low − 20%` … `high + 20%` so an out-of-range value
 * still lands inside the track instead of being clamped to the edge, which
 * would make "slightly high" and "dangerously high" look identical.
 */
function useBarGeometry(biomarker: Biomarker) {
  return useMemo(() => {
    const { low, high, optimalLow, optimalHigh } = biomarker.range;

    const anchorLow = low ?? optimalLow ?? biomarker.value * 0.5;
    const anchorHigh = high ?? optimalHigh ?? biomarker.value * 1.5;
    const spread = anchorHigh - anchorLow || Math.abs(anchorHigh) || 1;

    const domainMin = anchorLow - spread * 0.2;
    const domainMax = anchorHigh + spread * 0.2;
    const domain = domainMax - domainMin || 1;

    const project = (value: number) =>
      Math.min(100, Math.max(0, ((value - domainMin) / domain) * 100));

    const normalStart = project(anchorLow);
    const normalEnd = project(anchorHigh);
    const optimalStart = optimalLow != null ? project(optimalLow) : null;
    const optimalEnd = optimalHigh != null ? project(optimalHigh) : null;

    return {
      valuePct: project(biomarker.value),
      normal: { left: normalStart, width: Math.max(2, normalEnd - normalStart) },
      optimal:
        optimalStart != null || optimalEnd != null
          ? {
              left: optimalStart ?? normalStart,
              width: Math.max(2, (optimalEnd ?? normalEnd) - (optimalStart ?? normalStart)),
            }
          : null,
    };
  }, [biomarker]);
}

function formatRange(biomarker: Biomarker): string {
  const { low, high } = biomarker.range;
  if (low != null && high != null) return `${low}–${high} ${biomarker.unit}`;
  if (high != null) return `< ${high} ${biomarker.unit}`;
  if (low != null) return `> ${low} ${biomarker.unit}`;
  return 'No reference range';
}

function BiomarkerRowBase({ biomarker }: { biomarker: Biomarker }) {
  const geometry = useBarGeometry(biomarker);
  const color = FLAG_COLOR[biomarker.flag];
  const lowConfidence = biomarker.confidence < 0.7;

  return (
    <View className="py-3.5">
      <View className="flex-row items-start justify-between gap-3">
        <View className="flex-1">
          <Text className="text-[15px] font-semibold text-mockup-card-text" numberOfLines={1}>
            {biomarker.displayName}
          </Text>
          <Text className="mt-0.5 text-[11px] text-mockup-card-text/45" numberOfLines={1}>
            {formatRange(biomarker)}
          </Text>
        </View>

        <View className="items-end">
          <View className="flex-row items-baseline gap-1">
            <Text style={{ color }} className="text-lg font-bold">
              {biomarker.value}
            </Text>
            <Text className="text-[11px] text-mockup-card-text/45">{biomarker.unit}</Text>
          </View>
          <Badge label={FLAG_LABEL[biomarker.flag]} color={color} className="mt-1" />
        </View>
      </View>

      {/* Reference-interval track */}
      <View className="mt-3 h-2 w-full overflow-hidden rounded-pill bg-mockup-card-text/8">
        <View
          className="absolute top-0 h-2 rounded-pill bg-normal/25"
          style={{ left: `${geometry.normal.left}%`, width: `${geometry.normal.width}%` }}
        />
        {geometry.optimal && (
          <View
            className="absolute top-0 h-2 rounded-pill bg-optimal/40"
            style={{ left: `${geometry.optimal.left}%`, width: `${geometry.optimal.width}%` }}
          />
        )}
        <View
          style={{
            left: `${geometry.valuePct}%`,
            backgroundColor: color,
            transform: [{ translateX: -5 }],
          }}
          className="absolute -top-0.5 h-3 w-2.5 rounded-full border-2 border-mockup-card-bg"
        />
      </View>

      {lowConfidence && (
        <View className="mt-2 flex-row items-center gap-1.5">
          <AlertTriangle size={12} color={palette.borderline} strokeWidth={2.2} />
          <Text className="text-[11px] text-borderline">
            Extracted at {Math.round(biomarker.confidence * 100)}% confidence — tap the report to
            confirm
          </Text>
        </View>
      )}
    </View>
  );
}

export const BiomarkerRow = memo(BiomarkerRowBase);
