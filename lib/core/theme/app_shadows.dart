import 'package:flutter/material.dart';

/// Elevation mirrored from the React Native `Card` stylesheet.
///
/// On a light canvas, separation comes from a soft lift rather than from
/// contrast against a dark background — so the shadow is tinted with
/// [AppColors.brandDeep] rather than neutral black, and stays very low
/// opacity. The hairline border carries the edge for users with shadows
/// reduced.
abstract final class AppShadows {
  /// `#0F2E1E` at 6% — the card lift.
  static const List<BoxShadow> sm = [
    BoxShadow(color: Color(0x0F0F2E1E), blurRadius: 16, offset: Offset(0, 6)),
  ];

  static const List<BoxShadow> md = [
    BoxShadow(color: Color(0x140F2E1E), blurRadius: 24, offset: Offset(0, 8)),
  ];

  static const List<BoxShadow> lg = [
    BoxShadow(color: Color(0x1F0F2E1E), blurRadius: 40, offset: Offset(0, 16)),
  ];
}
