import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuthException;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/auth/social_sign_in.dart';
import 'user_profile_provider.dart';

final socialSignInProvider = Provider<SocialSignIn>((ref) => SocialSignIn());

/// How the current session was established.
enum SessionKind {
  /// No session at all.
  none,

  /// The default state every install starts in. No backend in this build, so
  /// this never actually reaches a server — it exists so the UI has the same
  /// three-state gate (none / anonymous / account) a real auth backend uses.
  anonymous,

  /// "Signed in" via [AccountController.signIn] — simulated locally, no
  /// Google/Apple/Firebase call actually happens. See `social_sign_in.dart`.
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

/// Local session state. No backend in this build — every launch starts
/// anonymous, and [AccountController] moves it to `account` by simulating a
/// sign-in rather than calling a real identity provider.
final _sessionProvider = StateProvider<AccountStatus>(
  (ref) => const AccountStatus(kind: SessionKind.anonymous),
);

final accountStatusProvider = Provider<AccountStatus>(
  (ref) => ref.watch(_sessionProvider),
);

/// Sign-in, sign-out and account deletion.
///
/// The state is the in-flight operation, so a screen can disable its buttons
/// and surface an error without owning any of this itself. No backend in this
/// build: every method below only touches local state — see
/// `social_sign_in.dart` for the simulated provider handshake.
class AccountController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Runs the (simulated) provider sheet and adopts the result as the
  /// session. Returns false when the user backed out, so the caller can
  /// distinguish "cancelled" from "failed" without inspecting the error.
  Future<bool> signIn(SocialProvider provider) async {
    state = const AsyncLoading();

    try {
      final social = ref.read(socialSignInProvider);
      final identity = switch (provider) {
        SocialProvider.apple => await social.apple(),
        SocialProvider.google => await social.google(),
      };

      ref.read(_sessionProvider.notifier).state = AccountStatus(
        kind: SessionKind.account,
        email: identity.email,
        displayName: identity.displayName,
        photoUrl: identity.photoUrl,
        providerIds: [
          provider == SocialProvider.apple ? 'apple.com' : 'google.com',
        ],
      );

      _adoptProfileDetails(identity);

      state = const AsyncData(null);
      return true;
    } on SignInCancelled {
      state = const AsyncData(null);
      return false;
    } catch (error, stack) {
      state = AsyncError(error, stack);
      return false;
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
