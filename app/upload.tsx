import { useCallback, useState } from 'react';
import { ActivityIndicator, Pressable, ScrollView, Text, View } from 'react-native';
import { useRouter } from 'expo-router';
import {
  Camera,
  CheckCircle2,
  ChevronRight,
  FileText,
  ImageIcon,
  Mail,
  ShieldCheck,
  Sparkles,
  X,
} from 'lucide-react-native';

import { IconButton } from '@/components/ui/Button';
import { useUploadLabReport } from '@/features/labs/queries';
import {
  captureImage,
  pickDocument,
  pickImage,
  PickerCancelled,
  PickerPermissionDenied,
} from '@/features/labs/picker';
import { useConnectGmail, useGmailConnection } from '@/features/labs/gmail/queries';
import { GmailAuthCancelled, GmailNotConfigured } from '@/features/labs/gmail/auth';
import { isOfflineMode } from '@/lib/env';
import { palette } from '@/theme/colors';

type ManualMethod = 'pdf' | 'library' | 'camera';

const MANUAL_METHODS: Array<{ id: ManualMethod; icon: typeof FileText; title: string }> = [
  { id: 'pdf', icon: FileText, title: 'Choose a PDF' },
  { id: 'library', icon: ImageIcon, title: 'Pick a photo' },
  { id: 'camera', icon: Camera, title: 'Scan a printout' },
];

