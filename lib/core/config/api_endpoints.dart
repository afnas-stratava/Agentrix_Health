/// Every URL endpoint the app calls over HTTP — third-party APIs and our own
/// backend alike.
///
/// Kept separate from `app_info.dart`, which holds the app's *own* public
/// pages (privacy policy, support) rather than services it talks to.
library;

abstract final class ApiEndpoints {
  /// The `agentrix_backend` FastAPI service (see `app/api/auth.py` there)
  /// that verifies a Google ID token server-side before the app trusts its
  /// claims.
  ///
  /// Defaults to plain loopback — for a physical device that means running
  /// `adb reverse tcp:8000 tcp:8000` once per debug session (tunnels the
  /// phone's own `localhost` to this machine; the mapping is dropped every
  /// time `flutter run` reconnects, so it has to be re-run then, not just
  /// once ever).
  ///
  /// The LAN address looked like the cleaner fix (this machine's WSL runs in
  /// mirrored networking mode), but `Get-NetTCPConnection` shows Windows
  /// never actually exposes the listen socket to the LAN interface here —
  /// only loopback is proxied through. Revisit if that gets sorted out; until
  /// then `adb reverse` is what's proven to work. The Android-emulator
  /// loopback alias still works as an override too:
  ///
  /// ```
  /// flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000       # emulator
  /// flutter run --dart-define=API_BASE_URL=http://192.168.1.23:8000   # LAN, once fixed
  /// ```
  static const String backendBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  /// Verifies a Google ID token and returns the identity it belongs to.
  static Uri get googleAuth => Uri.parse('$backendBaseUrl/auth/google');

  /// Updates the signed-in user's biological-sex reference-range setting.
  /// See `app/api/users.py` — takes the same Google ID token as
  /// [googleAuth] to identify the user, no separate session needed.
  static Uri get updateBiologicalSex =>
      Uri.parse('$backendBaseUrl/users/me/sex');

  /// Updates the signed-in user's height/weight/age/activity level — see
  /// `UserProfileNotifier._syncBody` and `app/api/users.py`. The on-device
  /// copy stays the source of truth for reads; this is not fetched back
  /// from yet.
  static Uri get updateBody => Uri.parse('$backendBaseUrl/users/me/body');

  /// Updates the signed-in user's goal(s), target weight and any conditions
  /// being managed — see `UserProfileNotifier._syncGoals` and
  /// `app/api/users.py`.
  static Uri get updateGoals => Uri.parse('$backendBaseUrl/users/me/goals');

  /// Updates the signed-in user's diet pattern, allergies, preferences and
  /// ranked cuisines — see `UserProfileNotifier._syncDiet` and
  /// `app/api/users.py`.
  static Uri get updateDiet => Uri.parse('$backendBaseUrl/users/me/diet');

  /// Marks onboarding finished for the signed-in user — see
  /// `AppStageNotifier.goMain` and `app/api/users.py`. Read back on the next
  /// `/auth/google` so a reinstall or a second device skips onboarding for an
  /// account that already completed it.
  static Uri get markOnboardingComplete =>
      Uri.parse('$backendBaseUrl/users/me/onboarding-complete');

  /// OpenStreetMap's Overpass API — nearby restaurants and fast-food places.
  /// See `OverpassClient` for why there are three: no SLA on any one mirror,
  /// so all three are queried concurrently and the first live answer wins.
  static final List<Uri> overpassMirrors = [
    Uri.parse('https://overpass-api.de/api/interpreter'),
    Uri.parse('https://overpass.private.coffee/api/interpreter'),
    Uri.parse('https://maps.mail.ru/osm/tools/overpass/api/interpreter'),
  ];

  /// A universal Google Maps search link for a coordinate pair — resolves to
  /// whatever maps app is installed, no API key needed since it's just a URL.
  static String googleMapsSearch({required double lat, required double lon}) =>
      'https://www.google.com/maps/search/?api=1&query=$lat,$lon';
}
