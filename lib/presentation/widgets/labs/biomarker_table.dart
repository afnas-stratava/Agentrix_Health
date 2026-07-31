import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../domain/entities/labs/biomarker.dart';
import '../../../domain/entities/labs/lab_report.dart';

Color flagColour(BiomarkerFlag flag) => switch (flag) {
  BiomarkerFlag.criticalLow || BiomarkerFlag.criticalHigh => AppColors.critical,
  BiomarkerFlag.low || BiomarkerFlag.high => AppColors.abnormal,
  BiomarkerFlag.borderlineLow ||
  BiomarkerFlag.borderlineHigh => AppColors.borderline,
  BiomarkerFlag.optimal => AppColors.optimal,
  BiomarkerFlag.normal => AppColors.normal,
  BiomarkerFlag.unknown => AppColors.faint,
};

/// A parsed panel, grouped by category and led by what needs attention.
///
/// The "below optimal" rows are the point of the screen: those are the values a
/// lab report prints in black because they are inside the reference interval, and
/// which still explain how someone feels.
class BiomarkerTable extends StatelessWidget {
  const BiomarkerTable({
    super.key,
    required this.report,
    this.flaggedOnly = false,
  });

  final LabReport report;
  final bool flaggedOnly;

  @override
  Widget build(BuildContext context) {
    final rows = flaggedOnly ? report.flagged : report.biomarkers;
    if (rows.isEmpty) {
      return Text(
        'Nothing outside its optimal band in this panel.',
        style: AppTextStyles.cardBody.copyWith(height: 1.45),
      );
    }

    final byCategory = <BiomarkerCategory, List<Biomarker>>{};
    for (final biomarker in rows) {
      byCategory.putIfAbsent(biomarker.category, () => []).add(biomarker);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry in byCategory.entries) ...[
          Padding(
            padding: const EdgeInsets.only(
              top: AppSpacing.space3,
              bottom: AppSpacing.space2,
            ),
            child: Text(
              entry.key.label.toUpperCase(),
              style: AppTextStyles.tag.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                color: AppColors.muted,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.hairline),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final biomarker in entry.value)
                  BiomarkerRow(
                    biomarker: biomarker,
                    isLast: biomarker == entry.value.last,
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// One analyte: its name, the interval it was judged against, its value and
/// flag.
///
/// Public because the report screen groups rows by panel itself and needs the
/// same row rendering without the table's own grouping.
class BiomarkerRow extends StatelessWidget {
  const BiomarkerRow({
    super.key,
    required this.biomarker,
    required this.isLast,
  });

  final Biomarker biomarker;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final colour = flagColour(biomarker.flag);
    final range = biomarker.range;

    final rangeLabel = switch ((range.low, range.high)) {
      (null, null) => null,
      (final low?, null) => '≥ $low',
      (null, final high?) => '≤ $high',
      (final low?, final high?) => '$low–$high',
    };

    final optimalLabel = switch ((range.optimalLow, range.optimalHigh)) {
      (null, null) => null,
      (final low?, null) => 'optimal ≥ $low',
      (null, final high?) => 'optimal ≤ $high',
      (final low?, final high?) => 'optimal $low–$high',
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space3,
        vertical: AppSpacing.space3,
      ),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: AppColors.hairline, width: 1),
              ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.space3,
        children: [
          Container(
            width: 3,
            height: 30,
            decoration: BoxDecoration(
              color: colour,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  biomarker.displayName,
                  style: AppTextStyles.bodySmall.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  [
                    if (rangeLabel != null) 'ref $rangeLabel',
                    ?optimalLabel,
                  ].join(' · '),
                  style: AppTextStyles.cardMeta.copyWith(fontSize: 10),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                biomarker.valueWithUnit,
                style: AppTextStyles.h6.copyWith(
                  fontSize: 13,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                biomarker.flag.label,
                style: AppTextStyles.cardMeta.copyWith(
                  fontSize: 10,
                  color: colour,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
