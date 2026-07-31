import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/status_bar_style.dart';
import '../../providers/app_stage_provider.dart';
import '../../widgets/canvas_wash.dart';

/// Mirrors `app/onboarding/index.tsx`.
///
/// Leads with the product's actual claim rather than a feature list: a ferritin
/// of 21 is "normal", and a ferritin of 21 alongside three weeks of falling HRV
/// is a reason to act. If that sentence does not land, nothing downstream will.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  static const _points = [
    (
      Icons.monitor_heart_outlined,
      'Your daily telemetry',
      'HRV, resting heart rate, sleep stages, steps and active energy, read '
          'straight from Apple Health.',
    ),
    (
      Icons.description_outlined,
      'Your blood work',
      'Upload a lab PDF or photograph the printout. We extract every biomarker '
          'and flag it against evidence-based optimal bands.',
    ),
    (
      Icons.auto_awesome,
      'The intersection',
      'A ferritin of 21 is "normal". A ferritin of 21 alongside three weeks of '
          'falling HRV is a reason to act.',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StatusBarStyle(
      light: false,
      child: WelcomeWash(
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.space8,
                  ),
                  children: [
                    const SizedBox(height: AppSpacing.space8),
                    RichText(
                      text: TextSpan(
                        style: AppTextStyles.h1.copyWith(
                          fontSize: 40,
                          height: 1.15,
                        ),
                        children: [
                          const TextSpan(text: 'Your labs.\nYour wearable.\n'),
                          TextSpan(
                            text: 'One picture.',
                            style: AppTextStyles.h1.copyWith(
                              fontSize: 40,
                              height: 1.15,
                              color: AppColors.accent2_800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(
                      height: AppSpacing.space8 + AppSpacing.space2,
                    ),
                    for (final point in _points)
                      Padding(
                        padding: const EdgeInsets.only(
                          bottom: AppSpacing.space6,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: AppSpacing.space4,
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppColors.ink.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(
                                  AppRadius.md,
                                ),
                              ),
                              child: Icon(
                                point.$1,
                                size: 19,
                                color: AppColors.brand,
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    point.$2,
                                    style: AppTextStyles.cardTitle.copyWith(
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    point.$3,
                                    style: AppTextStyles.cardBody.copyWith(
                                      fontSize: 13,
                                      height: 1.46,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.space8,
                  0,
                  AppSpacing.space8,
                  AppSpacing.space6,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppButton(
                      label: 'Get started',
                      size: AppButtonSize.lg,
                      block: true,
                      onPressed: () =>
                          ref.read(appStageProvider.notifier).next(),
                    ),
                    const SizedBox(height: AppSpacing.space4),
                    Text(
                      'Agentrix Health is not a medical device and does not '
                      'diagnose. Always discuss results with a qualified '
                      'clinician.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.cardMeta.copyWith(
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
