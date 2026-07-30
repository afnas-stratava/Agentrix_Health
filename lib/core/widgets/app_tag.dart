import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

enum AppTagVariant { accent, neutral }

/// Small pill label mirroring the React Native `Badge`: an alpha-blended fill
/// derived from one colour, so the pill stays legible on both the white card
/// and the near-white canvas without needing two colour sets.
class AppTag extends StatelessWidget {
  const AppTag({
    super.key,
    required this.label,
    this.variant = AppTagVariant.neutral,
    this.color,
  });

  final String label;
  final AppTagVariant variant;

  /// Any hex from the theme; the pill derives its fill and border from it.
  /// Overrides [variant] when set — this is how status flags colour their tag.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final base =
        color ??
        (variant == AppTagVariant.accent ? AppColors.brand : AppColors.muted);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        // `${color}22` fill over a `${color}55` border, as in Badge.tsx.
        color: base.withValues(alpha: 0.13),
        border: Border.all(color: base.withValues(alpha: 0.33)),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(label, style: AppTextStyles.tag.copyWith(color: base)),
    );
  }
}
