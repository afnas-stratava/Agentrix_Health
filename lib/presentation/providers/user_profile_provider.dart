import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/allergy.dart';
import '../../domain/entities/cuisine_preference.dart';
import '../../domain/entities/gender.dart';
import '../../domain/entities/health_goal.dart';
import '../../domain/entities/user_profile.dart';
import 'auth_providers.dart';
import 'repository_providers.dart';

class UserProfileNotifier extends Notifier<UserProfile> {
  Timer? _persistDebounce;

  @override
  UserProfile build() {
    ref.onDispose(() => _persistDebounce?.cancel());
    unawaited(_hydrate());
    return UserProfile.initial();
  }

  Future<void> _hydrate() async {
    try {
      final uid = await ensureSignedIn(ref);
      if (uid == null) return;
      final saved = await ref.read(userProfileRepositoryProvider).fetch(uid);
      if (saved != null) state = saved;
    } catch (error) {
      // Background sync — if Firebase isn't reachable/configured (offline,
      // auth not set up yet, tests), the UI should keep working from local
      // state rather than surface this. Every write retries sign-in, so
      // fixing the underlying issue heals this without an app restart.
      debugPrint('UserProfileNotifier._hydrate failed: $error');
    }
  }

  void _persistNow() {
    unawaited(_persist());
  }

  Future<void> _persist() async {
    try {
      final uid = await ensureSignedIn(ref);
      if (uid == null) return;
      await ref.read(userProfileRepositoryProvider).save(uid, state);
    } catch (error) {
      debugPrint('UserProfileNotifier._persistNow failed: $error');
    }
  }

  /// Coalesces rapid-fire updates (every keystroke in the name/age fields)
  /// into a single write instead of one per character.
  void _persistDebounced() {
    _persistDebounce?.cancel();
    _persistDebounce = Timer(const Duration(milliseconds: 500), _persistNow);
  }

  void setName(String name) {
    state = state.copyWith(name: name);
    _persistDebounced();
  }

  void setAge(String age) {
    state = state.copyWith(age: age);
    _persistDebounced();
  }

  void setGender(Gender gender) {
    state = state.copyWith(gender: gender);
    _persistNow();
  }

  void setGoal(HealthGoal goal) {
    state = state.copyWith(goal: goal);
    _persistNow();
  }

  void toggleCuisine(CuisinePreference cuisine) {
    final cuisines = Set<CuisinePreference>.from(state.cuisines);
    cuisines.contains(cuisine)
        ? cuisines.remove(cuisine)
        : cuisines.add(cuisine);
    state = state.copyWith(cuisines: cuisines);
    _persistNow();
  }

  void toggleAllergy(Allergy allergy) {
    final allergies = Set<Allergy>.from(state.allergies);
    allergies.contains(allergy)
        ? allergies.remove(allergy)
        : allergies.add(allergy);
    state = state.copyWith(allergies: allergies);
    _persistNow();
  }

  void addCustomRestriction(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final exists = state.customRestrictions.any(
      (r) => r.toLowerCase() == trimmed.toLowerCase(),
    );
    if (exists) return;
    state = state.copyWith(
      customRestrictions: [...state.customRestrictions, trimmed],
    );
    _persistNow();
  }

  void removeCustomRestriction(String text) {
    state = state.copyWith(
      customRestrictions: state.customRestrictions
          .where((r) => r != text)
          .toList(),
    );
    _persistNow();
  }

  void reset() {
    _persistDebounce?.cancel();
    state = UserProfile.initial();
    _persistNow();
  }
}

final userProfileProvider = NotifierProvider<UserProfileNotifier, UserProfile>(
  UserProfileNotifier.new,
);
