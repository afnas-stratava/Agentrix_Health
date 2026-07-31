import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../providers/app_stage_provider.dart';

/// Shared frame for the onboarding steps.
///
/// Every step is back-arrow, scrollable body, pinned footer — extracted because
/// five near-identical scaffolds drift apart the moment one of them is edited,
/// and the footer's disabled-with-a-reason behaviour is the part most worth
/// having in exactly one place.
class OnboardingScaffold extends ConsumerWidget {
  const OnboardingScaffold({
    super.key,
    required this.title,
    required this.children,
    this.intro,
    this.continueLabel = 'Continue',
    this.onContinue,
    this.canContinue = true,
    this.blockedHint,
    this.footerNote,
    this.secondary,
    this.showBack = true,
    this.stepIndex,
    this.stepCount,
  });

  final String title;
  final String? intro;
  final List<Widget> children;

  final String continueLabel;

  /// Defaults to advancing one step.
  final VoidCallback? onContinue;

  final bool canContinue;

  /// Shown under a disabled Continue. A blocked button with no stated reason is
  /// the single most common dead end in a signup flow.
  final String? blockedHint;

  /// Shown under an enabled Continue.
  final String? footerNote;

  /// An optional second action below Continue, e.g. "Skip for now".
  final Widget? secondary;

  final bool showBack;
  final int? stepIndex;
  final int? stepCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showBack)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.space6,
                AppSpacing.space2,
                AppSpacing.space6,
                0,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: AppButton.icon(
                  leading: const Icon(Icons.arrow_back, size: 16),
                  onPressed: () => ref.read(appStageProvider.notifier).back(),
                ),
              ),
            ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.space8,
                AppSpacing.space6,
                AppSpacing.space8,
                AppSpacing.space6,
              ),
              children: [
                if (stepCount != null && stepIndex != null) ...[
                  Text(
                    'Step $stepIndex of $stepCount',
                    style: AppTextStyles.tag.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.55,
                      color: AppColors.brand,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.space2),
                ],
                Text(
                  title,
                  style: AppTextStyles.h2.copyWith(fontSize: 28, height: 1.14),
                ),
                if (intro != null) ...[
                  const SizedBox(height: AppSpacing.space3),
                  Text(
                    intro!,
                    style: AppTextStyles.cardBody.copyWith(
                      fontSize: 13,
                      height: 1.54,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.space6 + AppSpacing.space1),
                ...children,
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.space8,
              AppSpacing.space2,
              AppSpacing.space8,
              AppSpacing.space6,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppButton(
                  label: continueLabel,
                  size: AppButtonSize.lg,
                  block: true,
                  onPressed: canContinue
                      ? (onContinue ??
                            () => ref.read(appStageProvider.notifier).next())
                      : null,
                ),
                if (secondary != null) ...[
                  const SizedBox(height: AppSpacing.space2),
                  secondary!,
                ],
                if (!canContinue && blockedHint != null) ...[
                  const SizedBox(height: AppSpacing.space3),
                  Text(
                    blockedHint!,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.cardMeta.copyWith(fontSize: 11),
                  ),
                ] else if (footerNote != null) ...[
                  const SizedBox(height: AppSpacing.space3),
                  Text(
                    footerNote!,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.cardMeta.copyWith(fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Uppercase micro-label used between groups within a step.
class OnboardingLabel extends StatelessWidget {
  const OnboardingLabel(this.label, {super.key, this.detail, this.icon});

  final String label;
  final String? detail;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.space6 + AppSpacing.space1,
        bottom: AppSpacing.space3,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            spacing: AppSpacing.space2,
            children: [
              if (icon != null) Icon(icon, size: 15, color: AppColors.critical),
              Text(
                label.toUpperCase(),
                style: AppTextStyles.tag.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.55,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
          if (detail != null) ...[
            const SizedBox(height: AppSpacing.space3),
            Text(
              detail!,
              style: AppTextStyles.cardMeta.copyWith(
                fontSize: 12,
                height: 1.42,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
