import { useMemo } from 'react';
import type { ResolvedProfile } from '@/schemas/profile';
import { HealthProfileSchema } from '@/schemas/profile';
import { useProfileStore } from '@/store/profile.store';
import { useSettingsStore } from '@/store/settings.store';

/**
 * Recombines the declared profile with the two demographic fields that live in
 * `settings.store` (biological sex and birth year, both of which predate this
 * profile and are wired into the lab reference-range resolver).
 *
 * Consumers should depend on this rather than reading either store directly, so
 * that moving a field between the two stores stays a one-file change.
 */
export function useProfile(): ResolvedProfile {
  const sex = useSettingsStore((s) => s.sex);
  const birthYear = useSettingsStore((s) => s.birthYear);
  const profile = useProfileStore((s) => s);

  return useMemo(() => {
    // Strips the action functions off the store slice; the schema output is
    // exactly the data half.
    const data = HealthProfileSchema.parse(profile);
    return {
      ...data,
      sex,
      birthYear,
      ageYears: birthYear == null ? null : new Date().getFullYear() - birthYear,
    };
    // The store object identity changes on any mutation, which is precisely
    // when this needs to recompute.
  }, [profile, sex, birthYear]);
}

/**
 * True when the user has told us enough for the nutrition and dining features
 * to say anything specific. Onboarding gates on this.
 */
export function isProfileComplete(profile: ResolvedProfile): boolean {
  return (
    profile.heightCm != null &&
    profile.weightKg != null &&
    profile.birthYear != null &&
    profile.cuisines.length > 0
  );
}
