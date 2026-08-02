import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/auth/social_sign_in.dart';
import 'auth_providers.dart';
import 'repository_providers.dart';
import 'user_profile_provider.dart';

final socialSignInProvider = Provider<SocialSignIn>((ref) => SocialSignIn());

/// How the current session was established.
enum SessionKind {
  /// No Firebase user at all — misconfigured project, or offline first run.
  none,

  /// The bootstrap uid every install gets. Data is real but unrecoverable if
  /// the app is deleted.
  anonymous,

  /// Signed in with Apple or Google.
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

  /// e.g. `apple.com`, `google.com`. A user can have both after linking.
  final List<String> providerIds;

  bool get isAccount => kind == SessionKind.account;

  /// What to call the account in the UI when there is no email — Apple users
  /// who hid their address have a relay address, but users who declined the
  /// email scope entirely have nothing.
  String get label => email ?? displayName ?? 'Signed in';
}

final accountStatusProvider = Provider<AccountStatus>((ref) {
  final user = ref.watch(authStateChangesProvider).valueOrNull;
  if (user == null) return const AccountStatus(kind: SessionKind.none);

  return AccountStatus(
    kind: user.isAnonymous ? SessionKind.anonymous : SessionKind.account,
    email: user.email,
    displayName: user.displayName,
    photoUrl: user.photoURL,
    providerIds: user.providerData.map((p) => p.providerId).toList(),
  );
});

