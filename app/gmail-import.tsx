import { useCallback, useMemo, useState } from 'react';
import { ActivityIndicator, Pressable, ScrollView, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useRouter } from 'expo-router';
import { CheckCircle2, Inbox, Mail, SearchX, X } from 'lucide-react-native';

import type { LabCandidate } from '@/schemas/connections';
import { GmailCandidateRow } from '@/components/labs/GmailCandidateRow';
import { Card } from '@/components/ui/Card';
import { Button, IconButton } from '@/components/ui/Button';
import { EmptyState } from '@/components/ui/EmptyState';
import {
  useGmailConnection,
  useGmailScan,
  useImportQueue,
  DEFAULT_SCAN_DAYS,
} from '@/features/labs/gmail/queries';
import { AUTO_SELECT_THRESHOLD } from '@/features/labs/gmail/providers';
import type { ImportFailed } from '@/features/labs/gmail/errors';
import { palette } from '@/theme/colors';

const LOOKBACK_OPTIONS = [
  { days: 365, label: '1 year' },
  { days: DEFAULT_SCAN_DAYS, label: '2 years' },
  { days: 1825, label: '5 years' },
] as const;

export default function GmailImportScreen() {
  const router = useRouter();
  const { data: connection } = useGmailConnection();

  const [lookback, setLookback] = useState<number>(DEFAULT_SCAN_DAYS);
  const [selected, setSelected] = useState<Set<string>>(new Set());
  const [passwords, setPasswords] = useState<Record<string, string>>({});
  const [errors, setErrors] = useState<Record<string, ImportFailed>>({});
  const [importedIds, setImportedIds] = useState<Set<string>>(new Set());

  const scan = useGmailScan(lookback);
  const { run, isImporting } = useImportQueue();

  const candidates: LabCandidate[] = useMemo(
    () => scan.data?.candidates ?? [],
    [scan.data],
  );

  const runScan = useCallback(async () => {
    setErrors({});
    setImportedIds(new Set());

    const result = await scan.mutateAsync();

    // Pre-tick the confident, not-yet-imported findings so the common case is
    // a single tap — but never auto-tick a low-confidence guess.
    setSelected(
      new Set(
        result.candidates
          .filter((c) => c.confidence >= AUTO_SELECT_THRESHOLD && !c.alreadyImported)
          .map((c) => c.attachmentId),
      ),
    );
  }, [scan]);

  const toggle = useCallback((attachmentId: string) => {
    setSelected((current) => {
      const next = new Set(current);
      if (next.has(attachmentId)) next.delete(attachmentId);
      else next.add(attachmentId);
      return next;
    });
  }, []);

  const setPassword = useCallback((attachmentId: string, value: string) => {
    setPasswords((current) => ({ ...current, [attachmentId]: value }));
  }, []);

  const chosen = useMemo(
    () => candidates.filter((c) => selected.has(c.attachmentId)),
    [candidates, selected],
  );

  // A protected PDF with no password will fail server-side; block it here
  // rather than burning a round-trip to learn that.
  const missingPassword = chosen.some(
    (c) => c.isPasswordProtected && !(passwords[c.attachmentId] ?? '').trim(),
  );

  const handleImport = useCallback(async () => {
    const results = await run(chosen, passwords);

    const nextErrors: Record<string, ImportFailed> = {};
    const succeeded = new Set(importedIds);

    for (const { candidate, error } of results) {
      if (error) nextErrors[candidate.attachmentId] = error;
      else succeeded.add(candidate.attachmentId);
    }

    setErrors(nextErrors);
    setImportedIds(succeeded);
    // Keep failures ticked so the user can fix a password and retry.
    setSelected(new Set(Object.keys(nextErrors)));

    if (Object.keys(nextErrors).length === 0 && succeeded.size > 0) {
      router.replace('/(tabs)/labs');
    }
  }, [run, chosen, passwords, importedIds, router]);

  const hasScanned = scan.isSuccess || scan.isError;
  const importedCount = importedIds.size;

  return (
    <SafeAreaView className="flex-1 bg-canvas">
      <View className="flex-row items-start justify-between px-6 pb-2 pt-2">
        <View className="flex-1 pr-4">
          <Text className="text-[24px] font-bold text-ink">Import from Gmail</Text>
          <Text className="mt-1 text-[12px] font-sans text-muted" numberOfLines={1}>
            {connection?.emailAddress ?? 'Not connected'}
          </Text>
        </View>
        <IconButton icon={X} label="Close" tone="onCanvas" onPress={() => router.back()} />
      </View>

      <ScrollView
        showsVerticalScrollIndicator={false}
        contentContainerStyle={{ paddingHorizontal: 24, paddingBottom: 140 }}
        keyboardShouldPersistTaps="handled"
      >
        {/* Lookback window — a scan is a privacy-visible action, so its scope
            is an explicit, visible choice rather than a hidden default. */}
        <View className="mt-3">
          <Text className="mb-2 text-[11px] font-semibold uppercase tracking-wider text-faint">
            Search the last
          </Text>
          <View className="flex-row gap-2">
            {LOOKBACK_OPTIONS.map((option) => {
              const isActive = option.days === lookback;
              return (
                <Pressable
                  key={option.days}
                  accessibilityRole="radio"
                  accessibilityState={{ selected: isActive }}
                  disabled={scan.isPending || isImporting}
                  onPress={() => setLookback(option.days)}
                  className={`flex-1 items-center rounded-pill py-2.5 active:opacity-70 ${
                    isActive ? 'bg-accent' : 'bg-ink/5'
                  }`}
                >
                  <Text
                    className={`text-[13px] font-semibold ${
                      isActive ? 'text-ink' : 'text-muted'
                    }`}
                  >
                    {option.label}
                  </Text>
                </Pressable>
              );
            })}
          </View>
        </View>

        {/* Scan trigger / results */}
        {!hasScanned && !scan.isPending && (
          <View className="mt-6">
            <Card>
              <View className="items-center py-2">
                <View className="h-14 w-14 items-center justify-center rounded-full bg-accent/25">
                  <Inbox size={24} color={palette.cardText} strokeWidth={2} />
                </View>
                <Text className="mt-4 text-center text-[16px] font-bold text-ink">
                  Ready to search
                </Text>
                <Text className="mt-1.5 max-w-[280px] text-center text-[12px] font-sans leading-[17px] text-ink/60">
                  We look only for attachments from known diagnostics labs, or messages whose
                  subject reads like a test result. Nothing is opened until you choose it.
                </Text>
              </View>
            </Card>

            <Button
              label="Scan my inbox"
              icon={Mail}
              size="lg"
              fullWidth
              onPress={() => void runScan()}
              className="mt-4"
            />
          </View>
        )}

        {scan.isPending && (
          <Card className="mt-6">
            <View className="items-center py-6">
              <ActivityIndicator size="large" color={palette.cardText} />
              <Text className="mt-4 text-[15px] font-semibold text-ink">
                Searching your inbox…
              </Text>
              <Text className="mt-1 text-[12px] font-sans text-ink/55">
                This can take up to a minute on a large mailbox.
              </Text>
            </View>
          </Card>
        )}

        {scan.isError && (
          <Card className="mt-6">
            <Text className="text-[15px] font-semibold text-ink">Scan failed</Text>
            <Text className="mt-1.5 text-[12px] font-sans leading-[17px] text-ink/60">
              {scan.error.message}
            </Text>
            <Button
              label="Try again"
              variant="secondary"
              size="sm"
              onPress={() => void runScan()}
              className="mt-4 self-start"
            />
          </Card>
        )}

        {scan.isSuccess && candidates.length === 0 && (
          <View className="mt-4">
            <EmptyState
              icon={SearchX}
              title="No lab reports found"
              body={`We examined ${scan.data.messagesExamined.toLocaleString()} messages and found nothing that looks like a lab report. Try a longer window, or add the report manually.`}
              actionLabel="Add manually"
              onAction={() => router.replace('/upload')}
            />
          </View>
        )}

        {scan.isSuccess && candidates.length > 0 && (
          <View className="mt-6">
            <View className="mb-3 flex-row items-end justify-between">
              <Text className="text-[11px] font-semibold uppercase tracking-wider text-faint">
                {candidates.length} found
              </Text>
              <Text className="text-[11px] font-sans text-faint/80">
                of {scan.data.messagesExamined.toLocaleString()} messages
              </Text>
            </View>

            <Card padded={false}>
              {candidates.map((candidate, index) => (
                <GmailCandidateRow
                  key={candidate.attachmentId}
                  candidate={candidate}
                  selected={selected.has(candidate.attachmentId)}
                  password={passwords[candidate.attachmentId] ?? ''}
                  error={errors[candidate.attachmentId] ?? null}
                  imported={importedIds.has(candidate.attachmentId)}
                  isLast={index === candidates.length - 1}
                  onToggle={() => toggle(candidate.attachmentId)}
                  onPasswordChange={(value) => setPassword(candidate.attachmentId, value)}
                />
              ))}
            </Card>

            {importedCount > 0 && Object.keys(errors).length > 0 && (
              <View className="mt-3 flex-row items-center gap-2 rounded-2xl bg-optimal/12 px-4 py-3">
                <CheckCircle2 size={15} color={palette.optimal} strokeWidth={2.2} />
                <Text className="flex-1 text-[12px] font-sans text-ink/80">
                  {importedCount} imported. Fix the errors below and retry the rest.
                </Text>
              </View>
            )}
          </View>
        )}
      </ScrollView>

      {/* Sticky action bar */}
      {scan.isSuccess && candidates.length > 0 && (
        <View className="absolute bottom-0 w-full border-t border-hairline bg-surface px-6 pb-8 pt-4">
          <Button
            label={
              isImporting
                ? `Importing ${chosen.length}…`
                : chosen.length === 0
                  ? 'Select a report to import'
                  : `Import ${chosen.length} report${chosen.length === 1 ? '' : 's'}`
            }
            size="lg"
            fullWidth
            loading={isImporting}
            disabled={chosen.length === 0 || missingPassword}
            onPress={() => void handleImport()}
          />
          {missingPassword && (
            <Text className="mt-2 text-center text-[11px] font-sans text-borderline">
              Enter the password for the locked report above.
            </Text>
          )}
        </View>
      )}
    </SafeAreaView>
  );
}
