enum CuisinePreference {
  american,
  mexican,
  mediterranean,
  indian,
  eastAsian,
  middleEastern,
  vegetarian;

  String get label => switch (this) {
    CuisinePreference.american => 'American',
    CuisinePreference.mexican => 'Mexican',
    CuisinePreference.mediterranean => 'Mediterranean',
    CuisinePreference.indian => 'Indian',
    CuisinePreference.eastAsian => 'East Asian',
    CuisinePreference.middleEastern => 'Middle Eastern',
    CuisinePreference.vegetarian => 'Vegetarian',
  };
}
