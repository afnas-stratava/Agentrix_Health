import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/config/api_endpoints.dart';
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
  Timer? _bodySyncDebounce;
  Timer? _goalsSyncDebounce;
  Timer? _dietSyncDebounce;

  @override
  UserProfile build() {
    ref.onDispose(() {
      _persistDebounce?.cancel();
      _bodySyncDebounce?.cancel();
      _goalsSyncDebounce?.cancel();
      _dietSyncDebounce?.cancel();
    });
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

  /// Write-behind backup of height/weight/age/activity level to the FastAPI
  /// backend (`PATCH /users/me/body`, see `app/api/users.py`) — the on-device
  /// copy above is the source of truth for reads, so a flaky connection here
  /// must not block onboarding. Silently drops if there's no signed-in
  /// session yet. Debounced separately from [_persistDebounced] so the three
  /// setters `body_screen.dart` fires back-to-back on Continue collapse into
  /// one request instead of three.
  void _syncBodyDebounced() {
    _bodySyncDebounce?.cancel();
    _bodySyncDebounce = Timer(const Duration(milliseconds: 500), _syncBody);
  }

  Future<void> _syncBody() async {
    final idToken = ref.read(googleIdTokenProvider);
    if (idToken == null) return;

    try {
      await http
          .patch(
            ApiEndpoints.updateBody,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'id_token': idToken,
              'height_cm': state.heightCm,
              'weight_kg': state.weightKg,
              'age': state.ageYears,
              'activity_level': state.activityLevel.wireName,
            }),
          )
          .timeout(const Duration(seconds: 10));
    } catch (error) {
      debugPrint('Could not sync body composition to backend: $error');
    }
  }

  /// Same write-behind pattern as [_syncBodyDebounced], covering the goal(s),
  /// target weight and managed conditions from `goals_screen.dart`
  /// (`PATCH /users/me/goals`).
  void _syncGoalsDebounced() {
    _goalsSyncDebounce?.cancel();
    _goalsSyncDebounce = Timer(const Duration(milliseconds: 500), _syncGoals);
  }

  Future<void> _syncGoals() async {
    final idToken = ref.read(googleIdTokenProvider);
    if (idToken == null) return;

    try {
      await http
          .patch(
            ApiEndpoints.updateGoals,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'id_token': idToken,
              'goals': state.goals.map((g) => g.name).toList(),
              'target_weight_kg': state.targetWeightKg,
              'conditions': state.conditions.map((c) => c.wireName).toList(),
            }),
          )
          .timeout(const Duration(seconds: 10));
    } catch (error) {
      debugPrint('Could not sync goals to backend: $error');
    }
  }

  /// Same write-behind pattern as [_syncBodyDebounced], covering the diet
  /// pattern, allergies, preferences and ranked cuisines from
  /// `diet_screen.dart` (`PATCH /users/me/diet`).
  void _syncDietDebounced() {
    _dietSyncDebounce?.cancel();
    _dietSyncDebounce = Timer(const Duration(milliseconds: 500), _syncDiet);
  }

  Future<void> _syncDiet() async {
    final idToken = ref.read(googleIdTokenProvider);
    if (idToken == null) return;

    try {
      await http
          .patch(
            ApiEndpoints.updateDiet,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'id_token': idToken,
              'diet_pattern': state.dietPattern.wireName,
              'allergies': state.allergies.map((a) => a.wireName).toList(),
              'restrictions': state.restrictions.map((r) => r.wireName).toList(),
              // Order carries the rank — see toggleCuisine.
              'cuisines': state.cuisines.map((c) => c.name).toList(),
            }),
          )
          .timeout(const Duration(seconds: 10));
    } catch (error) {
      debugPrint('Could not sync diet to backend: $error');
    }
  }

  void setName(String name) {
    state = state.copyWith(name: name);
    _persistDebounced();
  }

  void setAge(String age) {
    state = state.copyWith(age: age);
    _persistDebounced();
    _syncBodyDebounced();
  }

  void setGender(Gender gender) {
    state = state.copyWith(gender: gender);
    _persistNow();
  }

  void setGoal(HealthGoal goal) {
    state = state.copyWith(goals: {goal});
    _persistNow();
    _syncGoalsDebounced();
  }

  void setGoals(Set<HealthGoal> goals) {
    state = state.copyWith(
      goals: goals.isEmpty ? {HealthGoal.generalWellness} : goals,
    );
    _persistNow();
    _syncGoalsDebounced();
  }

  void toggleGoal(HealthGoal goal) {
    final next = Set<HealthGoal>.from(state.goals);
    if (next.contains(goal)) {
      if (next.length > 1) {
        next.remove(goal);
      }
    } else {
      next.add(goal);
    }
    state = state.copyWith(goals: next);
    _persistNow();
    _syncGoalsDebounced();
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
    _syncDietDebounced();
  }

  void toggleAllergy(Allergy allergy) {
    final allergies = Set<Allergy>.from(state.allergies);
    allergies.contains(allergy)
        ? allergies.remove(allergy)
        : allergies.add(allergy);
    state = state.copyWith(allergies: allergies);
    _persistNow();
    _syncDietDebounced();
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
    _syncBodyDebounced();
  }

  void setTargetWeight(double? weightKg) {
    state = state.copyWith(targetWeightKg: weightKg);
    _persistDebounced();
    _syncGoalsDebounced();
  }

  void setActivityLevel(ActivityLevel level) {
    state = state.copyWith(activityLevel: level);
    _persistNow();
    _syncBodyDebounced();
  }

  void setDietPattern(DietPattern pattern) {
    state = state.copyWith(dietPattern: pattern);
    _persistNow();
    _syncDietDebounced();
  }

  void toggleRestriction(Restriction restriction) {
    final next = Set<Restriction>.from(state.restrictions);
    next.contains(restriction)
        ? next.remove(restriction)
        : next.add(restriction);
    state = state.copyWith(restrictions: next);
    _persistNow();
    _syncDietDebounced();
  }

  void toggleCondition(Condition condition) {
    final next = Set<Condition>.from(state.conditions);
    next.contains(condition) ? next.remove(condition) : next.add(condition);
    state = state.copyWith(conditions: next);
    _persistNow();
    _syncGoalsDebounced();
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
    _bodySyncDebounce?.cancel();
    _goalsSyncDebounce?.cancel();
    _dietSyncDebounce?.cancel();
    state = UserProfile.initial();
    _persistNow();
  }
}

final userProfileProvider = NotifierProvider<UserProfileNotifier, UserProfile>(
  UserProfileNotifier.new,
);
