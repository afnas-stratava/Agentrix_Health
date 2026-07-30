import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';

abstract final class AppTheme {
  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.canvas,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.brand,
        brightness: Brightness.light,
        primary: AppColors.brand,
        onPrimary: AppColors.onBrand,
        // The lime accent is the CTA fill, and it only ever carries ink.
        secondary: AppColors.lime,
        onSecondary: AppColors.ink,
        surface: AppColors.surface,
        onSurface: AppColors.ink,
        error: AppColors.critical,
      ),
    );

    return base.copyWith(
      textTheme: base.textTheme
          .copyWith(
            headlineLarge: AppTextStyles.h1,
            headlineMedium: AppTextStyles.h2,
            headlineSmall: AppTextStyles.h3,
            titleLarge: AppTextStyles.h4,
            titleMedium: AppTextStyles.h5,
            titleSmall: AppTextStyles.h6,
            bodyLarge: AppTextStyles.body,
            bodyMedium: AppTextStyles.bodySmall,
            bodySmall: AppTextStyles.cardMeta,
          )
          .apply(bodyColor: AppColors.ink, displayColor: AppColors.ink),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      dividerColor: AppColors.hairline,
      inputDecorationTheme: const InputDecorationTheme(
        border: InputBorder.none,
      ),
    );
  }
}
