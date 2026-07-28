import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_tag.dart';
import '../../../core/widgets/status_bar_style.dart';
import '../../../domain/entities/blood_marker.dart';
import '../../providers/app_stage_provider.dart';
import '../../providers/blood_test_provider.dart';

class BloodTestScreen extends ConsumerWidget {
  const BloodTestScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bloodTest = ref.watch(bloodTestProvider);

    return StatusBarStyle(
      light: false,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.space6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Step 2 of 3',
                style: AppTextStyles.h6.copyWith(color: AppColors.accent700),
              ),
              const SizedBox(height: AppSpacing.space2),
              Text('Upload your blood test', style: AppTextStyles.h3),
              const SizedBox(height: AppSpacing.space2),
              Text(
                "We'll pull key markers so your morning plan reflects what's actually going on in your body.",
                style: AppTextStyles.muted.copyWith(fontSize: 14),
              ),
              const SizedBox(height: AppSpacing.space6),
              Expanded(
                child: SingleChildScrollView(
                  child: bloodTest.uploaded
                      ? _UploadedContent(markers: bloodTest.markers)
                      : _EmptyContent(
                          onUseSample: () => ref
                              .read(bloodTestProvider.notifier)
                              .useSampleReport(),
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
                        ref.read(appStageProvider.notifier).goForm(),
                  ),
                  Expanded(
                    child: AppButton(
                      label: 'Continue',
                      onPressed: bloodTest.uploaded
                          ? () => ref
                                .read(appStageProvider.notifier)
                                .goHealthConnect()
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

class _EmptyContent extends StatelessWidget {
  const _EmptyContent({required this.onUseSample});

  final VoidCallback onUseSample;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.space4,
            vertical: AppSpacing.space8,
          ),
          decoration: BoxDecoration(
            border: Border.all(
              color: AppColors.divider,
              style: BorderStyle.solid,
              width: 1,
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: [
              const Icon(
                Icons.upload_file_outlined,
                size: 28,
                color: AppColors.accent700,
              ),
              const SizedBox(height: AppSpacing.space2),
              Text(
                'Drop a PDF or photo here',
                style: AppTextStyles.bodySmall.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.space1),
              Text('or', style: AppTextStyles.muted.copyWith(fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.space4),
        AppButton(
          label: 'Use sample report (demo)',
          block: true,
          leading: const Icon(Icons.science_outlined, size: 16),
          onPressed: onUseSample,
        ),
      ],
    );
  }
}

class _UploadedContent extends StatelessWidget {
  const _UploadedContent({required this.markers});

  final List<BloodMarker> markers;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
                'Blood report analyzed',
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
        Table(
          columnWidths: const {
            0: FlexColumnWidth(1.4),
            1: FlexColumnWidth(1.2),
            2: FlexColumnWidth(1),
          },
          children: [
            TableRow(
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.divider, width: 2),
                ),
              ),
              children: [
                _headerCell('Marker'),
                _headerCell('Value'),
                _headerCell('Status'),
              ],
            ),
            for (final marker in markers)
              TableRow(
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: AppColors.divider, width: 1),
                  ),
                ),
                children: [
                  _cell(
                    Text(
                      marker.label,
                      style: AppTextStyles.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  _cell(
                    Text(
                      marker.value,
                      style: AppTextStyles.muted.copyWith(fontSize: 14),
                    ),
                  ),
                  _cell(
                    AppTag(
                      label: marker.status.label,
                      variant: marker.status.needsAttention
                          ? AppTagVariant.accent
                          : AppTagVariant.neutral,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }

  Widget _headerCell(String label) {
    return _cell(
      Text(
        label.toUpperCase(),
        style: AppTextStyles.cardMeta.copyWith(
          fontSize: 11,
          letterSpacing: 1,
          color: AppColors.text.withValues(alpha: 0.6),
        ),
      ),
    );
  }

  Widget _cell(Widget child) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.space2),
      child: Align(alignment: Alignment.centerLeft, child: child),
    );
  }
}
