enum Allergy {
  peanuts,
  treeNuts,
  dairy,
  gluten,
  soy,
  eggs;

  String get label => switch (this) {
    Allergy.peanuts => 'Peanuts',
    Allergy.treeNuts => 'Tree nuts',
    Allergy.dairy => 'Dairy',
    Allergy.gluten => 'Gluten',
    Allergy.soy => 'Soy',
    Allergy.eggs => 'Eggs',
  };
}
