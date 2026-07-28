import { useMemo } from 'react';
import { ScrollView, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useRouter } from 'expo-router';
import { FlaskConical, Plus } from 'lucide-react-native';

import { LabReportCard } from '@/components/labs/LabReportCard';
import { BiomarkerRow } from '@/components/labs/BiomarkerRow';
import { Card } from '@/components/ui/Card';
import { Button } from '@/components/ui/Button';
import { EmptyState } from '@/components/ui/EmptyState';
import { useLabsStore } from '@/store/labs.store';
import { useSettingsStore, selectSex } from '@/store/settings.store';
import { enrichBiomarker, FLAG_SEVERITY, needsAttention } from '@/features/labs/reference-ranges';
import { mergeBiomarkers } from '@/features/correlation/engine';

export default function LabsScreen() {
  const router = useRouter();
  const reports = useLabsStore((s) => s.reports);
  const sex = useSettingsStore(selectSex);

  /**
   * "Needs attention" is computed across the *latest value per biomarker*, not
   * per report — otherwise an old panel keeps flagging a marker the user has
   * since corrected.
   */
  const flagged = useMemo(() => {
    const ready = reports.filter((r) => r.status === 'ready' || r.status === 'needs-review');
    return mergeBiomarkers(ready)
      .map((biomarker) => enrichBiomarker(biomarker, sex))
      .filter((biomarker) => needsAttention(biomarker.flag))
      .sort((a, b) => FLAG_SEVERITY[b.flag] - FLAG_SEVERITY[a.flag]);
  }, [reports, sex]);

  return (
    <SafeAreaView className="flex-1 bg-mockup-bg" edges={['top']}>
      <ScrollView showsVerticalScrollIndicator={false} contentContainerStyle={{ paddingBottom: 140 }}>
        <View className="flex-row items-start justify-between px-6 pt-2">
          <View className="flex-1">
            <Text className="text-3xl font-bold text-white">Labs</Text>
            <Text className="mt-1.5 text-[13px] text-white/55">
              {reports.length === 0
                ? 'Upload a PDF or photo of a blood report'
                : `${reports.length} report${reports.length === 1 ? '' : 's'} on file`}
            </Text>
          </View>

          <Button
            label="Add"
            icon={Plus}
            size="sm"
            onPress={() => router.push('/upload')}
            className="mt-1"
          />
        </View>

        {flagged.length > 0 && (
          <View className="mt-6 px-6">
            <Text className="mb-3 text-[11px] font-semibold uppercase tracking-wider text-white/50">
              Outside your optimal band
            </Text>
            <Card>
              {flagged.map((biomarker, index) => (
                <View
                  key={`${biomarker.code ?? biomarker.rawName}`}
                  className={index > 0 ? 'border-t border-mockup-card-text/8' : ''}
                >
                  <BiomarkerRow biomarker={biomarker} />
                </View>
              ))}
            </Card>
          </View>
        )}

        <View className="mt-6 px-6">
          {reports.length > 0 && (
            <Text className="mb-3 text-[11px] font-semibold uppercase tracking-wider text-white/50">
              All reports
            </Text>
          )}

          {reports.length === 0 ? (
            <EmptyState
              icon={FlaskConical}
              title="No blood work yet"
              body="Add a lab report as a PDF or a photo of the printout. We extract the biomarkers and line them up against your daily telemetry."
              actionLabel="Add your first report"
              onAction={() => router.push('/upload')}
            />
          ) : (
            reports.map((report) => <LabReportCard key={report.id} report={report} />)
          )}
        </View>
      </ScrollView>
    </SafeAreaView>
  );
}
