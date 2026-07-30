/// Ported from `MacrosSchema` in `src/schemas/nutrition.ts`.
///
/// Macros are stored per *logged portion*, not per 100 g — the user logged "two
/// rotis", and converting back and forth through a density figure is where
/// rounding error accumulates. The food database holds per-portion values; the
/// scaling happens once, at log time, and the result is what persists.
class Macros {
  const Macros({
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    this.fibreG = 0,
    this.addedSugarG = 0,
    this.sodiumMg = 0,
  });

  final int calories;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double fibreG;

  /// Free/added sugars, not total carbohydrate sugars.
  final double addedSugarG;

  final int sodiumMg;

  static const Macros empty = Macros(
    calories: 0,
    proteinG: 0,
    carbsG: 0,
    fatG: 0,
  );

  Macros operator +(Macros other) => Macros(
    calories: calories + other.calories,
    proteinG: proteinG + other.proteinG,
    carbsG: carbsG + other.carbsG,
    fatG: fatG + other.fatG,
    fibreG: fibreG + other.fibreG,
    addedSugarG: addedSugarG + other.addedSugarG,
    sodiumMg: sodiumMg + other.sodiumMg,
  );

  /// Scales a portion. Grams keep one decimal; calories and sodium are integers
  /// because a tenth of a kilocalorie is noise dressed up as precision.
  Macros scaled(double factor) {
    double round1(double value) => (value * 10).round() / 10;
    return Macros(
      calories: (calories * factor).round(),
      proteinG: round1(proteinG * factor),
      carbsG: round1(carbsG * factor),
      fatG: round1(fatG * factor),
      fibreG: round1(fibreG * factor),
      addedSugarG: round1(addedSugarG * factor),
      sodiumMg: (sodiumMg * factor).round(),
    );
  }

  factory Macros.fromJson(Map<String, dynamic> json) => Macros(
    calories: (json['calories'] as num?)?.round() ?? 0,
    proteinG: (json['proteinG'] as num?)?.toDouble() ?? 0,
    carbsG: (json['carbsG'] as num?)?.toDouble() ?? 0,
    fatG: (json['fatG'] as num?)?.toDouble() ?? 0,
    fibreG: (json['fibreG'] as num?)?.toDouble() ?? 0,
    addedSugarG: (json['addedSugarG'] as num?)?.toDouble() ?? 0,
    sodiumMg: (json['sodiumMg'] as num?)?.round() ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'calories': calories,
    'proteinG': proteinG,
    'carbsG': carbsG,
    'fatG': fatG,
    'fibreG': fibreG,
    'addedSugarG': addedSugarG,
    'sodiumMg': sodiumMg,
  };
}

Macros sumMacros(Iterable<Macros> items) =>
    items.fold(Macros.empty, (total, item) => total + item);
