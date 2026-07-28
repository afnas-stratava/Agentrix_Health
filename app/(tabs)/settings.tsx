import { Alert, Linking, Pressable, ScrollView, Switch, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useQueryClient } from '@tanstack/react-query';
import Constants from 'expo-constants';
import { HeartPulse, ShieldCheck, Trash2 } from 'lucide-react-native';

import { Card } from '@/components/ui/Card';
import { Button } from '@/components/ui/Button';
import { Badge } from '@/components/ui/Badge';
import { RULES } from '@/features/correlation/rules';
import { useRequestHealthAccess } from '@/features/health/queries';
import { isSyntheticTelemetry } from '@/features/health/provider';
import { useHealthStore } from '@/store/health.store';
import { useLabsStore } from '@/store/labs.store';
import { useSettingsStore, type AnalysisWindow } from '@/store/settings.store';
import type { BiologicalSex } from '@/features/labs/reference-ranges';
import { formatRelativeDay, toIsoDay } from '@/lib/date';
import { palette } from '@/theme/colors';

const SEX_OPTIONS: Array<{ value: BiologicalSex; label: string }> = [
  { value: 'female', label: 'Female' },
  { value: 'male', label: 'Male' },
  { value: 'unspecified', label: 'Prefer not to say' },
];

const WINDOWS: AnalysisWindow[] = [30, 60, 90];

function SectionLabel({ children }: { children: string }) {
  return (
    <Text className="mb-3 mt-7 px-6 text-[11px] font-semibold uppercase tracking-wider text-white/50">
      {children}
    </Text>
  );
}

function Segmented<T extends string | number>({
  options,
  value,
  onChange,
}: {
  options: Array<{ value: T; label: string }>;
  value: T;
  onChange: (value: T) => void;
}) {
  return (
    <View className="flex-row gap-2">
      {options.map((option) => {
        const selected = option.value === value;
        return (
          <Pressable
            key={String(option.value)}
            accessibilityRole="radio"
            accessibilityState={{ selected }}
            onPress={() => onChange(option.value)}
            className={`flex-1 items-center rounded-pill px-3 py-2.5 active:opacity-70 ${
              selected ? 'bg-mockup-card-text' : 'bg-mockup-card-text/8'
            }`}
          >
            <Text
              className={`text-[13px] font-semibold ${
                selected ? 'text-white' : 'text-mockup-card-text/60'
              }`}
              numberOfLines={1}
            >
              {option.label}
            </Text>
          </Pressable>
        );
      })}
    </View>
  );
}

