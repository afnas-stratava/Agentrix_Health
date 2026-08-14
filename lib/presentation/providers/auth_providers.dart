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