/// Sign-in, sign-out and account deletion.
///
/// The state is the in-flight operation, so a screen can disable its buttons
/// and surface an error without owning any of this itself.
class AccountController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  FirebaseAuth get _auth => ref.read(firebaseAuthProvider);

  /// Runs the provider sheet, then attaches the result to the current session.
  ///
  /// Returns false when the user backed out, so the caller can distinguish
  /// "cancelled" from "failed" without inspecting the error.
  Future<bool> signIn(SocialProvider provider) async {
    state = const AsyncLoading();

    try {
      final social = ref.read(socialSignInProvider);
      final identity = switch (provider) {
        SocialProvider.apple => await social.apple(),
        SocialProvider.google => await social.google(),
      };

      final user = await _attach(identity.credential);

      // The uid may have just changed — signing into an account that already
      // exists abandons the anonymous one — so the profile in memory belongs
      // to the wrong user until this re-read completes.
      await ref.read(userProfileProvider.notifier).hydrate();

      await _adoptProfileDetails(user, identity);

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

  /// Upgrades the anonymous session in place where possible.
  ///
  /// `linkWithCredential` *keeps the uid*, so everything already written under
  /// `health_profiles/{uid}` carries over with no migration. Only when that
  /// Apple ID or Google account is already attached to a different Firebase
  /// user — a reinstall, or a second device — is there nothing to preserve, and
  /// the existing account wins over the throwaway anonymous one.
  Future<User> _attach(AuthCredential credential) async {
    final current = _auth.currentUser;

    if (current != null && current.isAnonymous) {
      try {
        final result = await current.linkWithCredential(credential);
        return result.user!;
      } on FirebaseAuthException catch (error) {
        const collisions = {
          'credential-already-in-use',
          'email-already-in-use',
          'provider-already-linked',
        };
        if (!collisions.contains(error.code)) rethrow;

        // Firebase hands back a usable credential on collision; prefer it, as
        // one-time tokens (Apple's) cannot be replayed.
        final result = await _auth.signInWithCredential(
          error.credential ?? credential,
        );
        return result.user!;
      }
    }

    final result = await _auth.signInWithCredential(credential);
    return result.user!;
  }

  /// Writes through anything the provider told us that the profile lacks.
  ///
  /// Apple gives the name on the first authorization only, so "later" does not
  /// exist — if the profile has no name yet, this is the one chance to fill it.
  /// Apple never gives a photo at all; Google gives one every sign-in.
  Future<void> _adoptProfileDetails(User user, SocialIdentity identity) async {
    final name = identity.displayName;
    if (name != null && name.isNotEmpty) {
      if ((user.displayName ?? '').isEmpty) {
        try {
          await user.updateDisplayName(name);
        } catch (error) {
          debugPrint('Could not set displayName: $error');
        }
      }

      if (ref.read(userProfileProvider).name.trim().isEmpty) {
        ref.read(userProfileProvider.notifier).setName(name);
      }
    }

    final photoUrl = identity.photoUrl;
    if (photoUrl != null && photoUrl.isNotEmpty) {
      if ((user.photoURL ?? '').isEmpty) {
        try {
          await user.updatePhotoURL(photoUrl);
        } catch (error) {
          debugPrint('Could not set photoURL: $error');
        }
      }

      if ((ref.read(userProfileProvider).photoUrl ?? '').isEmpty) {
        ref.read(userProfileProvider.notifier).setPhotoUrl(photoUrl);
      }
    }
  }

  /// Ends the session and returns the app to a signed-out state.
  Future<void> signOut() async {
    state = const AsyncLoading();
    try {
      await ref.read(socialSignInProvider).signOut();
      await _auth.signOut();
      await _restoreAnonymousSession();

      // Clearing the profile is not cosmetic. It stays in memory across a sign
      // out, and the next debounced write would persist it against the *new*
      // anonymous uid — which the next person to sign in on this phone then
      // links onto, inheriting a stranger's name, age and conditions. The
      // signed-out user's own document is untouched and comes back when they
      // sign in again.
      ref.read(userProfileProvider.notifier).reset();

      state = const AsyncData(null);
    } catch (error, stack) {
      state = AsyncError(error, stack);
    }
  }

  /// Puts the session back on an anonymous uid, if the project allows one.
  ///
  /// Best-effort by design. Anonymous auth is a *convenience* here, not a
  /// requirement: it keeps write paths alive between sessions and is what an
  /// existing install links its history onto. A project with the provider
  /// switched off throws `admin-restricted-operation`, and the correct outcome
  /// there is simply no user — which the sign-in gate already blocks on, the
  /// same as it blocks on an anonymous one. Letting this throw would instead
  /// leave the caller in an error state after a sign-out that had, in fact,
  /// succeeded.
  Future<void> _restoreAnonymousSession() async {
    try {
      await _auth.signInAnonymously();
    } on FirebaseAuthException catch (error) {
      if (error.code != 'admin-restricted-operation' &&
          error.code != 'operation-not-allowed') {
        rethrow;
      }
      debugPrint('Anonymous auth is disabled; staying signed out.');
    }
  }

  /// Deletes the Firebase user and the cloud copy of their profile.
  ///
  /// Required by App Store guideline 5.1.1(v): an app that creates accounts has
  /// to let them be deleted from inside the app. Local data is the caller's to
  /// clear — this only removes what left the device.
  ///
  /// Firebase refuses to delete a user whose sign-in is more than a few minutes
  /// old, so [reauthenticate] runs the provider sheet again on demand.
  /// Returns false when nothing was deleted — the re-auth sheet was dismissed,
  /// or the delete failed. The caller must not clear local data on a false.
  Future<bool> deleteAccount({
    required Future<SocialIdentity?> Function() reauthenticate,
  }) async {
    state = const AsyncLoading();

    try {
      final user = _auth.currentUser;
      if (user == null) {
        state = const AsyncData(null);
        return false;
      }

      // Delete the document before the user: once the user is gone the rules
      // reject the write, and the profile would be stranded in Firestore.
      await ref.read(userProfileRepositoryProvider).delete(user.uid);

      try {
        await user.delete();
      } on FirebaseAuthException catch (error) {
        if (error.code != 'requires-recent-login') rethrow;

        final identity = await reauthenticate();
        if (identity == null) {
          state = const AsyncData(null);
          return false;
        }
        await user.reauthenticateWithCredential(identity.credential);
        await user.delete();
      }

      await ref.read(socialSignInProvider).signOut();
      await _restoreAnonymousSession();
      state = const AsyncData(null);
      return true;
    } catch (error, stack) {
      state = AsyncError(error, stack);
      return false;
    }
  }
}

final accountControllerProvider =
    AsyncNotifierProvider<AccountController, void>(AccountController.new);

/// Turns a Firebase error into something worth showing a user.
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