export default function SettingsScreen() {
  const queryClient = useQueryClient();

  const sex = useSettingsStore((s) => s.sex);
  const setSex = useSettingsStore((s) => s.setSex);
  const analysisWindowDays = useSettingsStore((s) => s.analysisWindowDays);
  const setAnalysisWindow = useSettingsStore((s) => s.setAnalysisWindow);
  const mutedRuleIds = useSettingsStore((s) => s.mutedRuleIds);
  const toggleRule = useSettingsStore((s) => s.toggleRule);
  const resetSettings = useSettingsStore((s) => s.reset);

  const permission = useHealthStore((s) => s.permission);
  const lastSyncedAt = useHealthStore((s) => s.lastSyncedAt);
  const syncedButEmpty = useHealthStore((s) => s.syncedButEmpty);
  const resetHealth = useHealthStore((s) => s.reset);

  const reportCount = useLabsStore((s) => s.reports.length);
  const resetLabs = useLabsStore((s) => s.reset);

  const requestAccess = useRequestHealthAccess();

  const permissionBadge =
    permission === 'granted'
      ? { label: 'Connected', color: palette.optimal }
      : permission === 'unavailable'
        ? { label: 'Unavailable', color: palette.mutedIcon }
        : permission === 'denied'
          ? { label: 'Denied', color: palette.critical }
          : { label: 'Not connected', color: palette.borderline };

  const confirmErase = () => {
    Alert.alert(
      'Erase all local data?',
      'This deletes every stored lab report, your profile and all cached telemetry from this device. It cannot be undone.',
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Erase',
          style: 'destructive',
          onPress: () => {
            resetLabs();
            resetHealth();
            resetSettings();
            queryClient.clear();
          },
        },
      ],
    );
  };

  return (
    <SafeAreaView className="flex-1 bg-mockup-bg" edges={['top']}>
      <ScrollView showsVerticalScrollIndicator={false} contentContainerStyle={{ paddingBottom: 140 }}>
        <View className="px-6 pt-2">
          <Text className="text-3xl font-bold text-white">Settings</Text>
        </View>

        <SectionLabel>Apple Health</SectionLabel>
        <View className="px-6">
          <Card>
            <View className="flex-row items-center gap-3">
              <View className="h-11 w-11 items-center justify-center rounded-2xl bg-mockup-card-text/8">
                <HeartPulse size={20} color={palette.cardText} strokeWidth={2} />
              </View>
              <View className="flex-1">
                <Text className="text-[15px] font-semibold text-mockup-card-text">
                  HealthKit access
                </Text>
                <Text className="mt-0.5 text-[12px] text-mockup-card-text/50">
                  {lastSyncedAt
                    ? `Last synced ${formatRelativeDay(toIsoDay(new Date(lastSyncedAt))).toLowerCase()}`
                    : 'Never synced'}
                </Text>
              </View>
              <Badge label={permissionBadge.label} color={permissionBadge.color} />
            </View>

            {permission !== 'granted' && permission !== 'unavailable' && (
              <Button
                label="Connect Apple Health"
                onPress={() => requestAccess.mutate()}
                loading={requestAccess.isPending}
                fullWidth
                className="mt-4"
              />
            )}

            {permission === 'denied' && (
              <Button
                label="Open iOS Settings"
                variant="ghost"
                size="sm"
                onPress={() => void Linking.openSettings()}
                className="mt-2 self-center"
              />
            )}

            {syncedButEmpty && permission === 'granted' && (
              <Text className="mt-3 text-[12px] leading-4 text-borderline">
                Connected, but Health returned no samples. iOS does not reveal which read
                permissions were granted — check Settings › Privacy › Health › Vitals and confirm
                each category is on.
              </Text>
            )}

            {isSyntheticTelemetry && (
              <Text className="mt-3 text-[12px] leading-4 text-mockup-card-text/50">
                Running on synthetic telemetry — HealthKit is unavailable on this device or
                simulator.
              </Text>
            )}
          </Card>
        </View>

        <SectionLabel>Reference ranges</SectionLabel>
        <View className="px-6">
          <Card>
            <Text className="text-[13px] leading-[19px] text-mockup-card-text/65">
              Several biomarkers — ferritin, haemoglobin, HDL, testosterone, ALT — have
              sex-specific reference intervals. This only affects how values are flagged.
            </Text>
            <View className="mt-4">
              <Segmented options={SEX_OPTIONS} value={sex} onChange={setSex} />
            </View>
          </Card>
        </View>

        <SectionLabel>Analysis window</SectionLabel>
        <View className="px-6">
          <Card>
            <Text className="text-[13px] leading-[19px] text-mockup-card-text/65">
              How far back correlations look. Longer windows find weaker signals but respond more
              slowly to a change you have just made.
            </Text>
            <View className="mt-4">
              <Segmented
                options={WINDOWS.map((w) => ({ value: w, label: `${w} days` }))}
                value={analysisWindowDays}
                onChange={setAnalysisWindow}
              />
            </View>
          </Card>
        </View>

        <SectionLabel>Which insights you see</SectionLabel>
        <View className="px-6">
          <Card padded={false}>
            {RULES.map((rule, index) => {
              const enabled = !mutedRuleIds.includes(rule.id);
              return (
                <View
                  key={rule.id}
                  className={`flex-row items-center gap-3 px-5 py-3.5 ${
                    index > 0 ? 'border-t border-mockup-card-text/8' : ''
                  }`}
                >
                  <Text className="flex-1 text-[14px] text-mockup-card-text" numberOfLines={2}>
                    {rule.name}
                  </Text>
                  <Switch
                    value={enabled}
                    onValueChange={() => toggleRule(rule.id)}
                    trackColor={{ true: palette.cardText, false: '#D6D8E8' }}
                    thumbColor="#FFFFFF"
                    accessibilityLabel={`${rule.name} insights`}
                  />
                </View>
              );
            })}
          </Card>
        </View>

        <SectionLabel>Your data</SectionLabel>
        <View className="px-6">
          <Card>
            <View className="flex-row items-start gap-3">
              <ShieldCheck size={18} color={palette.optimal} strokeWidth={2.1} />
              <Text className="flex-1 text-[13px] leading-[19px] text-mockup-card-text/65">
                Telemetry never leaves your device. Lab documents are sent to the parsing service
                only when you upload one, and the extracted values are stored locally.
              </Text>
            </View>

            <View className="mt-4 border-t border-mockup-card-text/8 pt-4">
              <Text className="text-[12px] text-mockup-card-text/50">
                {reportCount} lab report{reportCount === 1 ? '' : 's'} stored on this device
              </Text>
              <Button
                label="Erase all local data"
                variant="danger"
                icon={Trash2}
                size="sm"
                onPress={confirmErase}
                className="mt-3 self-start"
              />
            </View>
          </Card>
        </View>

        <Text className="mt-8 text-center text-[11px] text-white/30">
          Vitals {Constants.expoConfig?.version ?? '1.0.0'} · Not a medical device
        </Text>
      </ScrollView>
    </SafeAreaView>
  );
}
