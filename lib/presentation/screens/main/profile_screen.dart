import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_tag.dart';
import '../../providers/demo_reset_provider.dart';
import '../../providers/health_apps_provider.dart';
import '../../providers/notification_time_provider.dart';
import '../../providers/repository_providers.dart';
import '../../providers/user_profile_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);
    final apps = ref.watch(healthAppsProvider);
    final history = ref.watch(bloodTestRepositoryProvider).history();
    final timeLabel = ref.watch(briefTimeLabelProvider);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            spacing: AppSpacing.space3,
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.accent900,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  profile.initial,
                  style: AppTextStyles.h4.copyWith(
                    color: AppColors.accent2_400,
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(profile.greetingName, style: AppTextStyles.h4),
                  Text(
                    '${profile.age.isNotEmpty ? '${profile.age} · ' : ''}${profile.goal.label}',
                    style: AppTextStyles.muted.copyWith(fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space6),
          Text('Connected devices', style: AppTextStyles.h6),
          const SizedBox(height: AppSpacing.space2),
          Table(
            children: [
              for (final app in apps)
                TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.space2,
                      ),
                      child: Text(
                        app.name,
                        style: AppTextStyles.bodySmall.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.space2,
                      ),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: AppTag(
                          label: app.connected ? 'Connected' : 'Not connected',
                          variant: app.connected
                              ? AppTagVariant.accent
                              : AppTagVariant.neutral,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.space6),
          Text('Blood test history', style: AppTextStyles.h6),
          const SizedBox(height: AppSpacing.space2),
          Table(
            children: [
              for (final record in history)
                TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.space2,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            record.label,
                            style: AppTextStyles.bodySmall.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            record.date,
                            style: AppTextStyles.cardMeta.copyWith(
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.space2,
                      ),
                      child: const Align(
                        alignment: Alignment.centerRight,
                        child: Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: AppColors.accent700,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.space6),
          Text('Notifications', style: AppTextStyles.h6),
          const SizedBox(height: AppSpacing.space2),
          Container(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.space3),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: AppColors.divider, width: 2),
                bottom: BorderSide(color: AppColors.divider, width: 2),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Morning brief time',
                  style: AppTextStyles.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Row(
                  spacing: AppSpacing.space2,
                  children: [
                    AppButton.icon(
                      leading: const Icon(Icons.remove, size: 16),
                      onPressed: () => ref
                          .read(notificationTimeIndexProvider.notifier)
                          .decrement(),
                    ),
                    SizedBox(
                      width: 70,
                      child: Text(
                        timeLabel,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.h6.copyWith(
                          letterSpacing: 0,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    AppButton.icon(
                      leading: const Icon(Icons.add, size: 16),
                      onPressed: () => ref
                          .read(notificationTimeIndexProvider.notifier)
                          .increment(),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.space6),
          AppButton(
            label: 'Reset demo',
            variant: AppButtonVariant.secondary,
            block: true,
            onPressed: () => resetDemo(ref),
          ),
        ],
      ),
    );
  }
}
