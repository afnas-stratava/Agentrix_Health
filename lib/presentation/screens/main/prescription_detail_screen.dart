import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_tag.dart';
import '../../../domain/entities/labs/lab_report.dart' show ParseStatus;
import '../../../domain/entities/prescriptions/prescription.dart';
import '../../providers/prescriptions_providers.dart';
import 'main_shell.dart';

/// A single prescription. Mirrors `lab_report_screen.dart` — same header/tag/
/// warning/delete structure — but medications have no category or reference
/// range to group by, so they render as one flat list.
class PrescriptionDetailScreen extends ConsumerWidget {
  const PrescriptionDetailScreen({super.key, required this.prescriptionId});

  final String prescriptionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prescription = ref
        .watch(prescriptionsProvider)
        .prescriptions
        .where((p) => p.id == prescriptionId)
        .firstOrNull;

    // The prescription can vanish underneath this screen if it is deleted
    // elsewhere.
    if (prescription == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.space6),
          child: Text(
            'This prescription is no longer on your device.',
            textAlign: TextAlign.center,
            style: AppTextStyles.cardBody,
          ),
        ),
      );
    }

    final date = prescription.prescribedAt ?? prescription.uploadedAt;

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
                      prescription.clinicName ??
                          prescription.fileName ??
                          'Prescription',
                      style: AppTextStyles.h3.copyWith(
                        fontSize: 24,
                        height: 1.17,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${prescription.prescriberName != null ? '${prescription.prescriberName} · ' : ''}'
                      '${prescription.prescribedAt != null ? 'Prescribed' : 'Uploaded'} '
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
              label:
                  '${prescription.medications.length} '
                  'medicine${prescription.medications.length == 1 ? '' : 's'}',
              variant: AppTagVariant.neutral,
            ),
            if (prescription.status == ParseStatus.needsReview)
              const AppTag(
                label: 'Needs review',
                variant: AppTagVariant.accent,
              ),
          ],
        ),

        if (prescription.status == ParseStatus.needsReview)
          const Padding(
            padding: EdgeInsets.only(top: AppSpacing.space4),
            child: _Notice(
              text: 'Some rows were extracted with low confidence. Check '
                  'anything marked below against the original document before '
                  'acting on it.',
            ),
          ),

        // Parser warnings, verbatim — including the standing disclosure that
        // no OCR service is configured in this build.
        for (final warning in prescription.warnings)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.space3),
            child: _Notice(text: warning),
          ),

        const SizedBox(height: AppSpacing.space4),

        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (final medication in prescription.medications)
                _MedicationRow(
                  medication: medication,
                  isLast: medication == prescription.medications.last,
                ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.space8),
        Center(
          child: AppButton(
            label: 'Delete prescription',
            variant: AppButtonVariant.danger,
            leading: const Icon(Icons.delete_outline, size: 15),
            onPressed: () => _confirmDelete(context, ref, prescription),
          ),
        ),

        const SizedBox(height: AppSpacing.space5),
        Text(
          'This is a transcription of what the document shows, not medical '
          'advice. Confirm doses against the original before acting on them.',
          textAlign: TextAlign.center,
          style: AppTextStyles.cardMeta.copyWith(fontSize: 11, height: 1.4),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Prescription prescription,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this prescription?'),
        content: const Text(
          'The extracted medicines and the stored file are removed from this '
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
    await ref.read(prescriptionsProvider.notifier).remove(prescription.id);
    if (context.mounted) Navigator.of(context).maybePop();
  }
}

class _MedicationRow extends StatelessWidget {
  const _MedicationRow({required this.medication, required this.isLast});

  final Medication medication;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: AppColors.hairline)),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space4,
        vertical: AppSpacing.space3,
      ),
      child: Row(
        spacing: AppSpacing.space3,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.brand50,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Icon(
              Icons.medication_outlined,
              size: 16,
              color: AppColors.brand,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  medication.name,
                  style: AppTextStyles.cardTitle.copyWith(fontSize: 14),
                ),
                if (medication.doseLine.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    medication.doseLine,
                    style: AppTextStyles.cardMeta.copyWith(height: 1.4),
                  ),
                ],
                if (medication.duration != null ||
                    medication.instructions != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    [
                      medication.duration,
                      medication.instructions,
                    ].where((s) => s != null && s.isNotEmpty).join(' · '),
                    style: AppTextStyles.cardMeta.copyWith(
                      height: 1.4,
                      color: AppColors.faint,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
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
