import 'gender.dart';
import 'health_goal.dart';

class UserProfile {
  const UserProfile({
    required this.name,
    required this.age,
    required this.gender,
    required this.goal,
  });

  final String name;
  final String age;
  final Gender gender;
  final HealthGoal goal;

  factory UserProfile.initial() => const UserProfile(
    name: '',
    age: '',
    gender: Gender.female,
    goal: HealthGoal.generalWellness,
  );

  bool get isComplete => name.trim().isNotEmpty && age.trim().isNotEmpty;

  String get greetingName => name.trim().isNotEmpty ? name.trim() : 'there';

  String get initial => greetingName[0].toUpperCase();

  UserProfile copyWith({
    String? name,
    String? age,
    Gender? gender,
    HealthGoal? goal,
  }) {
    return UserProfile(
      name: name ?? this.name,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      goal: goal ?? this.goal,
    );
  }
}
