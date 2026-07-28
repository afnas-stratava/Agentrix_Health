import 'allergy.dart';
import 'cuisine_preference.dart';
import 'gender.dart';
import 'health_goal.dart';

class UserProfile {
  const UserProfile({
    required this.name,
    required this.age,
    required this.gender,
    required this.goal,
    required this.cuisines,
    required this.allergies,
    required this.customRestrictions,
  });

  final String name;
  final String age;
  final Gender gender;
  final HealthGoal goal;
  final Set<CuisinePreference> cuisines;
  final Set<Allergy> allergies;
  final List<String> customRestrictions;

  factory UserProfile.initial() => const UserProfile(
    name: '',
    age: '',
    gender: Gender.female,
    goal: HealthGoal.generalWellness,
    cuisines: {},
    allergies: {},
    customRestrictions: [],
  );

  bool get isComplete => name.trim().isNotEmpty && age.trim().isNotEmpty;

  String get greetingName => name.trim().isNotEmpty ? name.trim() : 'there';

  String get initial => greetingName[0].toUpperCase();

  UserProfile copyWith({
    String? name,
    String? age,
    Gender? gender,
    HealthGoal? goal,
    Set<CuisinePreference>? cuisines,
    Set<Allergy>? allergies,
    List<String>? customRestrictions,
  }) {
    return UserProfile(
      name: name ?? this.name,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      goal: goal ?? this.goal,
      cuisines: cuisines ?? this.cuisines,
      allergies: allergies ?? this.allergies,
      customRestrictions: customRestrictions ?? this.customRestrictions,
    );
  }
}
