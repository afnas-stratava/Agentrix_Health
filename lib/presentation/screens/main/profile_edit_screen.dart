import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/util/iso_day.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/choice.dart' as choice;
import '../../../core/widgets/screen_back_button.dart';
import '../../../core/widgets/section_header.dart';
import '../../../domain/entities/allergy.dart';
import '../../../domain/entities/cuisine_preference.dart';
import '../../../domain/entities/health_goal.dart';
import '../../../domain/entities/profile/cycle_profile.dart';
import '../../../domain/entities/profile/diet_pattern.dart';
import '../../../features/cycle/menstrual_phase.dart';
import '../../../features/nutrition/targets.dart';
import '../../providers/cycle_phase_provider.dart';
import '../../providers/user_profile_provider.dart';
import 'main_shell.dart';

/// The profile editor. Mirrors `app/profile.tsx`.
///
/// Every field onboarding collects is editable here, in the same order and with
/// the same components — a user who changes their goal should recognise the
/// screen. The cycle section lives here rather than in Settings because it is
/// profile data, and because logging a period start is something people do from
/// wherever they happen to be, not somewhere buried behind a preferences list.
class ProfileEditScreen extends ConsumerWidget {
  const ProfileEditScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);
    final notifier = ref.read(userProfileProvider.notifier);
    final bmi = profile.bodyMassIndex;
    final bmr = basalMetabolicRate(profile);

    return ListView(
      padding: EdgeInsets.only(
        top: AppSpacing.space1,
        bottom: MainShell.bottomInsetFor(context),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space5),
          child: Row(
            children: [
              const ScreenBackButton(),
              Expanded(
                child: Text(
                  'Your profile',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.h6.copyWith(
                    fontSize: 15,
                    letterSpacing: 0,
                  ),
                ),
              ),
              const SizedBox(width: 36),
            ],
          ),
        ),

        // BODY
        _Group(
          title: 'Body',
          topGap: AppSpacing.space5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              choice.Stepper(
                label: 'Height',
                unit: 'cm',
                value: profile.heightCm,
                min: 120,
                max: 220,
                fallback: 170,
                onChanged: (value) => notifier.setBodyComposition(
                  heightCm: value,
                  weightKg: profile.weightKg,
                ),
              ),
              choice.Stepper(
                label: 'Weight',
                unit: 'kg',
                value: profile.weightKg,
                min: 35,
                max: 200,
                step: 0.5,
                fallback: 70,
                onChanged: (value) => notifier.setBodyComposition(
                  heightCm: profile.heightCm,
                  weightKg: value,
                ),
              ),
              choice.Stepper(
                label: 'Age',
                unit: 'years',
                value: profile.ageYears?.toDouble(),
                min: 16,
                max: 100,
                fallback: 32,
                onChanged: (value) => notifier.setAge('${value.round()}'),
              ),
              if (bmi != null || bmr != null) _BodyStats(bmi: bmi, bmr: bmr),
            ],
          ),
        ),

        // GOAL
        _Group(
          title: 'Goal',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final goal in HealthGoal.values)
                choice.ChoiceRow(
                  label: goal.label,
                  hint: goal.hint,
                  selected: profile.goal == goal,
                  onTap: () => notifier.setGoal(goal),
                ),
            ],
          ),
        ),

        // ACTIVITY
        _Group(
          title: 'Activity level',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final level in ActivityLevel.values)
                choice.ChoiceRow(
                  label: level.label,
                  hint: level.hint,
                  selected: profile.activityLevel == level,
                  onTap: () => notifier.setActivityLevel(level),
                ),
            ],
          ),
        ),

        // CONDITIONS
        _Group(
          title: 'Managing',
          child: choice.ChipGroup(
            children: [
              for (final condition in Condition.values)
                choice.ChoiceChip(
                  label: condition.label,
                  selected: profile.conditions.contains(condition),
                  onTap: () => notifier.toggleCondition(condition),
                ),
            ],
          ),
        ),

        // DIET
        _Group(
          title: 'Diet',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final pattern in DietPattern.values)
                choice.ChoiceRow(
                  label: pattern.label,
                  hint: pattern.hint,
                  selected: profile.effectiveDietPattern == pattern,
                  onTap: () => notifier.setDietPattern(pattern),
                ),
            ],
          ),
        ),

        // ALLERGENS
        _Group(
          title: 'Allergies',
          detail: 'Excluded outright from every food and restaurant '
              'recommendation, including on a cheat day.',
          child: choice.ChipGroup(
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
        ),

        // RESTRICTIONS
        _Group(
          title: 'Preferences',
          child: choice.ChipGroup(
            children: [
              for (final restriction in Restriction.values)
                choice.ChoiceChip(
                  label: restriction.label,
                  selected: profile.restrictions.contains(restriction),
                  onTap: () => notifier.toggleRestriction(restriction),
                ),
            ],
          ),
        ),

        // CUISINES
        _Group(
          title: 'Cuisines',
          detail: 'Tapped in order of preference — the first carries the most '
              'weight when we suggest somewhere to eat.',
          child: choice.ChipGroup(
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
        ),

        // CYCLE
        const _Group(title: 'Menstrual cycle', child: _CycleCard()),
      ],
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({
    required this.title,
    required this.child,
    this.detail,
    this.topGap = AppSpacing.space6,
  });

  final String title;
  final Widget child;
  final String? detail;
  final double topGap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.space5,
        topGap,
        AppSpacing.space5,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(title: title),
          if (detail != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.space3),
              child: Text(
                detail!,
                style: AppTextStyles.cardMeta.copyWith(
                  fontSize: 12,
                  height: 1.42,
                ),
              ),
            ),
          child,
        ],
      ),
    );
  }
}

