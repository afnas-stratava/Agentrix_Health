import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>(
  (ref) => FirebaseAuth.instance,
);

final authStateChangesProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

/// The signed-in user's uid, if already available. Prefer [ensureSignedIn]
/// on paths that need a uid to do work — this is just for read-only display.
final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(authStateChangesProvider).valueOrNull?.uid;
});

/// Returns the current uid, signing in anonymously first if needed. Startup
/// (see main.dart) already attempts this once, but that attempt can fail —
/// project not fully configured yet, device was offline — so anything that
/// actually needs a uid to persist data retries here instead of giving up
/// for the rest of the session.
Future<String?> ensureSignedIn(Ref ref) async {
  final auth = ref.read(firebaseAuthProvider);
  final existing = auth.currentUser;
  if (existing != null) return existing.uid;

  final credential = await auth.signInAnonymously();
  return credential.user?.uid;
}
