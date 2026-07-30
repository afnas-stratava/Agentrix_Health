/// Ported from `AllergenSchema` in `src/schemas/profile.ts`.
///
/// This is the allergen vocabulary the food database tags against, so an
/// allergy selected during onboarding becomes a *hard filter* in the dish
/// ranker and in the brief's food examples — not a warning label.
enum Allergy {
  peanuts('peanut', 'Peanuts'),
  treeNuts('tree-nut', 'Tree nuts'),
  dairy('dairy', 'Dairy'),
  gluten('gluten', 'Gluten'),
  soy('soy', 'Soy'),
  eggs('egg', 'Eggs'),
  shellfish('shellfish', 'Shellfish'),
  fish('fish', 'Fish'),
  sesame('sesame', 'Sesame');

  const Allergy(this.wireName, this.label);

  /// Matches the allergen strings used in the food table.
  final String wireName;

  final String label;

  static Allergy? fromWireName(String value) {
    for (final allergy in Allergy.values) {
      if (allergy.wireName == value) return allergy;
    }
    return null;
  }
}
