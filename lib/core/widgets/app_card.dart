import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';

/// Tones from the React Native `Card`.
enum AppCardTone {
  /// The default white card on the near-white canvas.
  light,

  /// A quieter, tinted grouping for secondary content.
  translucent,

  /// Reserved for the single highest-priority item on a screen.
  accent,
}

/// Card mirroring `src/components/ui/Card.tsx` — a padded, `rounded-card`
/// surface that separates from the canvas by a soft lift plus a hairline
/// border, rather than by contrast against a dark background. Pass
/// [direction]/[crossAxisAlignment] to match the row-oriented list-item cards.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.children,
    this.onTap,
    this.tone = AppCardTone.light,
    this.backgroundColor,
    this.direction = Axis.vertical,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.padding,
    this.elevated = true,
  });

  final List<Widget> children;
  final VoidCallback? onTap;
  final AppCardTone tone;
  final Color? backgroundColor;
  final Axis direction;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisAlignment mainAxisAlignment;
  final EdgeInsetsGeometry? padding;

  /// Set false for nested cards, where a second shadow reads as muddy.
  final bool elevated;

  Color get _toneBackground => switch (tone) {
    AppCardTone.light => AppColors.surface,
    AppCardTone.translucent => AppColors.brand50,
    AppCardTone.accent => AppColors.lime,
  };

  Color? get _toneBorder => switch (tone) {
    AppCardTone.light || AppCardTone.translucent => AppColors.hairline,
    AppCardTone.accent => null,
  };

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.card);

    final flex = Flex(
      direction: direction,
      crossAxisAlignment: crossAxisAlignment,
      mainAxisAlignment: mainAxisAlignment,
      mainAxisSize: MainAxisSize.min,
      spacing: AppSpacing.space2,
      children: children,
    );

    final border = _toneBorder;
    final card = Container(
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: backgroundColor ?? _toneBackground,
        borderRadius: radius,
        border: border != null ? Border.all(color: border) : null,
        // The translucent tone is a grouping, not a raised surface.
        boxShadow: elevated && tone != AppCardTone.translucent
            ? AppShadows.sm
            : null,
      ),
      child: flex,
    );

    if (onTap == null) return card;

    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap!();
        },
        child: card,
      ),
    );
  }
}
