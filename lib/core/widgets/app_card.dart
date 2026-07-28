import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';

/// Card matching the design system's `.card` class: a padded, rounded,
/// softly-shadowed surface. Pass [direction]/[crossAxisAlignment] to match
/// the row-oriented cards used for list items.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.children,
    this.onTap,
    this.backgroundColor,
    this.direction = Axis.vertical,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.padding,
    this.elevated = true,
  });

  final List<Widget> children;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Axis direction;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisAlignment mainAxisAlignment;
  final EdgeInsetsGeometry? padding;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final flex = Flex(
      direction: direction,
      crossAxisAlignment: crossAxisAlignment,
      mainAxisAlignment: mainAxisAlignment,
      mainAxisSize: MainAxisSize.min,
      spacing: AppSpacing.space2,
      children: children,
    );

    final card = Container(
      padding: padding ?? const EdgeInsets.all(AppSpacing.space3),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.space4),
        boxShadow: elevated ? AppShadows.sm : null,
      ),
      child: flex,
    );

    if (onTap == null) return card;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppSpacing.space4),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: card),
    );
  }
}
