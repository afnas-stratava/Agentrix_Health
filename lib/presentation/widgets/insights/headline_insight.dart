import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/pressable_scale.dart';
import '../../../domain/entities/insights/insight.dart';
import '../labs/biomarker_table.dart';

/// Mirrors `src/components/insights/HeadlineInsight.tsx`.
///
/// The single most important finding, given the most prominent slot on the
/// dashboard after readiness.
///
/// It leads with the *evidence* — the biomarker value and the telemetry drift
/// side by side — because that pairing is the only thing here that neither Apple
/// Health nor a lab portal can show on its own.
class HeadlineInsight extends StatelessWidget {
  const HeadlineInsight({
    super.key,
    required this.insight,
    required this.onTap,
  });

  final Insight insight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final severity = insight.severity.color;

    return PressableScale(
      scaleTo: 0.99,
      semanticLabel: '${insight.severity.label}: ${insight.title}',
      semanticHint: 'Opens the full finding and what to do about it',
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.hairline),
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Severity is carried by both the rail and the text badge, so the
            // cue survives greyscale and colour-blind viewing.
            Container(height: 4, color: severity),

            Padding(
              padding: const EdgeInsets.all(AppSpacing.space5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: severity.withValues(alpha: 0.12),
                        border: Border.all(
                          color: severity.withValues(alpha: 0.33),
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        spacing: 6,
                        children: [
                          Icon(Icons.auto_awesome, size: 11, color: severity),
                          Text(
                            insight.severity.label.toUpperCase(),
                            style: AppTextStyles.tag.copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: severity,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),
                  Text(
                    insight.title,
                    style: AppTextStyles.h4.copyWith(
                      fontSize: 18,
                      height: 24 / 18,
                    ),
                  ),

                  const SizedBox(height: AppSpacing.space2),
                  Text(
                    insight.summary,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.cardBody.copyWith(
                      height: 19 / 13,
                      color: AppColors.ink.withValues(alpha: 0.65),
                    ),
                  ),

                  // Evidence: the lab side.
                  if (insight.evidence.biomarkers.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final biomarker
                            in insight.evidence.biomarkers.take(3))
                          _BiomarkerChip(biomarker: biomarker),
                      ],
                    ),
                  ],

                  // Evidence: the telemetry side.
                  if (insight.evidence.telemetryNote != null) ...[
                    const SizedBox(height: AppSpacing.space2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.space3,
                        vertical: AppSpacing.space2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.ink.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Row(
                        spacing: AppSpacing.space2,
                        children: [
                          const Icon(
                            Icons.monitor_heart_outlined,
                            size: 13,
                            color: AppColors.faint,
                          ),
                          Expanded(
                            child: Text(
                              insight.evidence.telemetryNote!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.cardMeta.copyWith(
                                fontSize: 11,
                                height: 16 / 11,
                                color: AppColors.ink.withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: AppSpacing.space4),
                  Row(
                    spacing: 6,
                    children: [
                      Text(
                        'See what to do (${insight.suggestions.length})',
                        style: AppTextStyles.cardTitle.copyWith(fontSize: 13),
                      ),
                      const Icon(
                        Icons.arrow_forward,
                        size: 14,
                        color: AppColors.ink,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BiomarkerChip extends StatelessWidget {
  const _BiomarkerChip({required this.biomarker});

  final EvidenceBiomarker biomarker;

  @override
  Widget build(BuildContext context) {
    final colour = flagColour(biomarker.flag);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: colour.withValues(alpha: 0.33)),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: [
          Text(
            biomarker.displayName,
            style: AppTextStyles.cardMeta.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.ink.withValues(alpha: 0.6),
            ),
          ),
          Text(
            biomarker.valueWithUnit,
            style: AppTextStyles.cardMeta.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: colour,
            ),
          ),
        ],
      ),
    );
  }
}
