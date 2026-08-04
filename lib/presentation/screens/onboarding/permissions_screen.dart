import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../providers/app_stage_provider.dart';
import '../../providers/health_providers.dart';
import 'onboarding_scaffold.dart';

/// Mirrors `app/onboarding/permissions.tsx`.
///
/// The system sheet can only be shown once per install. This screen exists to
/// explain *why* before that single shot is spent — a denial here is effectively
/// permanent short of a trip into iOS Settings.
class PermissionsScreen extends ConsumerStatefulWidget {
  const PermissionsScreen({super.key});

  @override
  ConsumerState<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends ConsumerState<PermissionsScreen> {
  bool _requesting = false;

  static String get _storeName => healthStoreName;

  static const _scopes = [
    (
      Icons.monitor_heart_outlined,
      'Heart rate variability',
      'The primary recovery signal',
    ),
    (
      Icons.favorite_outline,
      'Resting heart rate',
      'Confirms what HRV is telling us',
    ),
    (
      Icons.bedtime_outlined,
      'Sleep analysis',
      'Duration, stages and consistency',
    ),
    (
      Icons.local_fire_department_outlined,
      'Active energy',
      'Training load against recovery',
    ),
    (Icons.directions_walk, 'Steps', 'Baseline movement volume'),
  ];

  Future<void> _connect() async {
    setState(() => _requesting = true);
    await requestHealthAccess(ref);
    if (!mounted) return;
    setState(() => _requesting = false);
    ref.read(appStageProvider.notifier).goMain();
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      stepIndex: 5,
      stepCount: 6,
      title: 'Connect $_storeName',
      intro:
          'We read five metrics and only read them. We never write back to '
          '$_storeName, and you can skip this step and continue later.',
      continueLabel: _requesting
          ? 'Asking $_storeName…'
          : 'Connect $_storeName',
      canContinue: !_requesting,
      onContinue: _connect,
      secondary: AppButton(
        label: 'Skip for now',
        variant: AppButtonVariant.ghost,
        size: AppButtonSize.sm,
        block: true,
        onPressed: () => ref.read(appStageProvider.notifier).goMain(),
      ),
      children: [
        for (final scope in _scopes)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.space4),
            child: Row(
              spacing: 14,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.ink.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(scope.$1, size: 18, color: AppColors.brand),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        scope.$2,
                        style: AppTextStyles.cardTitle.copyWith(fontSize: 14),
                      ),
                      Text(
                        scope.$3,
                        style: AppTextStyles.cardMeta.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        Container(
          margin: const EdgeInsets.only(top: AppSpacing.space4),
          padding: const EdgeInsets.all(AppSpacing.space4),
          decoration: BoxDecoration(
            color: AppColors.ink.withValues(alpha: 0.04),
            border: Border.all(color: AppColors.hairline),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: AppSpacing.space3,
            children: [
              const Icon(
                Icons.lock_outline,
                size: 16,
                color: AppColors.optimal,
              ),
              Expanded(
                child: Text(
                  'Health data is processed entirely on this device. It is '
                  'never uploaded, and the correlation engine runs locally.',
                  style: AppTextStyles.cardMeta.copyWith(
                    fontSize: 12,
                    height: 1.42,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