export default function UploadModal() {
  const router = useRouter();
  const upload = useUploadLabReport();
  const connectGmail = useConnectGmail();
  const { data: connection } = useGmailConnection();

  const [error, setError] = useState<string | null>(null);
  const [picking, setPicking] = useState<ManualMethod | null>(null);

  const isConnected = connection?.status === 'connected';

  const handleGmail = useCallback(async () => {
    setError(null);

    if (isConnected) {
      router.replace('/gmail-import');
      return;
    }

    try {
      await connectGmail.mutateAsync();
      router.replace('/gmail-import');
    } catch (caught) {
      if (caught instanceof GmailAuthCancelled) return;
      if (caught instanceof GmailNotConfigured) {
        setError(
          'Gmail import is not configured in this build. Add EXPO_PUBLIC_GOOGLE_IOS_CLIENT_ID to your .env.',
        );
        return;
      }
      setError(caught instanceof Error ? caught.message : 'Could not connect Gmail');
    }
  }, [connectGmail, isConnected, router]);

  const handleManual = useCallback(
    async (method: ManualMethod) => {
      setError(null);
      setPicking(method);

      try {
        const request =
          method === 'pdf'
            ? await pickDocument()
            : method === 'library'
              ? await pickImage()
              : await captureImage();

        // Dismiss immediately: parsing takes 30s+ and the placeholder row is
        // already visible in the Labs tab.
        router.back();
        upload.mutate(request);
      } catch (caught) {
        if (caught instanceof PickerCancelled) return;
        if (caught instanceof PickerPermissionDenied) {
          setError(caught.message);
          return;
        }
        setError(caught instanceof Error ? caught.message : 'Could not read that file');
      } finally {
        setPicking(null);
      }
    },
    [router, upload],
  );

  return (
    <View className="flex-1 bg-canvas">
      <ScrollView contentContainerStyle={{ padding: 24, paddingBottom: 48 }}>
        <View className="flex-row items-start justify-between">
          <View className="flex-1 pr-4">
            <Text className="text-[26px] font-bold text-ink">Add your blood work</Text>
            <Text className="mt-1.5 text-[13px] font-sans leading-5 text-muted">
              Most lab reports arrive by email and stay there. We can find them for you.
            </Text>
          </View>
          <IconButton icon={X} label="Close" tone="onCanvas" onPress={() => router.back()} />
        </View>

        {/* PRIMARY PATH — Gmail */}
        <Pressable
          accessibilityRole="button"
          accessibilityLabel={isConnected ? 'Scan your Gmail for reports' : 'Connect Gmail'}
          disabled={connectGmail.isPending}
          onPress={() => void handleGmail()}
          className="mt-6 overflow-hidden rounded-card bg-surface active:opacity-85"
        >
          <View className="h-1 w-full bg-accent" />

          <View className="p-5">
            <View className="flex-row items-center gap-3.5">
              <View className="h-12 w-12 items-center justify-center rounded-2xl bg-accent/25">
                {connectGmail.isPending ? (
                  <ActivityIndicator size="small" color={palette.cardText} />
                ) : (
                  <Mail size={22} color={palette.cardText} strokeWidth={2.1} />
                )}
              </View>

              <View className="flex-1">
                <View className="flex-row items-center gap-2">
                  <Text className="text-[17px] font-bold text-ink">
                    {isConnected ? 'Scan your inbox' : 'Connect Gmail'}
                  </Text>
                  <View className="flex-row items-center gap-1 rounded-pill bg-ink/8 px-2 py-0.5">
                    <Sparkles size={9} color={palette.cardText} strokeWidth={2.6} />
                    <Text className="text-[9px] font-bold uppercase tracking-wider text-ink/70">
                      Fastest
                    </Text>
                  </View>
                </View>

                <Text className="mt-1 text-[12px] font-sans leading-[17px] text-ink/60">
                  {isConnected
                    ? `Search ${connection.emailAddress} for lab reports and import them in one go.`
                    : 'We search only for messages from known diagnostics labs, and only ones with attachments.'}
                </Text>
              </View>

              <ChevronRight size={18} color={palette.mutedIcon} strokeWidth={2.2} />
            </View>

            {isConnected && (
              <View className="mt-3 flex-row items-center gap-1.5 border-t border-ink/8 pt-3">
                <CheckCircle2 size={13} color={palette.optimal} strokeWidth={2.3} />
                <Text className="text-[11px] font-sans text-ink/55">
                  Connected as {connection.emailAddress}
                </Text>
              </View>
            )}
          </View>
        </Pressable>

        {/* What we do and don't read — shown before consent, not buried in a policy */}
        <View className="mt-3 rounded-2xl border border-hairline bg-ink/4 p-4">
          <View className="flex-row items-start gap-2.5">
            <ShieldCheck size={15} color={palette.optimal} strokeWidth={2.1} />
            <View className="flex-1">
              <Text className="text-[12px] font-semibold text-ink/80">
                What we access
              </Text>
              <Text className="mt-1 text-[11px] font-sans leading-[16px] text-muted">
                Read-only. We search for attachments from known labs, and we only ever open the
                ones you tick. We never send email, never read unrelated messages, and your Google
                sign-in stays on Google&apos;s servers — this app never holds your password or a
                long-lived token.
              </Text>
            </View>
          </View>
        </View>

        {/* SECONDARY PATH — manual, deliberately quieter */}
        <Text className="mb-2 mt-7 text-[11px] font-semibold uppercase tracking-wider text-faint">
          Or add one manually
        </Text>

        <View className="overflow-hidden rounded-card bg-ink/4">
          {MANUAL_METHODS.map(({ id, icon: Icon, title }, index) => {
            const isBusy = picking === id;
            return (
              <Pressable
                key={id}
                accessibilityRole="button"
                accessibilityLabel={title}
                disabled={picking !== null}
                onPress={() => void handleManual(id)}
                className={`flex-row items-center gap-3.5 px-4 py-3.5 active:opacity-70 ${
                  index > 0 ? 'border-t border-hairline' : ''
                }`}
              >
                <View className="h-9 w-9 items-center justify-center rounded-xl bg-ink/5">
                  {isBusy ? (
                    <ActivityIndicator size="small" color={palette.onBgMuted} />
                  ) : (
                    <Icon size={17} color={palette.onBgMuted} strokeWidth={2} />
                  )}
                </View>
                <Text className="flex-1 text-[14px] font-medium text-ink/80">{title}</Text>
                <ChevronRight size={16} color="rgba(255,255,255,0.3)" strokeWidth={2.2} />
              </Pressable>
            );
          })}
        </View>

        {error && (
          <View className="mt-4 rounded-2xl border border-critical/30 bg-critical/12 p-4">
            <Text className="text-[13px] font-sans leading-[19px] text-ink/80">{error}</Text>
          </View>
        )}

        {isOfflineMode && (
          <Text className="mt-5 text-center text-[11px] font-sans leading-4 text-faint/80">
            No backend configured — Gmail import and parsing run against on-device fixtures.
          </Text>
        )}
      </ScrollView>
    </View>
  );
}
