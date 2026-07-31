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
  /// Tracking defaults to **zero**, matching Tailwind.
  ///
  /// It used to default to `-0.02 * fontSize`, which was wrong twice over: RN
  /// applies negative tracking only to the `metric*` sizes, and because
  /// `copyWith(fontSize:)` does not recompute letterSpacing, every call site
  /// that resized a heading kept the tracking computed for the *original* size.
  /// A 14px card title was carrying tracking meant for 17px, which is why the
  /// whole app read tighter than the React Native original.
  static TextStyle _heading({
    required double fontSize,
    FontWeight weight = FontWeight.w700,
    double? height,
    double letterSpacing = 0,
  }) {
    return GoogleFonts.interTight(
      fontSize: fontSize,
      fontWeight: weight,
      height: height ?? 1.15,
      letterSpacing: letterSpacing,
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

  static final TextStyle h1 = _heading(fontSize: 40, height: 46 / 40);
  static final TextStyle h2 = _heading(fontSize: 32);

  /// Tab-screen title. `text-3xl` in RN — Insights, Labs and Settings all use
  /// it, and it is noticeably larger than the 25px used for Today and Food.
  static final TextStyle screenTitle = _heading(fontSize: 30, height: 1.2);

  static final TextStyle h3 = _heading(fontSize: 25, height: 30 / 25);
  static final TextStyle h4 = _heading(fontSize: 20);
  static final TextStyle h5 = _heading(fontSize: 16, weight: FontWeight.w600);

  /// Centred page title on a pushed route — `text-[15px] font-bold` in RN.
  static final TextStyle h6 = _heading(
    fontSize: 15,
    height: 1.2,
    weight: FontWeight.w700,
  );

  /// Uppercase micro-label: `text-[11px] font-semibold uppercase tracking-wider`.
  ///
  /// Section header, per the design reference's type scale: 11px / 700 /
  /// 0.09em, uppercased at the call site. The tracking is the reference's, not
  /// Tailwind's `tracking-wider` — 0.09em is a hair under 1px at this size.
  static final TextStyle microLabel = GoogleFonts.interTight(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.09 * 11,
    color: AppColors.muted,
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
    letterSpacing: 0.5,
    color: AppColors.brand,
  );
  /// `text-[15px] font-semibold` — the size RN's card headings actually use.
  static final TextStyle cardTitle = _heading(
    fontSize: 15,
    weight: FontWeight.w600,
    height: 1.25,
  );

  /// `text-[13px] font-sans leading-5` — 20px leading on 13px copy.
  static final TextStyle cardBody = _body(
    fontSize: 13,
    height: 20 / 13,
    color: AppColors.muted,
  );
  static final TextStyle cardMeta = _body(fontSize: 11, color: AppColors.faint);

  static final TextStyle tag = GoogleFonts.interTight(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.55,
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
