import { Alert, Linking, Pressable, ScrollView, Switch, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useQueryClient } from '@tanstack/react-query';
import Constants from 'expo-constants';
import { useRouter } from 'expo-router';
import { ChevronRight, FlaskConical, HeartPulse, Mail, ShieldCheck, Trash2, User } from 'lucide-react-native';

import { Card } from '@/components/ui/Card';
import { Button } from '@/components/ui/Button';
import { Badge } from '@/components/ui/Badge';
import { RULES } from '@/features/correlation/rules';
import { useRequestHealthAccess } from '@/features/health/queries';
import { isSyntheticTelemetry } from '@/features/health/provider';
import { useHealthStore } from '@/store/health.store';
import { useLabsStore } from '@/store/labs.store';
import { useSettingsStore, type AnalysisWindow } from '@/store/settings.store';
import { useConnectionsStore } from '@/store/connections.store';
import {
  useConnectGmail,
  useDisconnectGmail,
  useGmailConnection,
} from '@/features/labs/gmail/queries';
import { GmailAuthCancelled } from '@/features/labs/gmail/auth';
import type { BiologicalSex } from '@/features/labs/reference-ranges';
import { useProfile } from '@/features/profile/use-profile';
import { useProfileStore } from '@/store/profile.store';
import { useNutritionStore } from '@/store/nutrition.store';
import { applyDemoPersona, clearDemoPersona } from '@/features/demo/persona';
import { CUISINE_LABEL, DIET_PATTERN_META, HEALTH_GOAL_META } from '@/schemas/profile';
import { PressableScale } from '@/components/ui/PressableScale';
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
    <Text className="mb-3 mt-7 px-6 text-[11px] font-semibold uppercase tracking-wider text-muted">
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
              selected ? 'bg-accent' : 'bg-ink/5'
            }`}
          >
            <Text
              className={`text-[13px] font-semibold ${
                selected ? 'text-ink' : 'text-muted'
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
  const router = useRouter();

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

  const profile = useProfile();
  const resetProfile = useProfileStore((s) => s.reset);
  const clearNutrition = useNutritionStore((s) => s.clear);
  const mealCount = useNutritionStore((s) => s.meals.length);

  // Derived rather than stored: the seeded report either exists or it does not,
  // and a separate "demo mode" flag could disagree with reality.
  const demoActive = useLabsStore((s) => s.reports.some((r) => r.id === 'demo-report-1'));

  const requestAccess = useRequestHealthAccess();

  const { data: gmail } = useGmailConnection();
  const connectGmail = useConnectGmail();
  const disconnectGmail = useDisconnectGmail();
  const resetConnections = useConnectionsStore((s) => s.reset);
  const importedCount = useConnectionsStore((s) => s.importedAttachmentIds.length);

  const isGmailConnected = gmail?.status === 'connected';

  const handleConnectGmail = async () => {
    try {
      await connectGmail.mutateAsync();
      router.push('/gmail-import');
    } catch (error) {
      if (error instanceof GmailAuthCancelled) return;
      Alert.alert(
        'Could not connect Gmail',
        error instanceof Error ? error.message : 'Please try again.',
      );
    }
  };

  const confirmDisconnectGmail = () => {
    Alert.alert(
      'Disconnect Gmail?',
      'We will revoke our access to your mailbox. Reports you have already imported stay in your library.',
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Disconnect',
          style: 'destructive',
          onPress: () => disconnectGmail.mutate(),
        },
      ],
    );
  };

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
            resetConnections();
            resetProfile();
            clearNutrition();
            queryClient.clear();
          },
        },
      ],
    );
  };

  return (
    <SafeAreaView className="flex-1 bg-canvas" edges={['top']}>
      <ScrollView showsVerticalScrollIndicator={false} contentContainerStyle={{ paddingBottom: 140 }}>
        <View className="px-6 pt-2">
          <Text className="text-3xl font-bold text-ink">Settings</Text>
        </View>

        <SectionLabel>Your profile</SectionLabel>
        <View className="px-6">
          <Card padded={false}>
            <PressableScale
              scaleTo={0.99}
              accessibilityRole="button"
              accessibilityLabel="Edit your profile"
              onPress={() => router.push('/profile')}
              className="flex-row items-center gap-3 px-5 py-4"
            >
              <View className="h-11 w-11 items-center justify-center rounded-2xl bg-brand-50">
                <User size={20} color={palette.brand} strokeWidth={2} />
              </View>
              <View className="flex-1">
                <Text className="text-[15px] font-semibold text-ink">
                  {profile.displayName ?? 'Goal, diet and body'}
                </Text>
                <Text className="mt-0.5 text-[12px] font-sans text-ink/50" numberOfLines={1}>
                  {HEALTH_GOAL_META[profile.goal].label} ·{' '}
                  {DIET_PATTERN_META[profile.dietPattern].label}
                  {profile.weightKg != null ? ` · ${profile.weightKg} kg` : ''}
                </Text>
              </View>
              <ChevronRight size={17} color={palette.faint} strokeWidth={2.3} />
            </PressableScale>

            {profile.cuisines.length > 0 && (
              <View className="border-t border-ink/8 px-5 py-3">
                <Text className="text-[12px] font-sans text-ink/50">
                  Cuisines: {profile.cuisines.map((c) => CUISINE_LABEL[c]).join(', ')}
                </Text>
              </View>
            )}

            {(profile.heightCm == null || profile.weightKg == null || profile.birthYear == null) && (
              <View className="border-t border-ink/8 px-5 py-3">
                <Text className="text-[12px] font-sans leading-[17px] text-borderline">
                  Height, weight and age are missing — calorie and macro targets stay switched off
                  until they are set.
                </Text>
              </View>
            )}
          </Card>
        </View>

        <SectionLabel>Apple Health</SectionLabel>
        <View className="px-6">
          <Card>
            <View className="flex-row items-center gap-3">
              <View className="h-11 w-11 items-center justify-center rounded-2xl bg-ink/8">
                <HeartPulse size={20} color={palette.cardText} strokeWidth={2} />
              </View>
              <View className="flex-1">
                <Text className="text-[15px] font-semibold text-ink">
                  HealthKit access
                </Text>
                <Text className="mt-0.5 text-[12px] font-sans text-ink/50">
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
              <Text className="mt-3 text-[12px] font-sans leading-4 text-borderline">
                Connected, but Health returned no samples. iOS does not reveal which read
                permissions were granted — check Settings › Privacy › Health › Vitals and confirm
                each category is on.
              </Text>
            )}

            {isSyntheticTelemetry && (
              <Text className="mt-3 text-[12px] font-sans leading-4 text-ink/50">
                Running on synthetic telemetry — HealthKit is unavailable on this device or
                simulator.
              </Text>
            )}
          </Card>
        </View>

        <SectionLabel>Gmail import</SectionLabel>
        <View className="px-6">
          <Card>
            <View className="flex-row items-center gap-3">
              <View className="h-11 w-11 items-center justify-center rounded-2xl bg-ink/8">
                <Mail size={20} color={palette.cardText} strokeWidth={2} />
              </View>
              <View className="flex-1">
                <Text className="text-[15px] font-semibold text-ink">
                  Mailbox access
                </Text>
                <Text className="mt-0.5 text-[12px] font-sans text-ink/50" numberOfLines={1}>
                  {isGmailConnected ? gmail.emailAddress : 'Not connected'}
                </Text>
              </View>
              <Badge
                label={isGmailConnected ? 'Connected' : 'Off'}
                color={isGmailConnected ? palette.optimal : palette.mutedIcon}
              />
            </View>

            <Text className="mt-3 text-[12px] font-sans leading-[17px] text-ink/60">
              Read-only access, used to find lab reports from known diagnostics providers. We only
              open the attachments you explicitly select, and no Google token is ever stored on
              this device.
            </Text>

            {isGmailConnected ? (
              <View className="mt-4 border-t border-ink/8 pt-4">
                <Text className="text-[12px] font-sans text-ink/50">
                  {importedCount} report{importedCount === 1 ? '' : 's'} imported from this mailbox
                </Text>
                <View className="mt-3 flex-row gap-2">
                  <Button
                    label="Scan inbox"
                    size="sm"
                    onPress={() => router.push('/gmail-import')}
                  />
                  <Button
                    label="Disconnect"
                    variant="danger"
                    size="sm"
                    loading={disconnectGmail.isPending}
                    onPress={confirmDisconnectGmail}
                  />
                </View>
              </View>
            ) : (
              <Button
                label="Connect Gmail"
                icon={Mail}
                fullWidth
                loading={connectGmail.isPending}
                onPress={() => void handleConnectGmail()}
                className="mt-4"
              />
            )}
          </Card>
        </View>

        <SectionLabel>Reference ranges</SectionLabel>
        <View className="px-6">
          <Card>
            <Text className="text-[13px] font-sans leading-[19px] text-ink/65">
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
            <Text className="text-[13px] font-sans leading-[19px] text-ink/65">
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
                    index > 0 ? 'border-t border-ink/8' : ''
                  }`}
                >
                  <Text className="flex-1 text-[14px] font-sans text-ink" numberOfLines={2}>
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

        <SectionLabel>Demo data</SectionLabel>
        <View className="px-6">
          <Card>
            <View className="flex-row items-center gap-3">
              <View className="h-11 w-11 items-center justify-center rounded-2xl bg-ink/8">
                <FlaskConical size={20} color={palette.cardText} strokeWidth={2} />
              </View>
              <View className="flex-1">
                <Text className="text-[15px] font-semibold text-ink">Demo persona</Text>
                <Text className="mt-0.5 text-[12px] font-sans text-ink/50">
                  {demoActive ? 'Active' : 'Off'} · {mealCount} meal
                  {mealCount === 1 ? '' : 's'} logged
                </Text>
              </View>
              <Badge
                label={demoActive ? 'On' : 'Off'}
                color={demoActive ? palette.borderline : palette.mutedIcon}
              />
            </View>

            <Text className="mt-3 text-[12px] font-sans leading-[17px] text-ink/60">
              Loads a complete example user: a wellness panel with ferritin at the bottom of range,
              a fortnight of vegetarian meals, hydration, and a logged cycle history. Useful for
              seeing every screen populated. It overwrites the profile and food log on this device.
            </Text>

            <View className="mt-4 flex-row gap-2">
              {demoActive ? (
                <Button
                  label="Remove demo data"
                  variant="danger"
                  size="sm"
                  onPress={() => {
                    clearDemoPersona();
                    queryClient.invalidateQueries();
                  }}
                />
              ) : (
                <Button
                  label="Load demo persona"
                  size="sm"
                  onPress={() => {
                    Alert.alert(
                      'Load the demo persona?',
                      'This replaces your profile and food log on this device with example data.',
                      [
                        { text: 'Cancel', style: 'cancel' },
                        {
                          text: 'Load',
                          onPress: () => {
                            applyDemoPersona();
                            queryClient.invalidateQueries();
                          },
                        },
                      ],
                    );
                  }}
                />
              )}
            </View>
          </Card>
        </View>

        <SectionLabel>Your data</SectionLabel>
        <View className="px-6">
          <Card>
            <View className="flex-row items-start gap-3">
              <ShieldCheck size={18} color={palette.optimal} strokeWidth={2.1} />
              <Text className="flex-1 text-[13px] font-sans leading-[19px] text-ink/65">
                Telemetry never leaves your device. Lab documents are sent to the parsing service
                only when you upload one, and the extracted values are stored locally.
              </Text>
            </View>

            <View className="mt-4 border-t border-ink/8 pt-4">
              <Text className="text-[12px] font-sans text-ink/50">
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

        <Text className="mt-8 text-center text-[11px] font-sans text-faint/80">
          Vitals {Constants.expoConfig?.version ?? '1.0.0'} · Not a medical device
        </Text>
      </ScrollView>
    </SafeAreaView>
  );
}
