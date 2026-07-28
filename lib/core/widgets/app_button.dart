import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

enum AppButtonVariant { primary, secondary, ghost }

/// Button matching the design system's `.btn` family (`.btn-primary`,
/// `.btn-secondary`, `.btn-ghost`), with `.btn-block` (full width, left
/// aligned) and `.btn-icon` (fixed square, icon only) modifiers.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.leading,
    this.block = false,
    this.foregroundColor,
    this.backgroundColor,
    this.borderColor,
  });

  const AppButton.icon({
    super.key,
    required Widget this.leading,
    this.onPressed,
    this.variant = AppButtonVariant.secondary,
    this.foregroundColor,
    this.backgroundColor,
    this.borderColor,
  }) : label = '',
       block = false;

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final Widget? leading;
  final bool block;
  final Color? foregroundColor;
  final Color? backgroundColor;
  final Color? borderColor;

  bool get _iconOnly => label.isEmpty && leading != null;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    final bg = backgroundColor ?? _defaultBackground();
    final fg = foregroundColor ?? _defaultForeground();
    final border = borderColor ?? _defaultBorder();

    final content = _iconOnly
        ? Center(
            child: IconTheme(
              data: IconThemeData(color: fg, size: 16),
              child: leading!,
            ),
          )
        : Row(
            mainAxisSize: block ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: block
                ? MainAxisAlignment.start
                : MainAxisAlignment.center,
            children: [
              if (leading != null) ...[
                IconTheme(
                  data: IconThemeData(color: fg, size: 16),
                  child: leading!,
                ),
                const SizedBox(width: 6),
              ],
              Text(label, style: AppTextStyles.button.copyWith(color: fg)),
            ],
          );

    final button = Opacity(
      opacity: disabled ? 0.45 : 1,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(AppSpacing.space4),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppSpacing.space4),
          child: Container(
            width: _iconOnly ? 36 : null,
            height: _iconOnly ? 36 : null,
            padding: _iconOnly
                ? null
                : EdgeInsets.symmetric(
                    horizontal: AppSpacing.space3 * 1.2,
                    vertical: AppSpacing.space2,
                  ),
            alignment: block ? Alignment.centerLeft : Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSpacing.space4),
              border: border != null ? Border.all(color: border) : null,
            ),
            child: content,
          ),
        ),
      ),
    );

    return block ? SizedBox(width: double.infinity, child: button) : button;
  }

  Color _defaultBackground() {
    switch (variant) {
      case AppButtonVariant.primary:
        return AppColors.accent;
      case AppButtonVariant.secondary:
      case AppButtonVariant.ghost:
        return Colors.transparent;
    }
  }

  Color _defaultForeground() {
    switch (variant) {
      case AppButtonVariant.primary:
        return AppColors.bg;
      case AppButtonVariant.secondary:
        return AppColors.text;
      case AppButtonVariant.ghost:
        return AppColors.accent;
    }
  }

  Color? _defaultBorder() {
    switch (variant) {
      case AppButtonVariant.primary:
      case AppButtonVariant.ghost:
        return null;
      case AppButtonVariant.secondary:
        return AppColors.divider;
    }
  }
}
