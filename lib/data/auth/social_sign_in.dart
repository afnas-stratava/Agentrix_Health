import 'dart:convert';
import 'dart:io' show Platform;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import '../../core/config/api_endpoints.dart';

/// The identity providers the app offers.
///
/// Apple is not optional on iOS: App Store guideline 4.8 requires Sign in with
/// Apple wherever a third-party social login is offered, so the two ship
/// together or not at all.
enum SocialProvider {
  apple('Apple'),
  google('Google');

  const SocialProvider(this.label);

  final String label;
}

/// The result of a completed provider handshake, before Firebase sees it.
///
/// [displayName] and [email] are carried separately from the credential because
/// **Apple returns the user's name exactly once**, on the very first
/// authorization for a given Apple ID. Any later sign-in returns nulls, and the
/// name is unrecoverable. Whatever arrives here has to be written to the profile
/// immediately or lost.
class SocialIdentity {
  const SocialIdentity({
    required this.provider,
    required this.credential,
    this.displayName,
    this.email,
    this.photoUrl,
    this.idToken,
    this.onboardingComplete = false,
  });

  final SocialProvider provider;
  final AuthCredential credential;
  final String? displayName;
  final String? email;

  /// Google returns this every sign-in. Apple's API has no photo of any kind,
  /// so this is always null for that provider.
  final String? photoUrl;

  /// The verified Google ID token — only set for [SocialProvider.google].
  /// Short-lived (expires within the hour); callers that need to authenticate
  /// a later backend call in the same session read it, nothing persists it.
  /// See `session_storage.dart` for why it never survives a restart.
  final String? idToken;

  /// Whether *this* account already finished onboarding — on a different
  /// device, or an earlier install on this one. Lets `account_screen.dart`
  /// skip straight to the main app instead of re-running onboarding for
  /// someone who already answered everything. Always false for Apple, which
  /// has no backend to read it from yet.
  final bool onboardingComplete;
}

/// The user backed out of the provider sheet. Not an error — nothing is shown.
class SignInCancelled implements Exception {
  const SignInCancelled();
}

/// A provider is offered by the UI but this build has no client ID for it.
class SignInNotConfigured implements Exception {
  const SignInNotConfigured(this.message);

  final String message;

  @override
  String toString() => message;
}

/// OAuth client IDs, supplied at build time.
///
/// Google's iOS client ID normally comes from `GoogleService-Info.plist`. That
/// file is not in the repo (it carries project-specific IDs), so these defines
/// are the escape hatch for builds that do not bundle it:
///
/// ```
/// flutter run \
///   --dart-define=GOOGLE_IOS_CLIENT_ID=<...>.apps.googleusercontent.com \
///   --dart-define=GOOGLE_SERVER_CLIENT_ID=<web client>.apps.googleusercontent.com
/// ```
///
/// On Android the server (web) client ID is what makes Google return an ID
/// token at all — without it the handshake succeeds and Firebase then rejects a
/// credential with no token, which reads as a mysterious failure at the last
/// step.
abstract final class AuthConfig {
  static const String googleIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
  );

  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
  );

  /// The project's web (`client_type: 3`) OAuth client — not a secret, it's
  /// the public audience value every Google ID token is issued for, and it's
  /// the same value visible in `android/app/google-services.json`. Kept here
  /// as the default so a plain `flutter run` works without the dart-define
  /// below; override it only for a build against a different Firebase
  /// project.
  static const String _defaultServerClientId =
      '368943821492-ilqu1s9fr9ktktjlv3gjfdso2eh0umta.apps.googleusercontent.com';

  /// Only Apple platforms take a `clientId`; Android reads its own from
  /// `google-services.json`, and passing the iOS one there fails the handshake.
  static String? get clientId {
    if (kIsWeb || !(Platform.isIOS || Platform.isMacOS)) return null;
    return googleIosClientId.isEmpty ? null : googleIosClientId;
  }

  static String? get serverClientId =>
      googleServerClientId.isEmpty ? _defaultServerClientId : googleServerClientId;
}

/// Runs the native provider sheets and hands back a credential.
///
/// [apple] is still simulated — no Apple backend flow yet. [google] is real:
/// it runs the native Google sheet, then posts the ID token to the
/// `agentrix_backend` FastAPI service's `/auth/google` (see
/// `app/api/auth.py` there) for server-side verification.
/// [_placeholder] satisfies [SocialIdentity.credential]'s type for the
/// providers that don't build a real Firebase credential.
class SocialSignIn {
  SocialSignIn();

  static final GoogleSignIn _google = GoogleSignIn.instance;
  static bool _googleInitialized = false;

  static Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) return;
    await _google.initialize(
      clientId: AuthConfig.clientId,
      serverClientId: AuthConfig.serverClientId,
    );
    _googleInitialized = true;
  }

  /// Apple's native sheet exists only on Apple platforms. On Android it is a
  /// Chrome Custom Tab against a Services ID this project has not set up, so
  /// the button is hidden there rather than shown and broken.
  static bool get supportsApple =>
      !kIsWeb && (Platform.isIOS || Platform.isMacOS);

  static const Duration _simulatedLatency = Duration(milliseconds: 500);

  Future<SocialIdentity> apple() async {
    await Future<void>.delayed(_simulatedLatency);
    return SocialIdentity(
      provider: SocialProvider.apple,
      credential: _placeholder,
      displayName: 'Alex Rivera',
      email: 'alex.rivera@icloud.com',
    );
  }

  Future<SocialIdentity> google() async {
    await _ensureGoogleInitialized();

    final GoogleSignInAccount account;
    try {
      account = await _google.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const SignInCancelled();
      }
      rethrow;
    }

    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw const SignInNotConfigured(
        'Google did not return an ID token. Check GOOGLE_SERVER_CLIENT_ID.',
      );
    }

    // The account object already carries displayName/email/photoUrl, but
    // those are whatever the client-side SDK claims. The backend re-derives
    // them from the token's verified signature so a tampered client can't
    // hand the rest of the app a spoofed identity.
    final response = await http
        .post(
          ApiEndpoints.googleAuth,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({'id_token': idToken}),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('Google sign-in failed (${response.statusCode})');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    return SocialIdentity(
      provider: SocialProvider.google,
      credential: GoogleAuthProvider.credential(idToken: idToken),
      displayName: body['name'] as String?,
      email: body['email'] as String?,
      photoUrl: body['picture'] as String?,
      idToken: idToken,
      onboardingComplete: body['onboarding_complete'] as bool? ?? false,
    );
  }

  Future<void> signOut() async {
    await _google.signOut();
  }

  /// A locally-constructed credential — no network call, never sent to a
  /// server — kept only to satisfy [SocialIdentity.credential]'s type.
  static AuthCredential get _placeholder => EmailAuthProvider.credential(
    email: 'local@device',
    password: 'unused',
  );
}
