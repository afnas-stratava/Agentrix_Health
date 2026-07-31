import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

/// Radio renders a dot, checkbox a tick — matching single vs multi select.
enum AppChoiceControl { radio, checkbox }

/// Mirrors `ChoiceRow` in `src/components/ui/Choice.tsx`.
///
/// Used for mutually-exclusive decisions that need a sentence of explanation
/// (goal, diet pattern). Multi-select sets where the label alone is enough
/// belong in [SelectableChip] instead — a screen that mixes the two
/// arbitrarily is a screen where nothing reads as more important than
/// anything else.
class AppChoiceRow extends StatelessWidget {
  const AppChoiceRow({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.hint,
    this.icon,
    this.control = AppChoiceControl.radio,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? hint;
  final IconData? icon;
  final AppChoiceControl control;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.card);
    final isRadio = control == AppChoiceControl.radio;

    return Semantics(
      inMutuallyExclusiveGroup: isRadio,
      checked: selected,
      label: label,
      hint: hint,
      child: Material(
        color: selected ? AppColors.brand50 : AppColors.surface,
        borderRadius: radius,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          borderRadius: radius,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.space4),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: selected ? AppColors.brand400 : AppColors.hairline,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  spacing: AppSpacing.space3,
                  children: [
                    _Control(selected: selected, isRadio: isRadio),
                    if (icon != null)
                      Icon(
                        icon,
                        size: 17,
                        color: selected ? AppColors.brand : AppColors.faint,
                      ),
                    Expanded(
                      child: Text(
                        label,
                        style: AppTextStyles.body.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                if (hint != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 32, top: 4),
                    child: Text(
                      hint!,
                      style: AppTextStyles.cardBody.copyWith(fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Control extends StatelessWidget {
  const _Control({required this.selected, required this.isRadio});

  final bool selected;
  final bool isRadio;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? AppColors.brand600 : Colors.transparent,
        shape: isRadio ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: isRadio ? null : BorderRadius.circular(6),
        border: Border.all(
          // Hairline on white is ~1.15:1 — an unselected radio was all but
          // invisible, so the control ring uses the darker [AppColors.faint]
          // while the card around it keeps the hairline.
          color: selected ? AppColors.brand600 : AppColors.faint,
          width: 2,
        ),
      ),
      child: selected
          ? Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: isRadio ? BoxShape.circle : BoxShape.rectangle,
                borderRadius: isRadio ? null : BorderRadius.circular(2),
              ),
            )
          : null,
    );
  }
}
