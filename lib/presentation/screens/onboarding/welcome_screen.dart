import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/status_bar_style.dart';
import '../../providers/app_stage_provider.dart';

/// Mirrors the React Native welcome screen (`app/onboarding/index.tsx`): the
/// near-white canvas with a soft lime glow bleeding off the top-right corner,
/// ink display copy, and the lime CTA pinned to the bottom.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenWidth = MediaQuery.sizeOf(context).width;

    return StatusBarStyle(
      light: false,
      child: Container(
        color: AppColors.canvas,
        child: Stack(
          children: [
            // Decorative only — sits behind everything and takes no hits.
            Positioned(
              top: -screenWidth * 0.5,
              right: -screenWidth * 0.3,
              child: IgnorePointer(
                child: Container(
                  width: screenWidth * 1.3,
                  height: screenWidth * 1.3,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0x59CDEBB8), // #CDEBB8 at 35%
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.space8,
                  AppSpacing.space8,
                  AppSpacing.space8,
                  AppSpacing.space6,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.lime,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Text(
                        'A',
                        style: AppTextStyles.h5.copyWith(
                          color: AppColors.ink,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Agentrix Health',
                          style: AppTextStyles.h1.copyWith(
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.space3),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 320),
                          child: Text(
                            'Your AI health assistant — a personal nutritionist, coach and wellness tracker in one place.',
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.muted,
                              fontSize: 16,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AppButton(
                          label: 'Get started',
                          block: true,
                          size: AppButtonSize.lg,
                          leading: const Icon(Icons.arrow_forward),
                          onPressed: () =>
                              ref.read(appStageProvider.notifier).goForm(),
                        ),
                        const SizedBox(height: AppSpacing.space4),
                        Text(
                          'Takes about a minute',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.cardMeta.copyWith(fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
