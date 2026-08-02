import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

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
  });

  final SocialProvider provider;
  final AuthCredential credential;
  final String? displayName;
  final String? email;

  /// Google returns this every sign-in. Apple's API has no photo of any kind,
  /// so this is always null for that provider.
  final String? photoUrl;
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

  /// Only Apple platforms take a `clientId`; Android reads its own from
  /// `google-services.json`, and passing the iOS one there fails the handshake.
  static String? get clientId {
    if (kIsWeb || !(Platform.isIOS || Platform.isMacOS)) return null;
    return googleIosClientId.isEmpty ? null : googleIosClientId;
  }

  static String? get serverClientId =>
      googleServerClientId.isEmpty ? null : googleServerClientId;
}

/// Runs the native provider sheets and hands back a Firebase credential.
///
/// Deliberately knows nothing about Firebase *sessions* — linking, collision
/// handling and profile writes all live in `AccountController`, so this class
/// stays a thin, mockable wrapper around two SDKs.
class SocialSignIn {
  SocialSignIn();

  Future<void>? _googleInit;

  /// Apple's native sheet exists only on Apple platforms. On Android it is a
  /// Chrome Custom Tab against a Services ID that this project has not set up
  /// yet, so the button is hidden there rather than shown and broken.
  static bool get supportsApple =>
      !kIsWeb && (Platform.isIOS || Platform.isMacOS);

  Future<SocialIdentity> apple() async {
    // Firebase verifies the SHA256 of the nonce it is given against the one
    // baked into Apple's identity token, so Apple gets the digest and Firebase
    // gets the raw string. Sending the same value to both fails verification.
    final rawNonce = _randomNonce();

    final AuthorizationCredentialAppleID apple;
    try {
      apple = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: sha256.convert(utf8.encode(rawNonce)).toString(),
      );
    } on SignInWithAppleAuthorizationException catch (error) {
      if (error.code == AuthorizationErrorCode.canceled) {
        throw const SignInCancelled();
      }
      rethrow;
    }

    final credential = OAuthProvider('apple.com').credential(
      idToken: apple.identityToken,
      rawNonce: rawNonce,
      accessToken: apple.authorizationCode,
    );

    final name = [
      apple.givenName,
      apple.familyName,
    ].whereType<String>().where((part) => part.isNotEmpty).join(' ');

    return SocialIdentity(
      provider: SocialProvider.apple,
      credential: credential,
      displayName: name.isEmpty ? null : name,
      email: apple.email,
    );
  }

  Future<SocialIdentity> google() async {
    await _initGoogle();

    final GoogleSignInAccount account;
    try {
      account = await GoogleSignIn.instance.authenticate();
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        throw const SignInCancelled();
      }
      rethrow;
    }

    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw const SignInNotConfigured(
        'Google returned no ID token. On Android this means the server '
        '(web) client ID is missing — see AuthConfig.',
      );
    }

    return SocialIdentity(
      provider: SocialProvider.google,
      credential: GoogleAuthProvider.credential(idToken: idToken),
      displayName: account.displayName,
      email: account.email,
      photoUrl: account.photoUrl,
    );
  }

  /// Clears the provider-side session so the next sign-in shows the account
  /// picker. Firebase's own `signOut` is the caller's job.
  ///
  /// Apple has no sign-out to call: authorization is revoked from iOS Settings,
  /// not from the app.
  Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (error) {
      // Never block a Firebase sign-out on the Google SDK: if it was never
      // initialized (Apple-only session) this throws, and the user still
      // expects the app to sign them out.
      debugPrint('Google sign-out skipped: $error');
    }
  }

  /// `initialize` is idempotent per process but not cheap, and calling it
  /// concurrently from two taps races. One future, awaited by everyone.
  Future<void> _initGoogle() {
    return _googleInit ??= GoogleSignIn.instance.initialize(
      clientId: AuthConfig.clientId,
      serverClientId: AuthConfig.serverClientId,
    );
  }

  static String _randomNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }
}
