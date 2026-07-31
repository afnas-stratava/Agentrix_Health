abstract final class AppSpacing {
  static const double space1 = 4;
  static const double space2 = 8;
  static const double space3 = 12;
  static const double space4 = 16;

  /// `px-5` — the gutter the React Native tab screens use.
  static const double space5 = 20;
  static const double space6 = 24;
  static const double space8 = 32;
}

/// Corner radii mirrored from `tailwind.config.js` — `rounded-card` (24) and
/// `rounded-pill` (999) are the two the React Native app actually reaches for;
/// the rest fill in the smaller steps.
abstract final class AppRadius {
  /// `rounded-xl` — the small tinted icon tiles inside cards.
  static const double sm = 12;

  /// `rounded-2xl` — notices, inline banners, the icon tiles in headers.
  static const double md = 16;

  static const double lg = 24;

  /// `rounded-card` — every surface in the card family.
  static const double card = 24;

  /// `rounded-pill` — buttons, tags, chips, segmented controls.
  static const double pill = 999;
}
