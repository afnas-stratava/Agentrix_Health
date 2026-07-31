import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_tag.dart';
import '../../../domain/entities/labs/biomarker.dart';
import '../../../domain/entities/labs/lab_report.dart';
import '../../providers/labs_providers.dart';
import '../../widgets/labs/biomarker_table.dart';
import 'main_shell.dart';

/// A single report, grouped by panel. Mirrors `app/lab/[id].tsx`.
///
/// Categories are ordered so the panels people act on most sit at the top, and
/// within each, the worst flag first — a report read top-to-bottom should reach
/// the thing that matters before the reader loses interest.
class LabReportScreen extends ConsumerWidget {
  const LabReportScreen({super.key, required this.reportId});

  final String reportId;

  /// Ordered by how often a finding here changes what someone does.
  static const _categoryOrder = [
    BiomarkerCategory.iron,
    BiomarkerCategory.inflammation,
    BiomarkerCategory.glycemic,
    BiomarkerCategory.lipids,
    BiomarkerCategory.thyroid,
    BiomarkerCategory.micronutrient,
    BiomarkerCategory.endocrine,
    BiomarkerCategory.organ,
    BiomarkerCategory.hematology,
    BiomarkerCategory.other,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref
        .watch(labsProvider)
        .reports
        .where((r) => r.id == reportId)
        .firstOrNull;

    // The report can vanish underneath this screen if it is deleted elsewhere.
    if (report == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.space6),
          child: Text(
            'This report is no longer on your device.',
            textAlign: TextAlign.center,
            style: AppTextStyles.cardBody,
          ),
        ),
      );
    }

    final grouped = <BiomarkerCategory, List<Biomarker>>{};
    for (final biomarker in report.biomarkers) {
      grouped.putIfAbsent(biomarker.category, () => []).add(biomarker);
    }
    for (final bucket in grouped.values) {
      bucket.sort((a, b) => b.flag.severity.compareTo(a.flag.severity));
    }

    final sections = _categoryOrder
        .where(grouped.containsKey)
        .map((category) => (category: category, rows: grouped[category]!))
        .toList();

    final flaggedCount = report.flagged.length;
    final date = report.collectedAt ?? report.uploadedAt;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.space6,
        AppSpacing.space6,
        AppSpacing.space6,
        MainShell.bottomInsetFor(context),
      ),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: AppSpacing.space4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.panelName ?? report.fileName ?? 'Lab report',
                      style: AppTextStyles.h3.copyWith(
                        fontSize: 24,
                        height: 1.17,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${report.labName != null ? '${report.labName} · ' : ''}'
                      '${report.collectedAt != null ? 'Collected' : 'Uploaded'} '
                      '${DateFormat('d MMMM yyyy').format(date)}',
                      style: AppTextStyles.cardBody,
                    ),
                  ],
                ),
              ),
            ),
            AppButton.icon(
              leading: const Icon(Icons.close, size: 16),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.space4),
        Wrap(
          spacing: AppSpacing.space2,
          runSpacing: AppSpacing.space2,
          children: [
            AppTag(
              label: '${report.biomarkers.length} markers',
              variant: AppTagVariant.neutral,
            ),
            if (flaggedCount > 0)
              AppTag(
                label: '$flaggedCount outside optimal',
                variant: AppTagVariant.accent,
              ),
            if (report.status == ParseStatus.needsReview)
              const AppTag(
                label: 'Needs review',
                variant: AppTagVariant.accent,
              ),
          ],
        ),

        if (report.status == ParseStatus.needsReview)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.space4),
            child: _Notice(
              text: 'Some values were extracted with low confidence. Check '
                  'anything marked below against the original document before '
                  'acting on it — a mis-read decimal point is the difference '
                  'between normal and critical.',
            ),
          ),

        // Parser warnings, verbatim — including the standing disclosure that no
        // OCR service is configured in this build.
        for (final warning in report.warnings)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.space3),
            child: _Notice(text: warning),
          ),

        const SizedBox(height: AppSpacing.space2),

        for (final section in sections) ...[
          Padding(
            padding: const EdgeInsets.only(
              top: AppSpacing.space4,
              bottom: AppSpacing.space2,
            ),
            child: Text(
              section.category.label.toUpperCase(),
              style: AppTextStyles.tag.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.55,
                color: AppColors.muted,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final biomarker in section.rows)
                  BiomarkerRow(
                    biomarker: biomarker,
                    isLast: biomarker == section.rows.last,
                  ),
              ],
            ),
          ),
        ],

        const SizedBox(height: AppSpacing.space8),
        Center(
          child: AppButton(
            label: 'Delete report',
            variant: AppButtonVariant.danger,
            leading: const Icon(Icons.delete_outline, size: 15),
            onPressed: () => _confirmDelete(context, ref, report),
          ),
        ),

        const SizedBox(height: AppSpacing.space5),
        Text(
          'Reference intervals shown are the lab’s own where printed, with an '
          'evidence-based optimal band layered on top. Neither replaces '
          'clinical interpretation.',
          textAlign: TextAlign.center,
          style: AppTextStyles.cardMeta.copyWith(fontSize: 11, height: 1.4),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    LabReport report,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this report?'),
        content: const Text(
          'The extracted values and the stored file are removed from this '
          'device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    HapticFeedback.mediumImpact();
    await ref.read(labsProvider.notifier).remove(report.id);
    if (context.mounted) Navigator.of(context).maybePop();
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.space4),
      decoration: BoxDecoration(
        color: AppColors.ink.withValues(alpha: 0.04),
        border: Border.all(color: AppColors.hairline),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Text(
        text,
        style: AppTextStyles.cardBody.copyWith(fontSize: 13, height: 1.46),
      ),
    );
  }
}
