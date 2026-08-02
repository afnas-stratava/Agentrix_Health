/// Public-facing identity: the strings and URLs the About and support rows
/// render, and the ones App Store Connect has to agree with.
///
/// Not secrets — this file is committed, unlike `secrets.dart`. It exists so
/// the support address and the legal URLs live in exactly one place rather
/// than being retyped into three screens and a footer.
///
/// **Every URL below is a placeholder.** They must point at live pages before
/// submission: Apple checks the privacy-policy link, and a 404 behind
/// "Privacy Policy" is a rejection on its own. See `docs/APP_STORE.md`.
library;

abstract final class AppInfo {
  /// Shown in the settings footer and on the About screen.
  ///
  /// Kept in step with `version:` in `pubspec.yaml` by hand. The alternative
  /// is a `package_info_plus` dependency and an async read in a widget that
  /// otherwise needs no state, which is not worth it for a string that
  /// changes once per release.
  static const String version = '1.0.0';

  static const String appName = 'Agentrix Health';

  /// The legal entity, for the copyright line.
  static const String publisher = 'Stratava';

  /// Support inbox. Also becomes the App Store Connect support contact.
  static const String supportEmail = 'support@agentrixhealth.com';

  /// Required by App Review for any app handling health data, and linked from
  /// both the About screen and App Store Connect. Must disclose that lab
  /// reports and HealthKit-derived readiness are sent to Google's Gemini API
  /// to be parsed and to answer assistant questions.
  static const String privacyPolicyUrl = 'https://agentrixhealth.com/privacy';

  static const String termsUrl = 'https://agentrixhealth.com/terms';

  /// Marketing / support landing page. App Store Connect asks for this
  /// separately from the privacy policy.
  static const String websiteUrl = 'https://agentrixhealth.com';

  /// Pre-addressed support mail. The version and platform ride along in the
  /// subject so a bug report arrives with the two facts every triage needs.
  static Uri supportMailto({required String platform}) => Uri(
    scheme: 'mailto',
    path: supportEmail,
    queryParameters: {'subject': '$appName $version ($platform) — support'},
  );
}
