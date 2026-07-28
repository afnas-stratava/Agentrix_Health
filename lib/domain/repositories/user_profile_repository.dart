import '../entities/user_profile.dart';

abstract interface class UserProfileRepository {
  /// Returns the saved profile for [uid], or null if none has been saved yet.
  Future<UserProfile?> fetch(String uid);

  Future<void> save(String uid, UserProfile profile);
}
