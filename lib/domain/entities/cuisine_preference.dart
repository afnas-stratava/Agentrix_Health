enum CuisinePreference {
  indian,
  mediterranean,
  eastAsian,
  mexican,
  middleEastern,
  american,
  vegetarian;

  String get label => switch (this) {
    CuisinePreference.indian => 'Indian',
    CuisinePreference.mediterranean => 'Mediterranean',
    CuisinePreference.eastAsian => 'East Asian',
    CuisinePreference.mexican => 'Mexican',
    CuisinePreference.middleEastern => 'Middle Eastern',
    CuisinePreference.american => 'American',
    CuisinePreference.vegetarian => 'Vegetarian',
  };
}
