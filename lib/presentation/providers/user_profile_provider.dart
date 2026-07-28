import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/allergy.dart';
import '../../domain/entities/cuisine_preference.dart';
import '../../domain/entities/gender.dart';
import '../../domain/entities/health_goal.dart';
import '../../domain/entities/user_profile.dart';

class UserProfileNotifier extends Notifier<UserProfile> {
  @override
  UserProfile build() => UserProfile.initial();

  void setName(String name) => state = state.copyWith(name: name);
  void setAge(String age) => state = state.copyWith(age: age);
  void setGender(Gender gender) => state = state.copyWith(gender: gender);
  void setGoal(HealthGoal goal) => state = state.copyWith(goal: goal);

  void toggleCuisine(CuisinePreference cuisine) {
    final cuisines = Set<CuisinePreference>.from(state.cuisines);
    cuisines.contains(cuisine)
        ? cuisines.remove(cuisine)
        : cuisines.add(cuisine);
    state = state.copyWith(cuisines: cuisines);
  }

  void toggleAllergy(Allergy allergy) {
    final allergies = Set<Allergy>.from(state.allergies);
    allergies.contains(allergy)
        ? allergies.remove(allergy)
        : allergies.add(allergy);
    state = state.copyWith(allergies: allergies);
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
  }

  void removeCustomRestriction(String text) {
    state = state.copyWith(
      customRestrictions: state.customRestrictions
          .where((r) => r != text)
          .toList(),
    );
  }

  void reset() => state = UserProfile.initial();
}

final userProfileProvider = NotifierProvider<UserProfileNotifier, UserProfile>(
  UserProfileNotifier.new,
);
