import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/allergy.dart';
import '../../domain/entities/cuisine_preference.dart';
import '../../domain/entities/gender.dart';
import '../../domain/entities/health_goal.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/user_profile_repository.dart';

/// Persists the onboarding "Health Profile" (age, gender, goal, dietary
/// preferences, allergies) to Cloud Firestore at `health_profiles/{uid}`.
class FirestoreUserProfileRepository implements UserProfileRepository {
  FirestoreUserProfileRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('health_profiles');

  @override
  Future<UserProfile?> fetch(String uid) async {
    final snapshot = await _collection.doc(uid).get();
    final data = snapshot.data();
    if (data == null) return null;
    return _fromMap(data);
  }

  @override
  Future<void> save(String uid, UserProfile profile) {
    return _collection.doc(uid).set(_toMap(profile));
  }

  Map<String, dynamic> _toMap(UserProfile profile) {
    return {
      'name': profile.name,
      'age': profile.age,
      'gender': profile.gender.name,
      'goal': profile.goal.name,
      'cuisines': profile.cuisines.map((c) => c.name).toList(),
      'allergies': profile.allergies.map((a) => a.name).toList(),
      'customRestrictions': profile.customRestrictions,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  UserProfile _fromMap(Map<String, dynamic> map) {
    final initial = UserProfile.initial();
    return UserProfile(
      name: map['name'] as String? ?? initial.name,
      age: map['age'] as String? ?? initial.age,
      gender: _enumFrom(Gender.values, map['gender']) ?? initial.gender,
      goal: _enumFrom(HealthGoal.values, map['goal']) ?? initial.goal,
      cuisines: _enumSetFrom(CuisinePreference.values, map['cuisines']),
      allergies: _enumSetFrom(Allergy.values, map['allergies']),
      customRestrictions:
          (map['customRestrictions'] as List?)?.cast<String>() ?? const [],
    );
  }

  T? _enumFrom<T extends Enum>(List<T> values, Object? name) {
    if (name is! String) return null;
    for (final value in values) {
      if (value.name == name) return value;
    }
    return null;
  }

  Set<T> _enumSetFrom<T extends Enum>(List<T> values, Object? rawList) {
    if (rawList is! List) return {};
    return rawList
        .map((name) => _enumFrom(values, name))
        .whereType<T>()
        .toSet();
  }
}
