import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/choice.dart' as choice;
import '../../../domain/entities/allergy.dart';
import '../../../domain/entities/cuisine_preference.dart';
import '../../../domain/entities/profile/diet_pattern.dart';
import '../../providers/user_profile_provider.dart';
import 'onboarding_scaffold.dart';

/// Diet, allergies and cuisine history. Mirrors `app/onboarding/diet.tsx`.
///
/// The distinction between the three groups is load-bearing, and the copy says
/// so: allergens and the diet pattern are *hard filters* that food and
/// restaurant recommendations may never violate, restrictions are preferences
/// that down-rank, and cuisines are an ordered preference deciding what floats
/// to the top. Getting a user to understand that in one screen is why they are
/// visually distinct rather than three identical chip rows.
class DietScreen extends ConsumerWidget {
  const DietScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);
    final notifier = ref.read(userProfileProvider.notifier);
    final cuisineCount = profile.cuisines.length;

    return OnboardingScaffold(
      title: 'How do you eat?',
      intro: 'Nothing we recommend — a meal, a dish, a restaurant — will ever '
          'contradict what you set here.',
      footerNote: cuisineCount == 0
          ? 'Skipping cuisines is fine — recommendations will just be less '
                'tailored.'
          : '$cuisineCount cuisine${cuisineCount == 1 ? '' : 's'} selected.',
      children: [
        const OnboardingLabel('Diet'),
        for (final pattern in DietPattern.values)
          choice.ChoiceRow(
            label: pattern.label,
            hint: pattern.hint,
            selected: profile.effectiveDietPattern == pattern,
            onTap: () => notifier.setDietPattern(pattern),
          ),

        const OnboardingLabel(
          'Allergies',
          icon: Icons.shield_outlined,
          detail: 'Anything selected here is excluded outright, everywhere in '
              'the app.',
        ),
        choice.ChipGroup(
          children: [
            for (final allergy in Allergy.values)
              choice.ChoiceChip(
                label: allergy.label,
                tone: choice.ChoiceChipTone.critical,
                selected: profile.allergies.contains(allergy),
                onTap: () => notifier.toggleAllergy(allergy),
              ),
          ],
        ),

        const OnboardingLabel(
          'Preferences',
          detail: 'Softer than an allergy — these push options down the list '
              'rather than removing them.',
        ),
        choice.ChipGroup(
          children: [
            for (final restriction in Restriction.values)
              choice.ChoiceChip(
                label: restriction.label,
                selected: profile.restrictions.contains(restriction),
                onTap: () => notifier.toggleRestriction(restriction),
              ),
          ],
        ),

        const OnboardingLabel(
          'Cuisines you eat most',
          detail: 'Tap in order of preference — the first one you pick carries '
              'the most weight when we suggest somewhere to eat.',
        ),
        choice.ChipGroup(
          children: [
            for (final (rank, cuisine) in [
              for (final c in CuisinePreference.values)
                (profile.cuisines.indexOf(c), c),
            ])
              choice.ChoiceChip(
                label: cuisine.label,
                selected: rank != -1,
                rank: rank == -1 ? null : rank + 1,
                onTap: () => notifier.toggleCuisine(cuisine),
              ),
          ],
        ),
      ],
    );
  }
}
