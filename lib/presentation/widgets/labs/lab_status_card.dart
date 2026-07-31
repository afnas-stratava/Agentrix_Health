import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/util/iso_day.dart';
import '../../../core/widgets/pressable_scale.dart';
import '../../../domain/entities/labs/lab_report.dart';

/// Mirrors `src/components/labs/LabStatusCard.tsx`.
///
/// Closes the loop on the dashboard: telemetry updates itself every day, but lab
/// data only changes when the user acts. This is the prompt that keeps the
/// correlation half of the product alive.
class LabStatusCard extends StatelessWidget {
  const LabStatusCard({
    super.key,
    required this.report,
    required this.flaggedCount,
    required this.onTap,
  });

  final LabReport? report;
  final int flaggedCount;
  final VoidCallback onTap;

  /// Beyond this, biomarkers are old enough that the engine heavily discounts
  /// them — so the card says so rather than presenting them as current.
  static const int _staleAfterDays = 180;

  static String _ageLabel(int days) {
    if (days == 0) return 'Collected today';
    if (days == 1) return 'Collected yesterday';
    if (days < 60) return '$days days ago';
    if (days < 365) return '${(days / 30).round()} months ago';
    return '${(days / 365).toStringAsFixed(1)} years ago';
  }

  @override
  Widget build(BuildContext context) {
    final panel = report;
    if (panel == null) return _EmptyPrompt(onTap: onTap);

    final anchor = panel.collectedAt ?? panel.uploadedAt;
    final ageDays = daysBetween(anchor, DateTime.now()).clamp(0, 1 << 30);
    final isStale = ageDays > _staleAfterDays;
    final accent = isStale ? AppColors.borderline : AppColors.brand;

    return PressableScale(
      scaleTo: 0.99,
      semanticLabel: 'Lab report from ${_ageLabel(ageDays)}',
      semanticHint: 'Opens the full report',
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.space4),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.hairline),
          borderRadius: BorderRadius.circular(AppRadius.card),
          boxShadow: AppShadows.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              spacing: 14,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(
                    Icons.science_outlined,
                    size: 19,
                    color: accent,
                  ),
                ),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        panel.panelName ?? 'Blood report',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.cardTitle.copyWith(fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_ageLabel(ageDays)} · '
                        '${panel.biomarkers.length} markers',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.cardMeta.copyWith(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),

                // The off-target count earns its own pill: it is the one number
                // here that decides whether the report is worth reopening.
                if (flaggedCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.abnormal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      '$flaggedCount off',
                      style: AppTextStyles.cardMeta.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.abnormal,
                      ),
                    ),
                  ),

                const Icon(
                  Icons.chevron_right,
                  size: 17,
                  color: AppColors.faint,
                ),
              ],
            ),

            if (isStale)
              Container(
                margin: const EdgeInsets.only(top: AppSpacing.space3),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.space3,
                  vertical: AppSpacing.space2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.borderline.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  'Older than 6 months — findings from it are heavily '
                  'discounted.',
                  style: AppTextStyles.cardMeta.copyWith(
                    fontSize: 11,
                    height: 16 / 11,
                    color: AppColors.ink.withValues(alpha: 0.7),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A dashed prompt rather than a solid card: this is an invitation, not a
/// record, and it should not read as one more thing already in the feed.
class _EmptyPrompt extends StatelessWidget {
  const _EmptyPrompt({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      scaleTo: 0.99,
      semanticLabel: 'Find your blood work',
      semanticHint: 'Opens the ways to add a lab report',
      onTap: onTap,
      child: CustomPaint(
        painter: const _DashedBorderPainter(),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.space4),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Row(
            spacing: 14,
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.limeSoft,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Icon(Icons.add, size: 20, color: AppColors.brand),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Find your blood work',
                      style: AppTextStyles.cardTitle.copyWith(fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Add a lab report and we can start pairing your '
                      'biomarkers against these daily trends.',
                      style: AppTextStyles.cardMeta.copyWith(
                        fontSize: 12,
                        height: 16 / 12,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 17,
                color: AppColors.faint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// `border-dashed border-brand-200` — Flutter has no dashed border, so it is
/// stroked by hand.
class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = AppColors.brand200;

    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(AppRadius.card),
    );

    const dash = 5.0;
    const gap = 4.0;

    for (final metric in (Path()..addRRect(rect)).computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance = end + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) => false;
}
