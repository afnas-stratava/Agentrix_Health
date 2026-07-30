import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/segmented_control.dart';
import '../../../domain/entities/labs/lab_report.dart';
import '../../providers/labs_providers.dart';
import '../../widgets/labs/biomarker_table.dart';

/// A single report, in full. Ported from `app/lab/[id].tsx`.
///
/// Defaults to the flagged view rather than the whole panel: eighteen rows of
/// mostly-optimal results buries the three that matter. The full panel is one tap
/// away, because it is still the user's own data and hiding it would be wrong.
class LabReportScreen extends ConsumerStatefulWidget {
  const LabReportScreen({super.key, required this.reportId});

  final String reportId;

  @override
  ConsumerState<LabReportScreen> createState() => _LabReportScreenState();
}

class _LabReportScreenState extends ConsumerState<LabReportScreen> {
  bool _flaggedOnly = true;

  @override
  Widget build(BuildContext context) {
    final report = ref
        .watch(labsProvider)
        .reports
        .where((r) => r.id == widget.reportId)
        .firstOrNull;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.canvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          report?.panelName ?? 'Report',
          style: AppTextStyles.h5,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: report == null
          // Reachable if the report is deleted while this screen is open.
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.space6),
                child: Text(
                  'This report is no longer on your device.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.cardBody,
                ),
              ),
            )
          : _Body(
              report: report,
              flaggedOnly: _flaggedOnly,
              onToggle: (value) => setState(() => _flaggedOnly = value),
            ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.report,
    required this.flaggedOnly,
    required this.onToggle,
  });

  final LabReport report;
  final bool flaggedOnly;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = report.collectedAt ?? report.uploadedAt;
    final flagged = report.flagged.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.space5,
        0,
        AppSpacing.space5,
        AppSpacing.space8,
      ),
      children: [
        Text(
          '${DateFormat('d MMMM yyyy').format(date)}'
          '${report.collectedAt == null ? ' (uploaded)' : ' (collected)'}',
          style: AppTextStyles.muted.copyWith(fontSize: 13),
        ),
        if (report.labName != null)
          Text(report.labName!, style: AppTextStyles.cardMeta),

        const SizedBox(height: AppSpacing.space4),

        Row(
          spacing: AppSpacing.space3,
          children: [
            _Stat(
              value: '${report.biomarkers.length}',
              label: 'markers read',
            ),
            _Stat(value: '$flagged', label: 'to watch'),
            _Stat(
              value: '${(report.overallConfidence * 100).round()}%',
              label: 'confidence',
            ),
          ],
        ),

        // Every parser warning, verbatim — including the standing disclosure
        // that no OCR service is configured in this build.
        for (final warning in report.warnings)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.space3),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.space3),
              decoration: BoxDecoration(
                color: AppColors.neutral200,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
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
          ),

        const SizedBox(height: AppSpacing.space5),

        SegmentedControl<bool>(
          options: [
            SegmentedOption(value: true, label: 'To watch ($flagged)'),
            SegmentedOption(
              value: false,
              label: 'All ${report.biomarkers.length}',
            ),
          ],
          selected: flaggedOnly,
          onChanged: onToggle,
        ),

        const SizedBox(height: AppSpacing.space4),
        BiomarkerTable(report: report, flaggedOnly: flaggedOnly),

        const SizedBox(height: AppSpacing.space6),
        const SectionHeader(title: 'How to read this'),
        Text(
          'The reference interval is your lab’s own, where the report printed '
          'one. The optimal band is narrower and comes from published '
          'literature — a value can sit inside the first and outside the '
          'second, which is exactly the case worth acting on.',
          style: AppTextStyles.cardBody.copyWith(height: 1.5),
        ),

        const SizedBox(height: AppSpacing.space5),
        AppButton(
          label: 'Delete this report',
          variant: AppButtonVariant.danger,
          block: true,
          onPressed: () async {
            await ref.read(labsProvider.notifier).remove(report.id);
            if (context.mounted) Navigator.of(context).pop();
          },
        ),

        const SizedBox(height: AppSpacing.space4),
        Text(
          'Reference intervals are population defaults, not a diagnosis. '
          'Discuss anything flagged here with a clinician.',
          textAlign: TextAlign.center,
          style: AppTextStyles.cardMeta.copyWith(fontSize: 10, height: 1.5),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space3,
          vertical: AppSpacing.space3,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.hairline),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: AppTextStyles.metricSmall.copyWith(fontSize: 18),
            ),
            Text(label, style: AppTextStyles.cardMeta.copyWith(fontSize: 10)),
          ],
        ),
      ),
    );
  }
}
