import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/status_bar_style.dart';
import '../../../domain/entities/health/metric_key.dart';
import '../../providers/app_stage_provider.dart';
import '../../providers/health_providers.dart';

/// Connects Apple Health (or Health Connect on Android).
///
/// This screen used to list four providers with buttons that flipped a boolean.
/// It now asks the platform for real read access, and reports honestly when a
/// platform store is not available — on the simulator, on the web, or on a device
/// without Health Connect — rather than showing a "Connected" pill over synthetic
/// data.
///
/// Fitbit and Oura are deliberately absent: both need a server-side OAuth
/// exchange this build has no backend for, and listing them as tappable would be
/// the same lie the old screen told.
class HealthConnectScreen extends ConsumerStatefulWidget {
  const HealthConnectScreen({super.key});

  @override
  ConsumerState<HealthConnectScreen> createState() =>
      _HealthConnectScreenState();
}

class _HealthConnectScreenState extends ConsumerState<HealthConnectScreen> {
  HealthPermissionState? _result;
  bool _requesting = false;

  static String get _platformName {
    if (kIsWeb) return 'Apple Health';
    if (Platform.isAndroid) return 'Health Connect';
    return 'Apple Health';
  }

  Future<void> _connect() async {
    setState(() => _requesting = true);
    final result = await requestHealthAccess(ref);
    if (!mounted) return;
    setState(() {
      _requesting = false;
      _result = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final seriesAsync = ref.watch(healthSeriesProvider);
    final source = ref.watch(telemetrySourceProvider);
    final days = seriesAsync.valueOrNull?.length ?? 0;

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
              Text('Connect your health data', style: AppTextStyles.h3),
              const SizedBox(height: AppSpacing.space2),
              Text(
                'Sleep, heart-rate variability, resting heart rate, steps and '
                'active energy. Read-only — nothing is written back, and none of '
                'it leaves your phone.',
                style: AppTextStyles.muted.copyWith(fontSize: 14),
              ),
              const SizedBox(height: AppSpacing.space5),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _MetricList(),
                      const SizedBox(height: AppSpacing.space4),
                      AppButton(
                        label: _requesting
                            ? 'Asking $_platformName…'
                            : 'Connect $_platformName',
                        block: true,
                        leading: const Icon(Icons.favorite_outline, size: 16),
                        onPressed: _requesting ? null : _connect,
                      ),
                      if (_result != null) ...[
                        const SizedBox(height: AppSpacing.space3),
                        _ResultNotice(result: _result!),
                      ],
                      if (days > 0) ...[
                        const SizedBox(height: AppSpacing.space4),
                        _SeriesNotice(
                          days: days,
                          synthetic: source == TelemetrySource.synthetic,
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
                      // Never gated on a permission grant: the app is fully
                      // usable on the synthetic series, and holding setup hostage
                      // to a system dialog is how onboarding gets abandoned.
                      label: 'Finish setup',
                      onPressed: () =>
                          ref.read(appStageProvider.notifier).goMain(),
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

class _MetricList extends StatelessWidget {
  static const _rows = [
    (Icons.monitor_heart_outlined, 'Heart-rate variability', '40% of readiness'),
    (Icons.favorite_outline, 'Resting heart rate', '25% of readiness'),
    (Icons.bedtime_outlined, 'Sleep stages & duration', '35% of readiness'),
    (Icons.directions_walk, 'Steps & active energy', 'Sets your daily targets'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.hairline),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final row in _rows)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.space4,
                vertical: AppSpacing.space3,
              ),
              decoration: BoxDecoration(
                border: row == _rows.last
                    ? null
                    : const Border(
                        bottom: BorderSide(
                          color: AppColors.hairline,
                          width: 1,
                        ),
                      ),
              ),
              child: Row(
                spacing: AppSpacing.space3,
                children: [
                  Icon(row.$1, size: 17, color: AppColors.brand),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          row.$2,
                          style: AppTextStyles.bodySmall.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(row.$3, style: AppTextStyles.cardMeta),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ResultNotice extends StatelessWidget {
  const _ResultNotice({required this.result});

  final HealthPermissionState result;

  @override
  Widget build(BuildContext context) {
    final (icon, colour, message) = switch (result) {
      HealthPermissionState.granted => (
        Icons.check_circle_outline,
        AppColors.brand800,
        'Connected. Your own numbers will replace the sample series on the '
            'next refresh.',
      ),
      HealthPermissionState.undetermined => (
        Icons.info_outline,
        AppColors.muted,
        'Apple Health never confirms read access — that is by design, so an app '
            'cannot tell whether you simply have no data. Pull to refresh on Home '
            'and your own numbers will appear if there are any.',
      ),
      HealthPermissionState.denied => (
        Icons.block_outlined,
        AppColors.abnormal,
        'Access declined. The app works on a sample series — you can change '
            'this any time in Settings › Privacy › Health.',
      ),
      HealthPermissionState.unavailable => (
        Icons.phonelink_off_outlined,
        AppColors.muted,
        'No health store on this device — the simulator and the web build have '
            'none. Everything runs on the sample series instead.',
      ),
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.space2,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 14, color: colour),
        ),
        Expanded(
          child: Text(
            message,
            style: AppTextStyles.cardBody.copyWith(height: 1.45),
          ),
        ),
      ],
    );
  }
}

class _SeriesNotice extends StatelessWidget {
  const _SeriesNotice({required this.days, required this.synthetic});

  final int days;
  final bool synthetic;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.space3),
      decoration: BoxDecoration(
        color: synthetic ? AppColors.neutral200 : AppColors.brand50,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        spacing: AppSpacing.space2,
        children: [
          Icon(
            synthetic ? Icons.science_outlined : Icons.watch_outlined,
            size: 15,
            color: synthetic ? AppColors.muted : AppColors.brand,
          ),
          Expanded(
            child: Text(
              synthetic
                  ? '$days days of sample telemetry loaded — enough for '
                        'readiness, targets and the brief to be real.'
                  : '$days days of your own telemetry loaded.',
              style: AppTextStyles.cardBody.copyWith(height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}