class _BodyStats extends StatelessWidget {
  const _BodyStats({required this.bmi, required this.bmr});

  final double? bmi;
  final double? bmr;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.space4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.hairline),
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (bmi != null)
                Expanded(child: _Stat(label: 'BMI', value: '$bmi')),
              if (bmr != null)
                Expanded(
                  child: _Stat(
                    label: 'Resting burn',
                    value: '${bmr!.round()} kcal',
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.space2),
          Text(
            'BMI is a population screening tool, not a diagnosis — it says '
            'nothing about body composition, and a muscular person will read '
            '“overweight” on it.',
            style: AppTextStyles.cardMeta.copyWith(
              fontSize: 11,
              height: 1.36,
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: AppTextStyles.tag.copyWith(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            color: AppColors.faint,
          ),
        ),
        const SizedBox(height: 2),
        Text(value, style: AppTextStyles.metricSmall.copyWith(fontSize: 19)),
      ],
    );
  }
}

/// Cycle tracking, and the period-start log the phase model runs on.
///
/// It has to be logged here: HealthKit records menstrual flow, but the plugin
/// this app uses does not expose that category, so there is nothing to read.
class _CycleCard extends ConsumerWidget {
  const _CycleCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cycle = ref.watch(userProfileProvider).cycle;
    final notifier = ref.read(userProfileProvider.notifier);
    final phase = computeMenstrualPhase(cycle);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.space4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.hairline),
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            spacing: AppSpacing.space3,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.brand50,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Icon(
                  Icons.water_drop_outlined,
                  size: 18,
                  color: AppColors.brand,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Track my cycle',
                      style: AppTextStyles.cardTitle.copyWith(fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Adjusts training, calorie and food guidance by phase.',
                      style: AppTextStyles.cardMeta.copyWith(
                        fontSize: 11,
                        height: 1.36,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: cycle.tracks,
                activeTrackColor: AppColors.brand,
                onChanged: (tracks) =>
                    notifier.updateCycle(cycle.copyWith(tracks: tracks)),
              ),
            ],
          ),

          if (cycle.tracks) ...[
            Container(
              margin: const EdgeInsets.only(top: AppSpacing.space4),
              padding: const EdgeInsets.only(top: AppSpacing.space4),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.hairline)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (phase != null) ...[
                    Text(
                      phase.label,
                      style: AppTextStyles.cardTitle.copyWith(fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      phase.summary,
                      style: AppTextStyles.cardBody.copyWith(height: 1.42),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      phase.isMeasuredLength
                          ? 'Using your measured '
                                '${phase.cycleLengthDays}-day cycle.'
                          : 'Using an assumed ${phase.cycleLengthDays}-day '
                                'cycle — log two periods and we measure it '
                                'instead.',
                      style: AppTextStyles.cardMeta.copyWith(fontSize: 11),
                    ),
                    const SizedBox(height: AppSpacing.space3),
                  ] else ...[
                    Text(
                      'Log the first day of your period and we can place you in '
                      'a phase. Apple Health records this, but the library we '
                      'use to read HealthKit does not expose the '
                      'menstrual-flow category — so it has to be logged here.',
                      style: AppTextStyles.cardBody.copyWith(height: 1.42),
                    ),
                    const SizedBox(height: AppSpacing.space3),
                  ],

                  AppButton(
                    label: 'My period started today',
                    variant: AppButtonVariant.secondary,
                    size: AppButtonSize.sm,
                    block: true,
                    leading: const Icon(Icons.event_outlined, size: 14),
                    onPressed: () => _logToday(context, ref, cycle),
                  ),

                  if (cycle.periodStarts.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.space3),
                    Text(
                      'LOGGED STARTS',
                      style: AppTextStyles.tag.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                        color: AppColors.faint,
                      ),
                    ),
                    const SizedBox(height: 6),
                    for (final day
                        in ([...cycle.periodStarts]..sort()).reversed.take(4))
                      Text(
                        '• ${formatRelativeDay(day)}',
                        style: AppTextStyles.cardMeta.copyWith(fontSize: 12),
                      ),
                  ],

                  Container(
                    margin: const EdgeInsets.only(top: AppSpacing.space4),
                    padding: const EdgeInsets.only(top: AppSpacing.space3),
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: AppColors.hairline),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Hormonal contraception',
                                style: AppTextStyles.cardTitle.copyWith(
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Switch.adaptive(
                              value: cycle.hormonalContraception,
                              activeTrackColor: AppColors.brand,
                              onChanged: (value) => notifier.updateCycle(
                                cycle.copyWith(hormonalContraception: value),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'If this is on we keep phase guidance but mark it '
                          'low-confidence — a withdrawal bleed is not the same '
                          'hormonal cycle.',
                          style: AppTextStyles.cardMeta.copyWith(
                            fontSize: 11,
                            height: 1.36,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _logToday(
    BuildContext context,
    WidgetRef ref,
    CycleProfile cycle,
  ) async {
    final today = toIsoDay(DateTime.now());
    if (cycle.periodStarts.contains(today)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Today is already recorded as a period start.'),
        ),
      );
      return;
    }
    await logPeriodStart(ref);
  }
}
