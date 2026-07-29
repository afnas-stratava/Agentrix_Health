import { useMemo } from 'react';
import { Alert, SectionList, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Redirect, useLocalSearchParams, useRouter } from 'expo-router';
import { Trash2, X } from 'lucide-react-native';

import type { Biomarker, BiomarkerCategory } from '@/schemas/labs';
import { BiomarkerRow } from '@/components/labs/BiomarkerRow';
import { Card } from '@/components/ui/Card';
import { Badge } from '@/components/ui/Badge';
import { Button, IconButton } from '@/components/ui/Button';
import { useLabsStore } from '@/store/labs.store';
import { useSettingsStore, selectSex } from '@/store/settings.store';
import { useDeleteLabReport } from '@/features/labs/queries';
import { enrichBiomarker, FLAG_SEVERITY, needsAttention } from '@/features/labs/reference-ranges';
import { formatDay, toIsoDay } from '@/lib/date';
import { palette } from '@/theme/colors';

const CATEGORY_LABEL: Record<BiomarkerCategory, string> = {
  iron: 'Iron & oxygen transport',
  inflammation: 'Inflammation',
  glycemic: 'Blood sugar',
  lipids: 'Lipids',
  thyroid: 'Thyroid',
  micronutrient: 'Micronutrients',
  organ: 'Liver & kidney',
  endocrine: 'Hormones',
  hematology: 'Blood count',
  other: 'Other markers',
};

// Ordered so the panels people act on most sit at the top.
const CATEGORY_ORDER: BiomarkerCategory[] = [
  'iron',
  'inflammation',
  'glycemic',
  'lipids',
  'thyroid',
  'micronutrient',
  'endocrine',
  'organ',
  'hematology',
  'other',
];

export default function LabDetail() {
  const router = useRouter();
  const { id } = useLocalSearchParams<{ id: string }>();
  const sex = useSettingsStore(selectSex);
  const report = useLabsStore((s) => s.reports.find((r) => r.id === id) ?? null);
  const deleteReport = useDeleteLabReport();

  const sections = useMemo(() => {
    if (!report) return [];

    const enriched = report.biomarkers.map((b) => enrichBiomarker(b, sex));
    const grouped = new Map<BiomarkerCategory, Biomarker[]>();

    for (const biomarker of enriched) {
      const bucket = grouped.get(biomarker.category);
      if (bucket) bucket.push(biomarker);
      else grouped.set(biomarker.category, [biomarker]);
    }

    return CATEGORY_ORDER.filter((category) => grouped.has(category)).map((category) => ({
      title: CATEGORY_LABEL[category],
      data: (grouped.get(category) ?? []).sort(
        (a, b) => FLAG_SEVERITY[b.flag] - FLAG_SEVERITY[a.flag],
      ),
    }));
  }, [report, sex]);

  const flaggedCount = useMemo(
    () =>
      report ? report.biomarkers.map((b) => enrichBiomarker(b, sex)).filter((b) => needsAttention(b.flag)).length : 0,
    [report, sex],
  );

  // The report can vanish underneath this screen if it is deleted from the
  // Labs tab while the modal is open.
  if (!report) return <Redirect href="/(tabs)/labs" />;

  const confirmDelete = () => {
    Alert.alert('Delete this report?', 'The extracted values and the stored file are removed from this device.', [
      { text: 'Cancel', style: 'cancel' },
      {
        text: 'Delete',
        style: 'destructive',
        onPress: () => {
          deleteReport(report.id);
          router.back();
        },
      },
    ]);
  };

  return (
    <SafeAreaView className="flex-1 bg-canvas">
      <SectionList
        sections={sections}
        keyExtractor={(item, index) => `${item.code ?? item.rawName}-${index}`}
        contentContainerStyle={{ padding: 24, paddingBottom: 48 }}
        stickySectionHeadersEnabled={false}
        showsVerticalScrollIndicator={false}
        ListHeaderComponent={
          <View className="mb-6">
            <View className="flex-row items-start justify-between">
              <View className="flex-1 pr-4">
                <Text className="text-[24px] font-bold leading-7 text-ink">
                  {report.panelName ?? report.fileName ?? 'Lab report'}
                </Text>
                <Text className="mt-1.5 text-[13px] font-sans text-muted">
                  {report.labName ? `${report.labName} · ` : ''}
                  {report.collectedAt
                    ? `Collected ${formatDay(toIsoDay(new Date(report.collectedAt)), 'long')}`
                    : `Uploaded ${formatDay(toIsoDay(new Date(report.uploadedAt)), 'long')}`}
                </Text>
              </View>
              <IconButton icon={X} label="Close" tone="onCanvas" onPress={() => router.back()} />
            </View>

            <View className="mt-4 flex-row flex-wrap gap-2">
              <Badge
                label={`${report.biomarkers.length} markers`}
                color={palette.mutedIcon}
                size="md"
              />
              {flaggedCount > 0 && (
                <Badge
                  label={`${flaggedCount} outside optimal`}
                  color={palette.borderline}
                  size="md"
                />
              )}
              {report.status === 'needs-review' && (
                <Badge label="Needs review" color={palette.borderline} size="md" />
              )}
            </View>

            {report.status === 'needs-review' && (
              <Card className="mt-4" tone="translucent">
                <Text className="text-[13px] font-sans leading-[19px] text-muted">
                  Some values were extracted with low confidence. Check anything marked below
                  against the original document before acting on it — a mis-read decimal point is
                  the difference between normal and critical.
                </Text>
              </Card>
            )}
          </View>
        }
        renderSectionHeader={({ section }) => (
          <Text className="mb-2 mt-4 text-[11px] font-semibold uppercase tracking-wider text-muted">
            {section.title}
          </Text>
        )}
        renderItem={({ item, index, section }) => (
          <View
            className={`bg-surface px-5 ${
              index === 0 ? 'rounded-t-card pt-1' : 'border-t border-ink/8'
            } ${index === section.data.length - 1 ? 'rounded-b-card pb-1' : ''}`}
          >
            <BiomarkerRow biomarker={item} />
          </View>
        )}
        ListFooterComponent={
          <View className="mt-8">
            <Button
              label="Delete report"
              variant="danger"
              icon={Trash2}
              onPress={confirmDelete}
              className="self-center"
            />
            <Text className="mt-5 text-center text-[11px] font-sans leading-4 text-faint/80">
              Reference intervals shown are the lab&apos;s own where printed, with an
              evidence-based optimal band layered on top. Neither replaces clinical interpretation.
            </Text>
          </View>
        }
      />
    </SafeAreaView>
  );
}
