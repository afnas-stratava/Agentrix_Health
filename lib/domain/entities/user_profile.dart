import 'allergy.dart';
import 'cuisine_preference.dart';
import 'gender.dart';
import 'health_goal.dart';
import 'profile/cuisine.dart';
import 'profile/cycle_profile.dart';
import 'profile/diet_pattern.dart';

/// The user-declared half of the health picture.
///
/// Everything here is *stated*, never inferred: telemetry tells us how someone
/// slept and blood work tells us what is circulating, but only the user can
/// tell us they are vegetarian, allergic to peanuts, or training for a race.
///
/// The targets calculator, the morning brief and the restaurant ranker all read
/// from this class, so a field added here shows up in three features at once.
/// Onboarding collects the first seven; the rest carry defaults good enough to
/// compute with and are editable from the Profile tab.
class UserProfile {
  const UserProfile({
    required this.name,
    required this.age,
    required this.gender,
    required this.cuisines,
    required this.allergies,
    required this.customRestrictions,
    this.goals = const {HealthGoal.generalWellness},
    this.heightCm,
    this.weightKg,
    this.targetWeightKg,
    this.activityLevel = ActivityLevel.light,
    this.dietPattern = DietPattern.omnivore,
    this.restrictions = const {},
    this.conditions = const {},
    this.cycle = const CycleProfile(),
    this.photoUrl,
  });

  final String name;

  /// Bound straight to a text field, so it stays a `String`; anything that
  /// needs to compute reads [ageYears].
  final String age;

  final Gender gender;
  final Set<HealthGoal> goals;

  HealthGoal get goal =>
      goals.isNotEmpty ? goals.first : HealthGoal.generalWellness;

  /// Ordered by preference — the first pick carries the most weight when
  /// suggesting a meal, so this is a list rather than a set.
  final List<CuisinePreference> cuisines;
  final Set<Allergy> allergies;
  final List<String> customRestrictions;

  final double? heightCm;
  final double? weightKg;
  final double? targetWeightKg;

  /// Self-declared; used only when no wearable energy data exists.
  final ActivityLevel activityLevel;

  final DietPattern dietPattern;
  final Set<Restriction> restrictions;
  final Set<Condition> conditions;
  final CycleProfile cycle;

  /// From the sign-in provider (Google always has one, Apple never does).
  /// Never user-editable, so there is no onboarding screen that sets it.
  final String? photoUrl;

  factory UserProfile.initial() => const UserProfile(
    name: '',
    age: '',
    gender: Gender.female,
    goals: {HealthGoal.generalWellness},
    cuisines: [],
    allergies: {},
    customRestrictions: [],
  );

  bool get isComplete => name.trim().isNotEmpty && age.trim().isNotEmpty;

  String get greetingName => name.trim().isNotEmpty ? name.trim() : 'there';

  String get initial => greetingName[0].toUpperCase();

  int? get ageYears {
    final parsed = int.tryParse(age.trim());
    if (parsed == null || parsed < 10 || parsed > 120) return null;
    return parsed;
  }

  /// The ranker's cuisine vocabulary, expanded from the onboarding chips.
  List<Cuisine> get rankedCuisines => expandCuisinePreferences(cuisines);

  /// True once we know enough to compute calorie and macro targets.
  bool get canComputeTargets =>
      heightCm != null && weightKg != null && ageYears != null;

  double? get bodyMassIndex {
    final height = heightCm;
    final weight = weightKg;
    if (height == null || weight == null) return null;
    final metres = height / 100;
    return (weight / (metres * metres) * 10).round() / 10;
  }

  /// A "Vegetarian" *cuisine* chip is really a diet declaration; honour it as
  /// one, unless the user has already stated something stricter.
  DietPattern get effectiveDietPattern {
    if (dietPattern != DietPattern.omnivore) return dietPattern;
    return cuisines.contains(CuisinePreference.vegetarian)
        ? DietPattern.vegetarian
        : DietPattern.omnivore;
  }

  /// The wire format shared by every place this profile leaves the app —
  /// local storage today, the backend sync in `user_profile_provider.dart`.
  /// Keeping it here means both stay byte-for-byte identical without either
  /// one importing the other.
  Map<String, dynamic> toJson() => {
    'name': name,
    'age': age,
    'gender': gender.name,
    'goals': goals.map((g) => g.name).toList(),
    'cuisines': cuisines.map((c) => c.name).toList(),
    'allergies': allergies.map((a) => a.name).toList(),
    'customRestrictions': customRestrictions,
    'heightCm': heightCm,
    'weightKg': weightKg,
    'targetWeightKg': targetWeightKg,
    'activityLevel': activityLevel.name,
    'dietPattern': dietPattern.name,
    'restrictions': restrictions.map((r) => r.name).toList(),
    'conditions': conditions.map((c) => c.name).toList(),
    'cycle': cycle.toJson(),
    'photoUrl': photoUrl,
  };

  UserProfile copyWith({
    String? name,
    String? age,
    Gender? gender,
    Set<HealthGoal>? goals,
    HealthGoal? goal,
    List<CuisinePreference>? cuisines,
    Set<Allergy>? allergies,
    List<String>? customRestrictions,
    double? heightCm,
    double? weightKg,
    double? targetWeightKg,
    ActivityLevel? activityLevel,
    DietPattern? dietPattern,
    Set<Restriction>? restrictions,
    Set<Condition>? conditions,
    CycleProfile? cycle,
    String? photoUrl,
  }) {
    return UserProfile(
      name: name ?? this.name,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      goals: goals ?? (goal != null ? {goal} : this.goals),
      cuisines: cuisines ?? this.cuisines,
      allergies: allergies ?? this.allergies,
      customRestrictions: customRestrictions ?? this.customRestrictions,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      targetWeightKg: targetWeightKg ?? this.targetWeightKg,
      activityLevel: activityLevel ?? this.activityLevel,
      dietPattern: dietPattern ?? this.dietPattern,
      restrictions: restrictions ?? this.restrictions,
      conditions: conditions ?? this.conditions,
      cycle: cycle ?? this.cycle,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }
}
