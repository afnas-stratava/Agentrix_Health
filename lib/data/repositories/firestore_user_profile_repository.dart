import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/allergy.dart';
import '../../domain/entities/cuisine_preference.dart';
import '../../domain/entities/gender.dart';
import '../../domain/entities/health_goal.dart';
import '../../domain/entities/profile/cycle_profile.dart';
import '../../domain/entities/profile/diet_pattern.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/user_profile_repository.dart';

/// Persists the "Health Profile" — the declared half of the health picture —
/// to Cloud Firestore at `health_profiles/{uid}`.
///
/// Every field is read back defensively: a document written by an older build
/// is missing the body-composition and diet fields entirely, and the profile
/// must degrade to its defaults rather than failing to load at all.
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
      'heightCm': profile.heightCm,
      'weightKg': profile.weightKg,
      'targetWeightKg': profile.targetWeightKg,
      'activityLevel': profile.activityLevel.name,
      'dietPattern': profile.dietPattern.name,
      'restrictions': profile.restrictions.map((r) => r.name).toList(),
      'conditions': profile.conditions.map((c) => c.name).toList(),
      'cycle': profile.cycle.toJson(),
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
      cuisines: _enumListFrom(CuisinePreference.values, map['cuisines']),
      allergies: _enumSetFrom(Allergy.values, map['allergies']),
      customRestrictions:
          (map['customRestrictions'] as List?)?.cast<String>() ?? const [],
      heightCm: (map['heightCm'] as num?)?.toDouble(),
      weightKg: (map['weightKg'] as num?)?.toDouble(),
      targetWeightKg: (map['targetWeightKg'] as num?)?.toDouble(),
      activityLevel:
          _enumFrom(ActivityLevel.values, map['activityLevel']) ??
          initial.activityLevel,
      dietPattern:
          _enumFrom(DietPattern.values, map['dietPattern']) ??
          initial.dietPattern,
      restrictions: _enumSetFrom(Restriction.values, map['restrictions']),
      conditions: _enumSetFrom(Condition.values, map['conditions']),
      cycle: map['cycle'] is Map
          ? CycleProfile.fromJson(
              Map<String, dynamic>.from(map['cycle'] as Map),
            )
          : initial.cycle,
    );
  }

  T? _enumFrom<T extends Enum>(List<T> values, Object? name) {
    if (name is! String) return null;
    for (final value in values) {
      if (value.name == name) return value;
    }
    return null;
  }

  /// Order is meaningful for cuisines, so this preserves it (and drops
  /// duplicates) rather than going through a set.
  List<T> _enumListFrom<T extends Enum>(List<T> values, Object? rawList) {
    if (rawList is! List) return const [];
    final ordered = <T>[];
    for (final name in rawList) {
      final value = _enumFrom(values, name);
      if (value != null && !ordered.contains(value)) ordered.add(value);
    }
    return ordered;
  }

  Set<T> _enumSetFrom<T extends Enum>(List<T> values, Object? rawList) {
    if (rawList is! List) return {};
    return rawList
        .map((name) => _enumFrom(values, name))
        .whereType<T>()
        .toSet();
  }
}
