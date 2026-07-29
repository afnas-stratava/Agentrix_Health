import { memo } from 'react';
import { Pressable, Text, TextInput, View } from 'react-native';
import { Check, CircleAlert, FileText, KeyRound, Lock } from 'lucide-react-native';
import type { LabCandidate } from '@/schemas/connections';
import { MATCH_REASON_LABEL } from '@/schemas/connections';
import { ImportFailed } from '@/features/labs/gmail/errors';
import { IMPORT_ERROR_COPY } from '@/schemas/connections';
import { formatRelativeDay, toIsoDay } from '@/lib/date';
import { palette } from '@/theme/colors';

function confidenceTone(confidence: number): { label: string; color: string } {
  if (confidence >= 0.75) return { label: 'Very likely', color: palette.optimal };
  if (confidence >= 0.6) return { label: 'Likely', color: palette.normal };
  return { label: 'Possible', color: palette.borderline };
}

function formatSize(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${Math.round(bytes / 1024)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}

interface GmailCandidateRowProps {
  candidate: LabCandidate;
  selected: boolean;
  password: string;
  error: ImportFailed | null;
  imported: boolean;
  isLast: boolean;
  onToggle: () => void;
  onPasswordChange: (value: string) => void;
}

/**
 * One discovered attachment, with the evidence for why we think it is a lab
 * report shown inline.
 *
 * Surfacing the match reasons matters: a scanner that silently decides what is
 * medical in someone's inbox is exactly the kind of opaque behaviour that makes
 * mailbox access feel invasive. Showing "matched: known diagnostics lab,
 * report-style filename" makes the mechanism inspectable.
 */
function GmailCandidateRowBase({
  candidate,
  selected,
  password,
  error,
  imported,
  isLast,
  onToggle,
  onPasswordChange,
}: GmailCandidateRowProps) {
  const tone = confidenceTone(candidate.confidence);
  const disabled = candidate.alreadyImported || imported;

  return (
    <View className={isLast ? '' : 'border-b border-ink/8'}>
      <Pressable
        accessibilityRole="checkbox"
        accessibilityState={{ checked: selected, disabled }}
        accessibilityLabel={`${candidate.filename} from ${candidate.fromName}`}
        disabled={disabled}
        onPress={onToggle}
        className={`flex-row items-start gap-3 px-4 py-3.5 active:opacity-70 ${
          disabled ? 'opacity-45' : ''
        }`}
      >
        {/* Checkbox */}
        <View
          className={`mt-0.5 h-5 w-5 items-center justify-center rounded-md border-2 ${
            selected
              ? 'border-ink bg-ink'
              : 'border-ink/25'
          }`}
        >
          {(selected || disabled) && <Check size={12} color="#FFFFFF" strokeWidth={3.2} />}
        </View>

        <View className="flex-1">
          <View className="flex-row items-center gap-1.5">
            <FileText size={13} color={palette.mutedIcon} strokeWidth={2.1} />
            <Text
              className="flex-1 text-[13px] font-semibold text-ink"
              numberOfLines={1}
            >
              {candidate.filename}
            </Text>
            {candidate.isPasswordProtected && (
              <Lock size={12} color={palette.borderline} strokeWidth={2.4} />
            )}
          </View>

          <Text className="mt-0.5 text-[11px] font-sans text-ink/55" numberOfLines={1}>
            {candidate.fromName} · {formatRelativeDay(toIsoDay(new Date(candidate.receivedAt)))} ·{' '}
            {formatSize(candidate.sizeBytes)}
          </Text>

          <Text className="mt-1 text-[11px] font-sans leading-4 text-ink/45" numberOfLines={1}>
            {candidate.subject}
          </Text>

          {/* Why we matched it */}
          <View className="mt-2 flex-row flex-wrap items-center gap-1.5">
            <View
              style={{ backgroundColor: `${tone.color}1A` }}
              className="rounded-pill px-2 py-0.5"
            >
              <Text style={{ color: tone.color }} className="text-[9px] font-bold uppercase tracking-wide">
                {tone.label}
              </Text>
            </View>

            {candidate.matchReasons.slice(0, 2).map((reason) => (
              <View key={reason} className="rounded-pill bg-ink/6 px-2 py-0.5">
                <Text className="text-[9px] font-medium text-ink/50">
                  {MATCH_REASON_LABEL[reason]}
                </Text>
              </View>
            ))}

            {disabled && (
              <Text className="text-[9px] font-semibold uppercase tracking-wide text-optimal">
                Imported
              </Text>
            )}
          </View>
        </View>
      </Pressable>

      {/* Password entry, revealed only when a protected report is selected */}
      {selected && candidate.isPasswordProtected && !disabled && (
        <View className="px-4 pb-3.5">
          <View className="flex-row items-center gap-2 rounded-xl bg-ink/6 px-3">
            <KeyRound size={14} color={palette.borderline} strokeWidth={2.2} />
            <TextInput
              value={password}
              onChangeText={onPasswordChange}
              placeholder="PDF password"
              placeholderTextColor="rgba(90,89,170,0.35)"
              secureTextEntry
              autoCapitalize="characters"
              autoCorrect={false}
              accessibilityLabel={`Password for ${candidate.filename}`}
              className="h-11 flex-1 text-[13px] font-sans text-ink"
            />
          </View>
          <Text className="mt-1.5 text-[10px] font-sans leading-[14px] text-ink/45">
            Labs usually use your date of birth as DDMMYYYY, or the last digits of your phone
            number. It is sent once to unlock the file and never stored.
          </Text>
        </View>
      )}

      {error && (
        <View className="mx-4 mb-3.5 flex-row items-start gap-2 rounded-xl bg-critical/10 px-3 py-2.5">
          <CircleAlert size={13} color={palette.critical} strokeWidth={2.2} />
          <Text className="flex-1 text-[11px] font-sans leading-4 text-critical">
            {IMPORT_ERROR_COPY[error.reason]}
          </Text>
        </View>
      )}
    </View>
  );
}

export const GmailCandidateRow = memo(GmailCandidateRowBase);
