import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuthException;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/auth/session_storage.dart';
import '../../data/auth/social_sign_in.dart';
import 'auth_providers.dart';
import 'user_profile_provider.dart';

final socialSignInProvider = Provider<SocialSignIn>((ref) => SocialSignIn());

final sessionStorageProvider = Provider<SessionStorage>(
  (ref) => const SessionStorage(),
);

/// The session saved on a previous launch, resolved in `main()` *before*
/// `runApp()` — same reasoning as `onboardingCompleteAtLaunchProvider`: a
/// [Notifier.build] can't await the secure-storage read, and starting
/// signed-out for one frame before flipping to signed-in is the flash a user
/// reads as "it signed me out".
final savedSessionAtLaunchProvider = Provider<StoredSession?>((ref) => null);

/// How the current session was established.
enum SessionKind {
  /// No session at all.
  none,

  /// The default state every install starts in.
  anonymous,

  /// "Signed in" via [AccountController.signIn]. Google is a real handshake,
  /// backend-verified; Apple is still simulated. See `social_sign_in.dart`.
  account,
}

/// A flat view of the session for the UI to switch on.
class AccountStatus {
  const AccountStatus({
    required this.kind,
    this.email,
    this.displayName,
    this.photoUrl,
    this.providerIds = const [],
  });

  final SessionKind kind;
  final String? email;
  final String? displayName;
  final String? photoUrl;

  /// e.g. `apple.com`, `google.com`.
  final List<String> providerIds;

  bool get isAccount => kind == SessionKind.account;

  /// What to call the account in the UI when there is no email.
  String get label => email ?? displayName ?? 'Signed in';
}

/// Local session state, seeded from whatever [savedSessionAtLaunchProvider]
/// resolved to — a previously signed-in session reappears as `account`
/// instead of every launch starting anonymous.
final _sessionProvider = StateProvider<AccountStatus>((ref) {
  final saved = ref.watch(savedSessionAtLaunchProvider);
  if (saved == null) return const AccountStatus(kind: SessionKind.anonymous);
  return AccountStatus(
    kind: SessionKind.account,
    email: saved.email,
    displayName: saved.displayName,
    photoUrl: saved.photoUrl,
    providerIds: saved.providerIds,
  );
});

final accountStatusProvider = Provider<AccountStatus>(
  (ref) => ref.watch(_sessionProvider),
);

/// Sign-in, sign-out and account deletion.
///
/// The state is the in-flight operation, so a screen can disable its buttons
/// and surface an error without owning any of this itself. See
/// `social_sign_in.dart` for what each provider's handshake actually does,
/// and `session_storage.dart` for why a signed-in session survives a restart.
class AccountController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Runs the (simulated) provider sheet and adopts the result as the
  /// session. `success: false` means the user backed out or the handshake
  /// failed, so the caller can distinguish "cancelled" from "failed" without
  /// inspecting the error. `onboardingComplete` is only meaningful when
  /// `success` is true — it's what `account_screen.dart` reads to decide
  /// whether to run onboarding or skip straight to the main app for an
  /// account that already finished it.
  Future<({bool success, bool onboardingComplete})> signIn(
    SocialProvider provider,
  ) async {
    state = const AsyncLoading();

    try {
      final social = ref.read(socialSignInProvider);
      final identity = switch (provider) {
        SocialProvider.apple => await social.apple(),
        SocialProvider.google => await social.google(),
      };

      final providerIds = [
        provider == SocialProvider.apple ? 'apple.com' : 'google.com',
      ];
      ref.read(_sessionProvider.notifier).state = AccountStatus(
        kind: SessionKind.account,
        email: identity.email,
        displayName: identity.displayName,
        photoUrl: identity.photoUrl,
        providerIds: providerIds,
      );
      await ref
          .read(sessionStorageProvider)
          .write(
            StoredSession(
              email: identity.email,
              displayName: identity.displayName,
              photoUrl: identity.photoUrl,
              providerIds: providerIds,
            ),
          );

      _adoptProfileDetails(identity);
      ref.read(googleIdTokenProvider.notifier).state = identity.idToken;

      state = const AsyncData(null);
      return (success: true, onboardingComplete: identity.onboardingComplete);
    } on SignInCancelled {
      state = const AsyncData(null);
      return (success: false, onboardingComplete: false);
    } catch (error, stack) {
      debugPrint(
        'AccountController.signIn($provider) failed: '
        '${error.runtimeType}: $error\n$stack',
      );
      state = AsyncError(error, stack);
      return (success: false, onboardingComplete: false);
    }
  }

  /// Writes through anything the provider told us that the profile lacks.
  void _adoptProfileDetails(SocialIdentity identity) {
    final name = identity.displayName;
    if (name != null &&
        name.isNotEmpty &&
        ref.read(userProfileProvider).name.trim().isEmpty) {
      ref.read(userProfileProvider.notifier).setName(name);
    }

    final photoUrl = identity.photoUrl;
    if (photoUrl != null &&
        photoUrl.isNotEmpty &&
        (ref.read(userProfileProvider).photoUrl ?? '').isEmpty) {
      ref.read(userProfileProvider.notifier).setPhotoUrl(photoUrl);
    }
  }

  /// Ends the session and returns the app to a signed-out state.
  Future<void> signOut() async {
    state = const AsyncLoading();
    await ref.read(socialSignInProvider).signOut();

    // Clearing the profile is not cosmetic: it stays in memory across a sign
    // out, and the next write would persist it as if the next person to use
    // this device were still the one who just signed out.
    ref.read(userProfileProvider.notifier).reset();
    ref.read(_sessionProvider.notifier).state = const AccountStatus(
      kind: SessionKind.anonymous,
    );
    ref.read(googleIdTokenProvider.notifier).state = null;
    await ref.read(sessionStorageProvider).clear();

    state = const AsyncData(null);
  }

  /// Deletes the (simulated) account and everything written under it.
  ///
  /// Kept `async` and shaped like the real flow it replaces — a future
  /// backend re-adds the re-auth branch here without touching callers.
  Future<bool> deleteAccount({
    required Future<SocialIdentity?> Function() reauthenticate,
  }) async {
    state = const AsyncLoading();
    ref.read(userProfileProvider.notifier).reset();
    ref.read(_sessionProvider.notifier).state = const AccountStatus(
      kind: SessionKind.anonymous,
    );
    ref.read(googleIdTokenProvider.notifier).state = null;
    await ref.read(sessionStorageProvider).clear();
    state = const AsyncData(null);
    return true;
  }
}

final accountControllerProvider =
    AsyncNotifierProvider<AccountController, void>(AccountController.new);

/// Turns a Firebase error into something worth showing a user. No backend in
/// this build ever throws one of these, but the mapping is kept so a real
/// auth backend can reuse it unmodified.
String describeAuthError(Object error) {
  if (error is SignInNotConfigured) return error.message;

  if (error is FirebaseAuthException) {
    return switch (error.code) {
      'account-exists-with-different-credential' =>
        'That email is already registered with a different sign-in method. '
            'Use the one you signed up with.',
      'network-request-failed' =>
        'No connection. Check your network and try again.',
      'operation-not-allowed' =>
        'That sign-in method is not enabled for this project yet.',
      'invalid-credential' =>
        'That sign-in could not be verified. Please try again.',
      _ => error.message ?? 'Sign-in failed. Please try again.',
    };
  }

  return 'Sign-in failed. Please try again.';
}
