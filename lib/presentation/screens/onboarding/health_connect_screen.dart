import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/status_bar_style.dart';
import '../../../domain/entities/connected_health_app.dart';
import '../../providers/app_stage_provider.dart';
import '../../providers/health_apps_provider.dart';
import '../../providers/repository_providers.dart';

class HealthConnectScreen extends ConsumerWidget {
  const HealthConnectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apps = ref.watch(healthAppsProvider);
    final anyConnected = ref.watch(anyHealthAppConnectedProvider);
    final stats = ref.watch(dailyStatsRepositoryProvider).current();

    return StatusBarStyle(
      light: false,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.space6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Step 3 of 3',
                style: AppTextStyles.h6.copyWith(color: AppColors.accent700),
              ),
              const SizedBox(height: AppSpacing.space2),
              Text('Connect your health apps', style: AppTextStyles.h3),
              const SizedBox(height: AppSpacing.space2),
              Text(
                'Sync steps, sleep and activity so your plan updates with your body every day.',
                style: AppTextStyles.muted.copyWith(fontSize: 14),
              ),
              const SizedBox(height: AppSpacing.space4),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(color: AppColors.divider, width: 2),
                          ),
                        ),
                        child: Column(
                          children: [
                            for (final app in apps) _HealthAppRow(app: app),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.space4),
                      if (anyConnected) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.space3,
                            vertical: AppSpacing.space2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accent100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            spacing: AppSpacing.space2,
                            children: [
                              const Icon(
                                Icons.check_circle_outline,
                                size: 16,
                                color: AppColors.accent800,
                              ),
                              Text(
                                'Health data synced',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.accent800,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.space4),
                        Row(
                          spacing: AppSpacing.space2,
                          children: [
                            Expanded(
                              child: AppCard(
                                children: [
                                  Text(
                                    'Steps',
                                    style: AppTextStyles.cardKicker,
                                  ),
                                  Text(
                                    stats.stepsLabel,
                                    style: AppTextStyles.cardTitle,
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: AppCard(
                                children: [
                                  Text(
                                    'Sleep',
                                    style: AppTextStyles.cardKicker,
                                  ),
                                  Text(
                                    stats.sleepLabel,
                                    style: AppTextStyles.cardTitle,
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: AppCard(
                                children: [
                                  Text(
                                    'Burned',
                                    style: AppTextStyles.cardKicker,
                                  ),
                                  Text(
                                    stats.burnedLabel,
                                    style: AppTextStyles.cardTitle,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
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
                        ref.read(appStageProvider.notifier).goBloodTest(),
                  ),
                  Expanded(
                    child: AppButton(
                      label: 'Finish setup',
                      onPressed: anyConnected
                          ? () => ref.read(appStageProvider.notifier).goMain()
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

class _HealthAppRow extends ConsumerWidget {
  const _HealthAppRow({required this.app});

  final ConnectedHealthApp app;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.space3),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider, width: 2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            spacing: AppSpacing.space3,
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.neutral200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  app.initial,
                  style: AppTextStyles.h6.copyWith(
                    fontSize: 12,
                    letterSpacing: 0,
                  ),
                ),
              ),
              Text(
                app.name,
                style: AppTextStyles.bodySmall.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          AppButton(
            label: app.connected ? 'Connected' : 'Connect',
            variant: app.connected
                ? AppButtonVariant.primary
                : AppButtonVariant.secondary,
            onPressed: () =>
                ref.read(healthAppsProvider.notifier).toggle(app.id),
          ),
        ],
      ),
    );
  }
}
