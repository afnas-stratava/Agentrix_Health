import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/allergy.dart';
import '../../domain/entities/cuisine_preference.dart';
import '../../domain/entities/gender.dart';
import '../../domain/entities/health_goal.dart';
import '../../domain/entities/profile/cycle_profile.dart';
import '../../domain/entities/profile/diet_pattern.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/user_profile_repository.dart';

/// The declared health profile, on the device.
///
/// No backend in this build: [uid] is accepted on every method only for
/// interface compatibility with whatever real repository replaces this one —
/// this implementation is single-profile, every uid reads and writes the same
/// local record. Mirrors `FirestoreUserProfileRepository`'s field mapping
/// exactly, so swapping the real repository back in later is a one-file
/// change with no schema migration.
class PrefsUserProfileRepository implements UserProfileRepository {
  PrefsUserProfileRepository();

  static const _key = 'user_profile.v1';

  @override
  Future<UserProfile?> fetch(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return _fromMap(Map<String, dynamic>.from(decoded));
    } catch (error) {
      debugPrint('Discarding unreadable profile: $error');
      return null;
    }
  }

  @override
  Future<void> save(String uid, UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(profile.toJson()));
  }

  @override
  Future<void> delete(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  UserProfile _fromMap(Map<String, dynamic> map) {
    final initial = UserProfile.initial();

    return UserProfile(
      name: map['name'] as String? ?? initial.name,
      age: map['age'] as String? ?? initial.age,
      gender: _enumFrom(Gender.values, map['gender']) ?? initial.gender,
      goals: _enumSetFrom(HealthGoal.values, map['goals']).isNotEmpty
          ? _enumSetFrom(HealthGoal.values, map['goals'])
          : initial.goals,
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
      photoUrl: map['photoUrl'] as String?,
    );
  }

  T? _enumFrom<T extends Enum>(List<T> values, Object? name) {
    if (name is! String) return null;
    for (final value in values) {
      if (value.name == name) return value;
    }
    return null;
  }

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
