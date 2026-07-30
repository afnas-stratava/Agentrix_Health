import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Type scale mirrored from the React Native app.
///
/// Inter Tight is the product typeface — the compact display cut of Inter,
/// which is what keeps headline tracking tight at large sizes without manual
/// kerning. Unlike React Native, Flutter synthesises weights from one family,
/// so a single `GoogleFonts.interTight` call covers every face that
/// `src/theme/fonts.ts` has to register individually.
abstract final class AppTextStyles {
  static TextStyle _heading({
    required double fontSize,
    FontWeight weight = FontWeight.w700,
    double? height,
    double? letterSpacing,
  }) {
    return GoogleFonts.interTight(
      fontSize: fontSize,
      fontWeight: weight,
      height: height ?? 1.15,
      letterSpacing: letterSpacing ?? -0.02 * fontSize,
      color: AppColors.ink,
    );
  }

  static TextStyle _body({
    required double fontSize,
    FontWeight weight = FontWeight.w400,
    double? height,
    Color? color,
  }) {
    return GoogleFonts.interTight(
      fontSize: fontSize,
      fontWeight: weight,
      height: height ?? 1.5,
      color: color ?? AppColors.ink,
    );
  }

  static final TextStyle h1 = _heading(fontSize: 40);
  static final TextStyle h2 = _heading(fontSize: 32);
  static final TextStyle h3 = _heading(fontSize: 25);
  static final TextStyle h4 = _heading(fontSize: 20);
  static final TextStyle h5 = _heading(fontSize: 16, weight: FontWeight.w600);

  /// Section/step label — uppercase with wide tracking at the call site.
  static final TextStyle h6 = GoogleFonts.interTight(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0.08 * 13,
    color: AppColors.ink,
  );

  static final TextStyle body = _body(fontSize: 15);
  static final TextStyle bodySmall = _body(fontSize: 14);
  static final TextStyle muted = _body(fontSize: 14, color: AppColors.muted);

  /// Numeric readouts need tighter tracking than body copy.
  static final TextStyle metric = _heading(
    fontSize: 34,
    height: 36 / 34,
    letterSpacing: -1.2,
  );
  static final TextStyle metricSmall = _heading(
    fontSize: 22,
    height: 24 / 22,
    letterSpacing: -0.6,
  );
  static final TextStyle metricLarge = _heading(
    fontSize: 46,
    height: 48 / 46,
    letterSpacing: -1.8,
  );

  static final TextStyle cardKicker = GoogleFonts.interTight(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.0,
    color: AppColors.brand,
  );
  static final TextStyle cardTitle = _heading(
    fontSize: 17,
    weight: FontWeight.w600,
    height: 1.25,
  );
  static final TextStyle cardBody = _body(fontSize: 13, color: AppColors.muted);
  static final TextStyle cardMeta = _body(fontSize: 11, color: AppColors.faint);

  static final TextStyle tag = GoogleFonts.interTight(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
  );

  static final TextStyle button = GoogleFonts.interTight(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  static final TextStyle fieldLabel = _body(
    fontSize: 12,
    weight: FontWeight.w500,
    color: AppColors.muted,
  );

  static final TextStyle input = _body(fontSize: 15);
}
