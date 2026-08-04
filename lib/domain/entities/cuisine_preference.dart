enum CuisinePreference {
  american,
  mexican,
  mediterranean,
  indian,
  chinese,
  korean,
  vegetarian;

  String get label => switch (this) {
    CuisinePreference.american => 'American',
    CuisinePreference.mexican => 'Mexican',
    CuisinePreference.mediterranean => 'Mediterranean',
    CuisinePreference.indian => 'Indian',
    CuisinePreference.chinese => 'Chinese',
    CuisinePreference.korean => 'Korean',
    CuisinePreference.vegetarian => 'Vegetarian',
  };
}
