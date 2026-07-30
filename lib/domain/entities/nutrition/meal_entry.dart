import '../../../core/util/iso_day.dart';
import 'food_definition.dart';
import 'macros.dart';

/// How this entry's macros were arrived at — surfaced honestly in the UI.
enum MealSource {
  /// A photo was attached and the user confirmed the contents from candidates.
  photo('photo'),

  /// Picked from the food table.
  database('database'),

  /// Free-text with hand-entered macros.
  manual('manual'),

  /// Logged from a dining recommendation.
  restaurant('restaurant'),

  /// Pre-seeded demo data.
  seed('seed');

  const MealSource(this.wireName);

  final String wireName;

  String get label => switch (this) {
    MealSource.photo => 'Photo, confirmed by you',
    MealSource.database => 'From the food table',
    MealSource.manual => 'Entered by hand',
    MealSource.restaurant => 'Logged from a recommendation',
    MealSource.seed => 'Sample data',
  };

  static MealSource? fromWireName(String value) {
    for (final source in MealSource.values) {
      if (source.wireName == value) return source;
    }
    return null;
  }
}

class LoggedFood {
  const LoggedFood({
    required this.name,
    required this.macros,
    this.foodId,
    this.portions = 1,
    this.tags = const [],
  });

  /// Null for a free-text entry with no database match.
  final String? foodId;

  final String name;

  /// Multiplier against the definition's portion. 2 = "two rotis".
  final double portions;

  final Macros macros;
  final List<FoodTag> tags;

  /// Builds a logged food from a database row, scaling its macros once.
  factory LoggedFood.fromDefinition(
    FoodDefinition definition, {
    double portions = 1,
  }) {
    return LoggedFood(
      foodId: definition.id,
      name: definition.name,
      portions: portions,
      macros: portions == 1
          ? definition.macros
          : definition.macros.scaled(portions),
      tags: definition.tags,
    );
  }

  String get portionLabel =>
      portions == 1 ? name : '$name × ${_trim(portions)}';

  static String _trim(double value) =>
      value == value.roundToDouble() ? '${value.round()}' : '$value';

  factory LoggedFood.fromJson(Map<String, dynamic> json) => LoggedFood(
    foodId: json['foodId'] as String?,
    name: json['name'] as String,
    portions: (json['portions'] as num?)?.toDouble() ?? 1,
    macros: Macros.fromJson(Map<String, dynamic>.from(json['macros'] as Map)),
    tags:
        (json['tags'] as List?)
            ?.map((t) => FoodTag.fromWireName(t as String))
            .whereType<FoodTag>()
            .toList() ??
        const [],
  );

  Map<String, dynamic> toJson() => {
    'foodId': foodId,
    'name': name,
    'portions': portions,
    'macros': macros.toJson(),
    'tags': tags.map((t) => t.wireName).toList(),
  };
}

class MealEntry {
  const MealEntry({
    required this.id,
    required this.day,
    required this.loggedAt,
    required this.slot,
    required this.foods,
    this.source = MealSource.database,
    this.photoPath,
    this.confidence = 1,
    this.note,
  });

  final String id;
  final IsoDay day;
  final DateTime loggedAt;
  final MealSlot slot;
  final MealSource source;

  /// Local file path of the photo, when one was taken. Never uploaded.
  final String? photoPath;

  final List<LoggedFood> foods;

  /// 0–1 confidence in the macro estimate. Photo entries start below 1 and the
  /// UI keeps them editable; a user-confirmed entry is 1.
  final double confidence;

  final String? note;

  Macros get macros => sumMacros(foods.map((f) => f.macros));

  String get summary => foods.map((f) => f.portionLabel).join(', ');

  MealEntry copyWith({
    List<LoggedFood>? foods,
    MealSlot? slot,
    MealSource? source,
    String? photoPath,
    double? confidence,
    String? note,
  }) => MealEntry(
    id: id,
    day: day,
    loggedAt: loggedAt,
    slot: slot ?? this.slot,
    source: source ?? this.source,
    foods: foods ?? this.foods,
    photoPath: photoPath ?? this.photoPath,
    confidence: confidence ?? this.confidence,
    note: note ?? this.note,
  );

  factory MealEntry.fromJson(Map<String, dynamic> json) => MealEntry(
    id: json['id'] as String,
    day: json['day'] as String,
    loggedAt: DateTime.parse(json['loggedAt'] as String).toLocal(),
    slot: MealSlot.fromWireName(json['slot'] as String) ?? MealSlot.snack,
    source:
        MealSource.fromWireName(json['source'] as String) ?? MealSource.manual,
    foods: (json['foods'] as List)
        .map((f) => LoggedFood.fromJson(Map<String, dynamic>.from(f as Map)))
        .toList(),
    photoPath: json['photoPath'] as String?,
    confidence: (json['confidence'] as num?)?.toDouble() ?? 1,
    note: json['note'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'day': day,
    'loggedAt': loggedAt.toIso8601String(),
    'slot': slot.wireName,
    'source': source.wireName,
    'foods': foods.map((f) => f.toJson()).toList(),
    'photoPath': photoPath,
    'confidence': confidence,
    'note': note,
  };
}
