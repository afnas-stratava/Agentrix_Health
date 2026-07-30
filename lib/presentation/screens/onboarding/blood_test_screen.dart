import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/status_bar_style.dart';
import '../../../domain/entities/labs/lab_report.dart';
import '../../providers/app_stage_provider.dart';
import '../../providers/labs_providers.dart';
import '../../widgets/labs/biomarker_table.dart';
import '../../widgets/labs/upload_report_actions.dart';

class BloodTestScreen extends ConsumerWidget {
  const BloodTestScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final labs = ref.watch(labsProvider);
    final report = labs.latest;

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
              Text('Add your blood test', style: AppTextStyles.h3),
              const SizedBox(height: AppSpacing.space2),
              Text(
                "We'll pull the key markers so your morning plan reflects "
                "what's actually going on in your body.",
                style: AppTextStyles.muted.copyWith(fontSize: 14),
              ),
              const SizedBox(height: AppSpacing.space5),
              Expanded(
                child: SingleChildScrollView(
                  child: report == null
                      ? const UploadReportActions()
                      : _ParsedReport(report: report),
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
                      // Skippable on purpose: blood work sharpens the brief but
                      // is not required for it, and a hard gate here would
                      // strand anyone without a recent panel.
                      label: report == null ? 'Skip for now' : 'Continue',
                      variant: report == null
                          ? AppButtonVariant.secondary
                          : AppButtonVariant.primary,
                      onPressed: labs.parsing
                          ? null
                          : () => ref
                                .read(appStageProvider.notifier)
                                .goHealthConnect(),
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

class _ParsedReport extends ConsumerWidget {
  const _ParsedReport({required this.report});

  final LabReport report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flagged = report.flagged;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.space3,
            vertical: AppSpacing.space2,
          ),
          decoration: BoxDecoration(
            color: AppColors.brand50,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            spacing: AppSpacing.space2,
            children: [
              const Icon(
                Icons.check_circle_outline,
                size: 16,
                color: AppColors.brand800,
              ),
              Expanded(
                child: Text(
                  '${report.biomarkers.length} markers read'
                  '${flagged.isEmpty ? '' : ', ${flagged.length} to watch'}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.brand800,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Every warning the parser attached, verbatim — including the standing
        // disclosure that no OCR service is configured in this build.
        for (final warning in report.warnings)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.space2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpacing.space2,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.info_outline,
                    size: 13,
                    color: AppColors.muted,
                  ),
                ),
                Expanded(
                  child: Text(
                    warning,
                    style: AppTextStyles.cardBody.copyWith(height: 1.45),
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: AppSpacing.space2),
        BiomarkerTable(report: report),
        const SizedBox(height: AppSpacing.space4),
        AppButton(
          label: 'Use a different report',
          variant: AppButtonVariant.ghost,
          block: true,
          onPressed: () => ref.read(labsProvider.notifier).remove(report.id),
        ),
      ],
    );
  }
}
