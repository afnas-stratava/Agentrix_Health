import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

enum AppButtonVariant { primary, secondary, ghost, danger }

enum AppButtonSize { sm, md, lg }

/// Button mirroring the React Native `Button` in `src/components/ui/Button.tsx`.
///
/// Every variant is a pill. `primary` is the lime accent carrying **ink** —
/// the accent is never paired with white text — and `AppButton.icon` is the
/// circular icon-only affordance used in headers and card corners.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.md,
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
    this.size = AppButtonSize.md,
    this.foregroundColor,
    this.backgroundColor,
    this.borderColor,
  }) : label = '',
       block = false;

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final Widget? leading;
  final bool block;
  final Color? foregroundColor;
  final Color? backgroundColor;
  final Color? borderColor;

  bool get _iconOnly => label.isEmpty && leading != null;

  /// Heights and horizontal padding from the RN `SIZE` map.
  double get _height => switch (size) {
    AppButtonSize.sm => 36,
    AppButtonSize.md => 48,
    AppButtonSize.lg => 56,
  };

  /// Circular icon buttons, per the design reference's shape table: header
  /// actions are 48px, and `sm` stays 40 for the denser in-card affordances.
  double get _iconOnlyDiameter => switch (size) {
    AppButtonSize.sm => 40,
    AppButtonSize.md => 48,
    AppButtonSize.lg => 56,
  };

  double get _paddingX => switch (size) {
    AppButtonSize.sm => 14,
    AppButtonSize.md => 20,
    AppButtonSize.lg => 24,
  };

  double get _labelSize => switch (size) {
    AppButtonSize.sm => 13,
    AppButtonSize.md => 15,
    AppButtonSize.lg => 16,
  };

  double get _iconSize => switch (size) {
    AppButtonSize.sm => 15,
    AppButtonSize.md => 18,
    AppButtonSize.lg => 20,
  };

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    final bg = backgroundColor ?? _defaultBackground();
    final fg = foregroundColor ?? _defaultForeground();
    final border = borderColor ?? _defaultBorder();
    final radius = BorderRadius.circular(AppRadius.pill);

    final content = _iconOnly
        ? Center(
            child: IconTheme(
              data: IconThemeData(color: fg, size: 18),
              child: leading!,
            ),
          )
        : Row(
            mainAxisSize: block ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (leading != null) ...[
                IconTheme(
                  data: IconThemeData(color: fg, size: _iconSize),
                  child: leading!,
                ),
                const SizedBox(width: AppSpacing.space2),
              ],
              // Loose flex so a long label (or a large accessibility text
              // scale) ellipsises inside the pill instead of overflowing it.
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.button.copyWith(
                    color: fg,
                    fontSize: _labelSize,
                  ),
                ),
              ),
            ],
          );

    final button = Opacity(
      opacity: disabled ? 0.45 : 1,
      child: Material(
        color: bg,
        borderRadius: radius,
        child: InkWell(
          onTap: onPressed,
          borderRadius: radius,
          child: Container(
            width: _iconOnly ? _iconOnlyDiameter : null,
            height: _iconOnly ? _iconOnlyDiameter : _height,
            padding: _iconOnly
                ? null
                : EdgeInsets.symmetric(horizontal: _paddingX),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: radius,
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
        return AppColors.lime;
      case AppButtonVariant.secondary:
        // `bg-ink/5` over the canvas.
        return AppColors.ink.withValues(alpha: 0.05);
      case AppButtonVariant.ghost:
        return Colors.transparent;
      case AppButtonVariant.danger:
        return AppColors.critical.withValues(alpha: 0.15);
    }
  }

  Color _defaultForeground() {
    switch (variant) {
      case AppButtonVariant.primary:
      case AppButtonVariant.secondary:
        return AppColors.ink;
      case AppButtonVariant.ghost:
        return AppColors.ink.withValues(alpha: 0.8);
      case AppButtonVariant.danger:
        return AppColors.critical;
    }
  }

  Color? _defaultBorder() {
    switch (variant) {
      case AppButtonVariant.primary:
      case AppButtonVariant.ghost:
        return null;
      case AppButtonVariant.secondary:
        return AppColors.hairline;
      case AppButtonVariant.danger:
        return AppColors.critical.withValues(alpha: 0.4);
    }
  }
}
