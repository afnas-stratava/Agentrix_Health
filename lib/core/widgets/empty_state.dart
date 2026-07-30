import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'app_button.dart';

/// Mirrors `src/components/ui/EmptyState.tsx`.
///
/// Every empty state in the app carries a *reason* and, where one exists, the
/// action that resolves it. An icon and the word "Empty" tells the user nothing
/// they did not already know from the blank screen.
enum EmptyStateTone {
  /// Sitting directly on the canvas — draws its own dashed container.
  onCanvas,

  /// Already inside a card, so it draws no container of its own.
  onCard,
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
    this.tone = EmptyStateTone.onCanvas,
  });

  final IconData icon;
  final String title;
  final String body;

  /// Both must be set for the action to render — a label with no handler is the
  /// dead affordance this widget exists to avoid.
  final String? actionLabel;
  final VoidCallback? onAction;

  final EmptyStateTone tone;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.brand50,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Icon(icon, size: 20, color: AppColors.brand),
        ),
        const SizedBox(height: AppSpacing.space3),
        Text(
          title,
          textAlign: TextAlign.center,
          style: AppTextStyles.cardTitle.copyWith(fontSize: 15),
        ),
        const SizedBox(height: 5),
        Text(
          body,
          textAlign: TextAlign.center,
          style: AppTextStyles.cardBody.copyWith(height: 1.5),
        ),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: AppSpacing.space4),
          AppButton(
            label: actionLabel!,
            size: AppButtonSize.sm,
            onPressed: onAction,
          ),
        ],
      ],
    );

    if (tone == EmptyStateTone.onCard) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.space2),
        child: content,
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space5,
        vertical: AppSpacing.space6,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.hairline),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: content,
    );
  }
}
