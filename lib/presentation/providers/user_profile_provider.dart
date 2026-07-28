import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  void reset() => state = UserProfile.initial();
}

final userProfileProvider = NotifierProvider<UserProfileNotifier, UserProfile>(
  UserProfileNotifier.new,
);
