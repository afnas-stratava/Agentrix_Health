import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/status_bar_style.dart';
import '../../providers/app_stage_provider.dart';

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StatusBarStyle(
      light: true,
      child: Container(
        color: AppColors.accent900,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.space6,
              AppSpacing.space8,
              AppSpacing.space6,
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
                    color: AppColors.accent2_500,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    'A',
                    style: AppTextStyles.h5.copyWith(
                      color: AppColors.accent900,
                      fontSize: 20,
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Agentrix Health',
                      style: AppTextStyles.h1.copyWith(
                        color: AppColors.bg,
                        fontSize: 38,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.space3),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 300),
                      child: Text(
                        'Your AI health assistant — a personal nutritionist, coach and wellness tracker in one place.',
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.neutral400,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppButton(
                      label: 'Get started',
                      block: true,
                      leading: const Icon(Icons.arrow_forward, size: 16),
                      onPressed: () =>
                          ref.read(appStageProvider.notifier).goForm(),
                    ),
                    const SizedBox(height: AppSpacing.space3),
                    Text(
                      'Takes about a minute',
                      style: AppTextStyles.cardMeta.copyWith(
                        color: AppColors.neutral500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
