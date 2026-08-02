import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/allergy.dart';
import '../../domain/entities/cuisine_preference.dart';
import '../../domain/entities/gender.dart';
import '../../domain/entities/health_goal.dart';
import '../../domain/entities/profile/cycle_profile.dart';
import '../../domain/entities/profile/diet_pattern.dart';
import '../../domain/entities/user_profile.dart';
import 'auth_providers.dart';
import 'repository_providers.dart';

class UserProfileNotifier extends Notifier<UserProfile> {
  Timer? _persistDebounce;

  @override
  UserProfile build() {
    ref.onDispose(() => _persistDebounce?.cancel());
    unawaited(hydrate());
    return UserProfile.initial();
  }

  /// Loads the profile stored against the *current* uid.
  ///
  /// Public because the uid changes under this notifier: signing into an
  /// account that already exists elsewhere swaps the uid, and without a
  /// re-read the screen would keep showing whatever the previous session had
  /// in memory until the next app launch.
  Future<void> hydrate() async {
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
      debugPrint('UserProfileNotifier.hydrate failed: $error');
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

  void setPhotoUrl(String url) {
    state = state.copyWith(photoUrl: url);
    _persistNow();
  }

  void toggleCuisine(CuisinePreference cuisine) {
    final cuisines = [...state.cuisines];
    // Appending keeps the tap order, which is what the rank badges show.
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

  void setBodyComposition({double? heightCm, double? weightKg}) {
    state = state.copyWith(heightCm: heightCm, weightKg: weightKg);
    _persistDebounced();
  }

  void setTargetWeight(double? weightKg) {
    state = state.copyWith(targetWeightKg: weightKg);
    _persistDebounced();
  }

  void setActivityLevel(ActivityLevel level) {
    state = state.copyWith(activityLevel: level);
    _persistNow();
  }

  void setDietPattern(DietPattern pattern) {
    state = state.copyWith(dietPattern: pattern);
    _persistNow();
  }

  void toggleRestriction(Restriction restriction) {
    final next = Set<Restriction>.from(state.restrictions);
    next.contains(restriction)
        ? next.remove(restriction)
        : next.add(restriction);
    state = state.copyWith(restrictions: next);
    _persistNow();
  }

  void toggleCondition(Condition condition) {
    final next = Set<Condition>.from(state.conditions);
    next.contains(condition) ? next.remove(condition) : next.add(condition);
    state = state.copyWith(conditions: next);
    _persistNow();
  }

  /// Awaitable, unlike the fire-and-forget setters: logging a period start
  /// immediately re-renders the cycle surface, and a caller that wants to show a
  /// confirmation needs to know the write happened.
  Future<void> updateCycle(CycleProfile cycle) async {
    state = state.copyWith(cycle: cycle);
    await _persist();
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
