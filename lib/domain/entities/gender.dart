enum Gender {
  female,
  male;

  String get label => switch (this) {
    Gender.female => 'Female',
    Gender.male => 'Male',
  };
}
