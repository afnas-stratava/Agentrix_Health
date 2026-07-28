import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/segmented_control.dart';
import '../../../core/widgets/status_bar_style.dart';
import '../../../domain/entities/gender.dart';
import '../../../domain/entities/health_goal.dart';
import '../../providers/app_stage_provider.dart';
import '../../providers/user_profile_provider.dart';

class PersonalInfoScreen extends ConsumerWidget {
  const PersonalInfoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);
    final notifier = ref.read(userProfileProvider.notifier);

    return StatusBarStyle(
      light: false,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.space6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Step 1 of 3',
                style: AppTextStyles.h6.copyWith(color: AppColors.accent700),
              ),
              const SizedBox(height: AppSpacing.space2),
              Text('Tell us about you', style: AppTextStyles.h3),
              const SizedBox(height: AppSpacing.space6),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppTextField(
                        label: 'Name',
                        value: profile.name,
                        placeholder: 'Your name',
                        onChanged: notifier.setName,
                      ),
                      const SizedBox(height: AppSpacing.space4),
                      AppTextField(
                        label: 'Age',
                        value: profile.age,
                        placeholder: 'Your age',
                        keyboardType: TextInputType.number,
                        onChanged: notifier.setAge,
                      ),
                      const SizedBox(height: AppSpacing.space4),
                      Text('Gender', style: AppTextStyles.fieldLabel),
                      const SizedBox(height: 5),
                      SegmentedControl<Gender>(
                        expand: true,
                        selected: profile.gender,
                        options: const [
                          SegmentedOption(
                            value: Gender.female,
                            label: 'Female',
                          ),
                          SegmentedOption(value: Gender.male, label: 'Male'),
                        ],
                        onChanged: notifier.setGender,
                      ),
                      const SizedBox(height: AppSpacing.space4),
                      Text('Health goal', style: AppTextStyles.fieldLabel),
                      const SizedBox(height: AppSpacing.space2),
                      Column(
                        spacing: AppSpacing.space2,
                        children: [
                          for (final goal in HealthGoal.values)
                            AppButton(
                              label: goal.label,
                              block: true,
                              variant: goal == profile.goal
                                  ? AppButtonVariant.primary
                                  : AppButtonVariant.secondary,
                              onPressed: () => notifier.setGoal(goal),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: AppSpacing.space4 * 2, thickness: 2),
              Row(
                spacing: AppSpacing.space2,
                children: [
                  AppButton(
                    label: 'Back',
                    variant: AppButtonVariant.ghost,
                    onPressed: () =>
                        ref.read(appStageProvider.notifier).goWelcome(),
                  ),
                  Expanded(
                    child: AppButton(
                      label: 'Continue',
                      onPressed: profile.isComplete
                          ? () => ref
                                .read(appStageProvider.notifier)
                                .goBloodTest()
                          : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
