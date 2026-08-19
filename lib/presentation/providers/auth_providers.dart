import 'package:flutter_riverpod/flutter_riverpod.dart';

/// No backend in this build. Every install reads and writes the same local
/// profile record — see `PrefsUserProfileRepository`. Kept as a named
/// constant + an async function (matching the old Firebase-backed shape)
/// so a real auth backend can replace just this file without touching any
/// caller.
const String localProfileId = 'local-device';

final currentUserIdProvider = Provider<String?>((ref) => localProfileId);

/// Returns the current profile id. Named to match the pre-backend-removal
/// signature (`Future<String?> ensureSignedIn(Ref ref)`), which callers
/// await without knowing whether that meant a real network round trip.
Future<String?> ensureSignedIn(Ref ref) async => localProfileId;

/// The current Google ID token, in memory only — never persisted (see
/// `session_storage.dart`) and gone the moment the session ends or the app
/// restarts. Set by [AccountController.signIn]/`signOut` in
/// `account_provider.dart`; lives here instead so both that file and
/// `user_profile_provider.dart` can read it without importing each other.
final googleIdTokenProvider = StateProvider<String?>((ref) => null);
