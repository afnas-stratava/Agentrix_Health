import { ScrollView, StyleSheet, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { LinearGradient } from 'expo-linear-gradient';
import { useRouter } from 'expo-router';
import {
  Activity,
  ChevronLeft,
  Droplets,
  Dumbbell,
  Flame,
  Footprints,
  Info,
  Moon,
  UtensilsCrossed,
} from 'lucide-react-native';

import { Card } from '@/components/ui/Card';
import { Button, IconButton } from '@/components/ui/Button';
import { SectionHeader } from '@/components/ui/SectionHeader';
import { EmptyState } from '@/components/ui/EmptyState';
import { FadeIn } from '@/components/ui/FadeIn';
import { Skeleton } from '@/components/ui/Skeleton';

import { useDailyBrief } from '@/features/brief/use-brief';
import type { BriefDriver, WorkoutIntensity } from '@/features/brief/compose';
import { HERO_GRADIENT, palette } from '@/theme/colors';
import { cn } from '@/lib/cn';

/**
 * The morning brief.
 *
 * One screen answering "what should I do today", composed from blood work,
 * last night's recovery, cycle phase and the week's eating. The driver list at
 * the bottom is not decoration — it is what makes the plan auditable, and it is
 * the reason this can be shown to someone without over-claiming.
 */

const TARGET_ICON = {
  calories: Flame,
  protein: UtensilsCrossed,
  water: Droplets,
  steps: Footprints,
  sleep: Moon,
} as const;

const DRIVER_ICON: Record<BriefDriver['kind'], typeof Activity> = {
  recovery: Activity,
  sleep: Moon,
  cycle: Droplets,
  labs: Info,
  nutrition: UtensilsCrossed,
};

const INTENSITY_TONE: Record<WorkoutIntensity, string> = {
  rest: palette.critical,
  easy: palette.borderline,
  moderate: palette.normal,
  hard: palette.optimal,
};

export default function BriefScreen() {
  const router = useRouter();
  const { brief, isLoading, needsProfile } = useDailyBrief();

  if (needsProfile) {
    return (
      <SafeAreaView className="flex-1 bg-canvas" edges={['top']}>
        <View className="px-5 pt-1">
          <IconButton icon={ChevronLeft} label="Back" tone="onCanvas" onPress={() => router.back()} />
        </View>
        <View className="flex-1 justify-center">
          <EmptyState
            icon={UtensilsCrossed}
            title="We need a few numbers first"
            body="Your brief prescribes calories, protein and hydration — which needs your height, weight and age before it can say anything specific."
            actionLabel="Complete your profile"
            onAction={() => router.push('/(tabs)/settings')}
          />
        </View>
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView className="flex-1 bg-canvas" edges={['top']}>
      <ScrollView showsVerticalScrollIndicator={false} contentContainerStyle={{ paddingBottom: 48 }}>
        <View className="flex-row items-center justify-between px-5 pt-1">
          <IconButton icon={ChevronLeft} label="Back" tone="onCanvas" onPress={() => router.back()} />
          <Text className="text-[15px] font-bold text-ink">Your morning brief</Text>
          <View className="w-9" />
        </View>

        {isLoading && brief == null ? (
          <View className="mt-5 gap-3 px-5">
            <Skeleton className="h-[220px] w-full rounded-card" />
            <Skeleton className="h-[120px] w-full rounded-card" />
          </View>
        ) : brief == null ? (
          <EmptyState
            icon={Info}
            title="Nothing to brief yet"
            body="Connect Apple Health or add a blood report and your first brief appears the next morning."
          />
        ) : (
          <>
            {/* HERO */}
            <FadeIn delay={30} className="mt-4 px-5">
              <View className="overflow-hidden rounded-card" style={styles.hero}>
                <LinearGradient
                  colors={[...HERO_GRADIENT]}
                  start={{ x: 0, y: 0 }}
                  end={{ x: 1, y: 1 }}
                  style={StyleSheet.absoluteFill}
                />
                <View className="p-5">
                  <Text className="text-[10px] font-bold uppercase tracking-[1.5px] text-white/60">
                    {new Date(brief.generatedAt).toLocaleDateString(undefined, {
                      weekday: 'long',
                      day: 'numeric',
                      month: 'long',
                    })}
                  </Text>

                  <Text className="mt-2 text-[24px] font-bold leading-[29px] text-white">
                    {brief.headline}
                  </Text>

                  {brief.narrative.map((sentence, index) => (
                    <Text
                      key={index}
                      className="mt-2.5 text-[13px] font-sans leading-[19px] text-white/80"
                    >
                      {sentence}
                    </Text>
                  ))}
                </View>
              </View>
            </FadeIn>

            {/* TARGETS */}
            <FadeIn delay={90} className="mt-6 px-5">
              <SectionHeader title="Today's targets" />
              <Card padded={false}>
                {brief.targets.map((target, index) => {
                  const Icon = TARGET_ICON[target.id];
                  return (
                    <View
                      key={target.id}
                      className={cn(
                        'flex-row items-center gap-3 px-4 py-3.5',
                        index !== brief.targets.length - 1 && 'border-b border-hairline',
                      )}
                    >
                      <View className="h-9 w-9 items-center justify-center rounded-xl bg-brand-50">
                        <Icon size={16} color={palette.brand} strokeWidth={2.2} />
                      </View>
                      <View className="flex-1">
                        <Text className="text-[14px] font-semibold text-ink">{target.label}</Text>
                        <Text className="mt-0.5 text-[11px] font-sans leading-4 text-muted">
                          {target.basis}
                        </Text>
                      </View>
                      <Text className="text-[17px] font-bold text-ink">{target.value}</Text>
                    </View>
                  );
                })}
              </Card>
            </FadeIn>

            {/* TRAINING */}
            <FadeIn delay={150} className="mt-6 px-5">
              <SectionHeader title="Training" />
              <Card>
                <View className="flex-row items-start gap-3">
                  <View
                    className="h-10 w-10 items-center justify-center rounded-2xl"
                    style={{ backgroundColor: `${INTENSITY_TONE[brief.workout.intensity]}18` }}
                  >
                    <Dumbbell
                      size={18}
                      color={INTENSITY_TONE[brief.workout.intensity]}
                      strokeWidth={2.2}
                    />
                  </View>
                  <View className="flex-1">
                    <Text className="text-[15px] font-semibold text-ink">
                      {brief.workout.title}
                    </Text>
                    <Text className="mt-1 text-[12px] font-sans leading-[18px] text-muted">
                      {brief.workout.detail}
                    </Text>
                  </View>
                </View>
              </Card>
            </FadeIn>

            {/* FOOD FOCUS */}
            <FadeIn delay={210} className="mt-6 px-5">
              <SectionHeader title="Eat for this today" />
              <Card>
                <Text className="text-[15px] font-semibold text-ink">{brief.foodFocus.title}</Text>
                <Text className="mt-1.5 text-[12px] font-sans leading-[18px] text-muted">
                  {brief.foodFocus.detail}
                </Text>

                {brief.foodFocus.examples.length > 0 && (
                  <View className="mt-3.5 border-t border-hairline pt-3.5">
                    <Text className="mb-2 text-[10px] font-bold uppercase tracking-wider text-faint">
                      Good options for you
                    </Text>
                    {brief.foodFocus.examples.map((example) => (
                      <View key={example.id} className="mb-1.5 flex-row items-baseline gap-2">
                        <View className="h-1 w-1 rounded-full bg-brand-400" />
                        <Text className="text-[13px] font-semibold text-ink">{example.name}</Text>
                        <Text className="text-[11px] font-sans text-faint">
                          {example.portionLabel}
                        </Text>
                      </View>
                    ))}
                  </View>
                )}

                <Button
                  label="Find somewhere nearby"
                  variant="secondary"
                  size="sm"
                  fullWidth
                  className="mt-3"
                  onPress={() => router.push('/dining')}
                />
              </Card>
            </FadeIn>

            {/* DRIVERS */}
            <FadeIn delay={270} className="mt-6 px-5">
              <SectionHeader title="What shaped this" count={brief.drivers.length} />
              <Card padded={false}>
                {brief.drivers.map((driver, index) => {
                  const Icon = DRIVER_ICON[driver.kind];
                  return (
                    <View
                      key={driver.id}
                      className={cn(
                        'flex-row items-start gap-3 px-4 py-3.5',
                        index !== brief.drivers.length - 1 && 'border-b border-hairline',
                      )}
                    >
                      <Icon size={15} color={palette.faint} strokeWidth={2.2} className="mt-0.5" />
                      <View className="flex-1">
                        <Text className="text-[13px] font-semibold leading-[18px] text-ink">
                          {driver.label}
                        </Text>
                        <Text className="mt-0.5 text-[11px] font-sans leading-[16px] text-muted">
                          {driver.detail}
                        </Text>
                      </View>
                    </View>
                  );
                })}
              </Card>
            </FadeIn>

            {/* CAVEATS */}
            {brief.caveats.length > 0 && (
              <FadeIn delay={330} className="mt-5 px-5">
                <View className="rounded-2xl border border-hairline bg-ink/4 p-4">
                  <Text className="mb-1.5 text-[10px] font-bold uppercase tracking-wider text-faint">
                    What this brief could not see
                  </Text>
                  {brief.caveats.map((caveat, index) => (
                    <Text
                      key={index}
                      className="mt-1 text-[11px] font-sans leading-[16px] text-muted"
                    >
                      • {caveat}
                    </Text>
                  ))}
                </View>
              </FadeIn>
            )}

            <Text className="mt-6 px-10 text-center text-[10px] font-sans leading-[15px] text-faint">
              Composed from your own data on this device. Not medical advice, and not a diagnosis.
            </Text>
          </>
        )}
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  hero: {
    shadowColor: palette.brandDeep,
    shadowOffset: { width: 0, height: 10 },
    shadowOpacity: 0.18,
    shadowRadius: 22,
    elevation: 10,
  },
});
