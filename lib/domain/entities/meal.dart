class Meal {
  const Meal({
    required this.id,
    required this.name,
    required this.item,
    required this.calories,
    required this.carbs,
    required this.protein,
    required this.fat,
    required this.logged,
  });

  final int id;
  final String name;
  final String item;
  final int calories;
  final int carbs;
  final int protein;
  final int fat;
  final bool logged;

  String get calorieLabel => logged ? '$calories kcal' : '—';
  String get itemLabel => logged ? item : 'Not logged yet';
  String get macroText =>
      logged ? 'Carbs ${carbs}g · Protein ${protein}g · Fat ${fat}g' : '';

  Meal copyWith({
    String? item,
    int? calories,
    int? carbs,
    int? protein,
    int? fat,
    bool? logged,
  }) {
    return Meal(
      id: id,
      name: name,
      item: item ?? this.item,
      calories: calories ?? this.calories,
      carbs: carbs ?? this.carbs,
      protein: protein ?? this.protein,
      fat: fat ?? this.fat,
      logged: logged ?? this.logged,
    );
  }
}
