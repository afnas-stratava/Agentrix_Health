import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Text styles built on Archivo, matching the design system's heading
/// (weight 800) and body (weight 400) font roles.
abstract final class AppTextStyles {
  static TextStyle _heading({
    required double fontSize,
    double? height,
    double? letterSpacing,
  }) {
    return GoogleFonts.archivo(
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      height: height ?? 1.12,
      letterSpacing: letterSpacing ?? -0.015 * fontSize,
      color: AppColors.text,
    );
  }

  static TextStyle _body({
    required double fontSize,
    FontWeight weight = FontWeight.w400,
    double? height,
  }) {
    return GoogleFonts.archivo(
      fontSize: fontSize,
      fontWeight: weight,
      height: height ?? 1.55,
      color: AppColors.text,
    );
  }

  static final TextStyle h1 = _heading(fontSize: 42);
  static final TextStyle h2 = _heading(fontSize: 32);
  static final TextStyle h3 = _heading(fontSize: 25);
  static final TextStyle h4 = _heading(fontSize: 20);
  static final TextStyle h5 = _heading(fontSize: 16);
  static final TextStyle
  h6 = _heading(fontSize: 13, letterSpacing: 0.08 * 13).copyWith(
    // h6 in the design is uppercase + wide tracking, used as section/step labels.
  );

  static final TextStyle body = _body(fontSize: 15);
  static final TextStyle bodySmall = _body(fontSize: 14);
  static final TextStyle muted = _body(
    fontSize: 14,
  ).copyWith(color: AppColors.text.withValues(alpha: 0.55));

  static final TextStyle cardKicker = GoogleFonts.archivo(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.0,
    color: AppColors.accent,
  );
  static final TextStyle cardTitle = _heading(fontSize: 17, height: 1.2);
  static final TextStyle cardBody = _body(
    fontSize: 13,
  ).copyWith(color: AppColors.text.withValues(alpha: 0.8));
  static final TextStyle cardMeta = _body(
    fontSize: 11,
  ).copyWith(color: AppColors.text.withValues(alpha: 0.5));

  static final TextStyle tag = GoogleFonts.archivo(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
  );

  static final TextStyle button = GoogleFonts.archivo(
    fontSize: 14,
    fontWeight: FontWeight.w800,
    height: 1.2,
  );

  static final TextStyle fieldLabel = _body(
    fontSize: 12,
  ).copyWith(color: AppColors.text.withValues(alpha: 0.7));

  static final TextStyle input = _body(fontSize: 14);
}
