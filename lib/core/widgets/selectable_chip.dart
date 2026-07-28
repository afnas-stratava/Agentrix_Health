import 'package:flutter/material.dart';

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
    this.onRemove,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? selectedBackground;
  final Color? selectedForeground;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final background = selected
        ? (selectedBackground ?? AppColors.accent100)
        : Colors.transparent;
    final foreground = selected
        ? (selectedForeground ?? AppColors.accent800)
        : AppColors.text;
    final borderColor = selected ? Colors.transparent : AppColors.divider;

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: EdgeInsets.only(
            left: 14,
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
            spacing: 4,
            children: [
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
                  onTap: onRemove,
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
