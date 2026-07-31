import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../domain/entities/insights/correlation.dart';
import '../../../domain/entities/insights/insight.dart';

/// Mirrors `src/components/insights/ActionRow.tsx`.
///
/// A single recommended action, sized for scanning in a vertical list rather
/// than a carousel: the title, one line of specifics, and the two facts that
/// decide whether someone will actually do it — how hard it is, and how long
/// before it shows up in their data.
class ActionRow extends StatelessWidget {
  const ActionRow({
    super.key,
    required this.suggestion,
    required this.source,
    required this.onTap,
    this.isLast = false,
  });

  final Suggestion suggestion;
  final Insight source;
  final VoidCallback onTap;
  final bool isLast;

  static const _domainIcon = {
    InsightDomain.nutrition: Icons.restaurant_outlined,
    InsightDomain.training: Icons.fitness_center,
    InsightDomain.sleep: Icons.bed_outlined,
    InsightDomain.recovery: Icons.favorite_outline,
    InsightDomain.stress: Icons.monitor_heart_outlined,
    InsightDomain.medicalReferral: Icons.medical_services_outlined,
  };

  static const _effortLabel = {
    SuggestionEffort.low: 'Easy',
    SuggestionEffort.medium: 'Steady',
    SuggestionEffort.high: 'Committed',
  };

  static const _effortColor = {
    SuggestionEffort.low: AppColors.optimal,
    SuggestionEffort.medium: AppColors.borderline,
    SuggestionEffort.high: AppColors.abnormal,
  };

  /// Days → the coarsest unit that still reads as a real expectation.
  static String _horizonLabel(int days) {
    if (days <= 14) return '${days}d';
    if (days <= 60) return '${(days / 7).round()}w';
    return '${(days / 30).round()}mo';
  }

  @override
  Widget build(BuildContext context) {
    final effortColour = _effortColor[suggestion.effort]!;

    return Semantics(
      button: true,
      label: suggestion.title,
      hint: '${_effortLabel[suggestion.effort]} effort. From: ${source.title}',
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: isLast
                ? null
                : Border(
                    bottom: BorderSide(
                      color: AppColors.ink.withValues(alpha: 0.08),
                    ),
                  ),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.space5,
            vertical: AppSpacing.space4,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 14,
            children: [
              // Brand-tinted, matching the icon chips on the stat tiles — a
              // second neutral grey chip on the same screen read as a disabled
              // control.
              Container(
                margin: const EdgeInsets.only(top: 2),
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.brand50,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(
                  _domainIcon[suggestion.domain],
                  size: 17,
                  color: AppColors.brand,
                ),
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      suggestion.title,
                      style: AppTextStyles.cardTitle.copyWith(
                        fontSize: 14,
                        height: 19 / 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      suggestion.detail,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.cardBody.copyWith(
                        fontSize: 12,
                        height: 17 / 12,
                        color: AppColors.ink.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.space2),
                    Row(
                      spacing: AppSpacing.space2,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: effortColour.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(
                              AppRadius.pill,
                            ),
                          ),
                          child: Text(
                            _effortLabel[suggestion.effort]!.toUpperCase(),
                            style: AppTextStyles.tag.copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.25,
                              color: effortColour,
                            ),
                          ),
                        ),
                        Text(
                          'signal in ~${_horizonLabel(suggestion.horizonDays)}',
                          style: AppTextStyles.cardMeta.copyWith(
                            fontSize: 10,
                            color: AppColors.ink.withValues(alpha: 0.4),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
