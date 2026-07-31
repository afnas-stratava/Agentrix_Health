import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// A toggleable pill used for multi-select groups (cuisines, allergies):
/// outlined when unselected, filled when selected. [onRemove] adds a trailing
/// close affordance for user-entered (rather than preset) options.
class SelectableChip extends StatelessWidget {
  const SelectableChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.selectedBackground,
    this.selectedForeground,
    this.selectedBorder,
    this.rank,
    this.onRemove,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? selectedBackground;
  final Color? selectedForeground;
  final Color? selectedBorder;

  /// Shows the selection order — used where order is preference weight.
  final int? rank;

  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    // Mirrors `ChoiceChip` in the React Native app: selected is a brand-50
    // fill inside a brand-400 hairline, unselected is a plain surface chip
    // with muted copy.
    final background = selected
        ? (selectedBackground ?? AppColors.brand50)
        : AppColors.surface;
    final foreground = selected
        ? (selectedForeground ?? AppColors.brand700)
        : AppColors.muted;
    final borderColor = selected
        ? (selectedBorder ?? AppColors.brand400)
        : AppColors.hairline;

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: EdgeInsets.only(
            left: rank != null && selected ? 8 : 14,
            right: onRemove != null ? 8 : 14,
            top: 8,
            bottom: 8,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 6,
            children: [
              if (rank != null && selected)
                Container(
                  width: 16,
                  height: 16,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.brand600,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$rank',
                    style: AppTextStyles.tag.copyWith(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onBrand,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              Text(
                label,
                style: AppTextStyles.bodySmall.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: foreground,
                ),
              ),
              if (onRemove != null)
                InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onRemove!();
                  },
                  borderRadius: BorderRadius.circular(999),
                  child: Icon(Icons.close, size: 14, color: foreground),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
