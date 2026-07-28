import { useCallback, useState } from 'react';
import { ActivityIndicator, Pressable, ScrollView, Text, View } from 'react-native';
import { useRouter } from 'expo-router';
import { Camera, FileText, ImageIcon, ShieldCheck, X } from 'lucide-react-native';

import { Button, IconButton } from '@/components/ui/Button';
import { useUploadLabReport } from '@/features/labs/queries';
import {
  captureImage,
  pickDocument,
  pickImage,
  PickerCancelled,
  PickerPermissionDenied,
} from '@/features/labs/picker';
import { isOfflineMode } from '@/lib/env';
import { palette } from '@/theme/colors';

type Method = 'pdf' | 'library' | 'camera';

const METHODS: Array<{
  id: Method;
  icon: typeof FileText;
  title: string;
  body: string;
}> = [
  {
    id: 'pdf',
    icon: FileText,
    title: 'Choose a PDF',
    body: 'The lab portal download. Highest extraction accuracy.',
  },
  {
    id: 'library',
    icon: ImageIcon,
    title: 'Pick a photo',
    body: 'A screenshot or saved image of your report.',
  },
  {
    id: 'camera',
    icon: Camera,
    title: 'Scan the printout',
    body: 'Flat, well lit, whole page in frame.',
  },
];

export default function UploadModal() {
  const router = useRouter();
  const upload = useUploadLabReport();
  const [error, setError] = useState<string | null>(null);
  const [picking, setPicking] = useState<Method | null>(null);

  const start = useCallback(
    async (method: Method) => {
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
        // already visible in the Labs tab, so holding the sheet open would
        // just block the user behind a spinner.
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
    <View className="flex-1 bg-mockup-bg">
      <ScrollView contentContainerStyle={{ padding: 24, paddingBottom: 48 }}>
        <View className="flex-row items-start justify-between">
          <View className="flex-1 pr-4">
            <Text className="text-[26px] font-bold text-white">Add a lab report</Text>
            <Text className="mt-1.5 text-[13px] leading-5 text-white/55">
              We extract every biomarker, convert units, and flag each value against both the
              lab&apos;s range and an evidence-based optimal band.
            </Text>
          </View>
          <IconButton icon={X} label="Close" tone="onCanvas" onPress={() => router.back()} />
        </View>

        <View className="mt-7">
          {METHODS.map(({ id, icon: Icon, title, body }) => {
            const isBusy = picking === id;
            return (
              <Pressable
                key={id}
                accessibilityRole="button"
                accessibilityLabel={title}
                disabled={picking !== null}
                onPress={() => void start(id)}
                className="mb-3 flex-row items-center gap-4 rounded-card bg-mockup-card-bg p-4 active:opacity-80"
              >
                <View className="h-12 w-12 items-center justify-center rounded-2xl bg-mockup-card-text/8">
                  {isBusy ? (
                    <ActivityIndicator size="small" color={palette.cardText} />
                  ) : (
                    <Icon size={20} color={palette.cardText} strokeWidth={2} />
                  )}
                </View>
                <View className="flex-1">
                  <Text className="text-[15px] font-semibold text-mockup-card-text">{title}</Text>
                  <Text className="mt-0.5 text-[12px] leading-4 text-mockup-card-text/55">
                    {body}
                  </Text>
                </View>
              </Pressable>
            );
          })}
        </View>

        {error && (
          <View className="mt-1 rounded-2xl border border-critical/30 bg-critical/12 p-4">
            <Text className="text-[13px] leading-[19px] text-white/85">{error}</Text>
          </View>
        )}

        <View className="mt-6 flex-row items-start gap-3 rounded-2xl border border-white/10 bg-white/5 p-4">
          <ShieldCheck size={16} color={palette.optimal} strokeWidth={2.1} />
          <Text className="flex-1 text-[12px] leading-[17px] text-white/55">
            {isOfflineMode
              ? 'No parsing service is configured, so the app is using its on-device fixture parser. Nothing leaves this device.'
              : 'The document is sent to the parsing service over TLS, processed, and not retained. Extracted values are stored locally on this device.'}
          </Text>
        </View>

        <Button
          label="Cancel"
          variant="ghost"
          fullWidth
          onPress={() => router.back()}
          className="mt-4"
        />
      </ScrollView>
    </View>
  );
}
