import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

enum AppTagVariant { accent, neutral }

/// Small pill label matching `.tag`, `.tag-accent` / `.tag-neutral`.
class AppTag extends StatelessWidget {
  const AppTag({
    super.key,
    required this.label,
    this.variant = AppTagVariant.neutral,
  });

  final String label;
  final AppTagVariant variant;

  @override
  Widget build(BuildContext context) {
    final isAccent = variant == AppTagVariant.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: isAccent ? AppColors.accent100 : AppColors.neutral100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: AppTextStyles.tag.copyWith(
          color: isAccent ? AppColors.accent800 : AppColors.neutral800,
        ),
      ),
    );
  }
}
