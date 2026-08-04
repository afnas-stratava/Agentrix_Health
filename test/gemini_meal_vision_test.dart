import 'package:flutter_test/flutter_test.dart';
import 'package:agentrix_health/data/nutrition/gemini_meal_vision.dart';
import 'package:agentrix_health/features/nutrition/food_database.dart';

/// Covers the mapping between Gemini's reply and the plate the user confirms.
/// The network call is not the risky part — what happens to a bad reply is.
void main() {
  Map<String, dynamic> row(
    String id, {
    double portions = 1,
    double confidence = 0.9,
    String? seenAs,
  }) => {
    'foodId': id,
    'seenAs': seenAs ?? id,
    'portions': portions,
    'confidence': confidence,
  };

  group('resultFromJson', () {
    test('maps a match onto the food table row, not onto model-supplied macros', () {
      final result = GeminiMealVision.resultFromJson({
        'matched': [row('roti', portions: 2, seenAs: 'two chapatis')],
      });

      expect(result.suggestions, hasLength(1));
      final suggestion = result.suggestions.single;
      // The macros must be the audited ones, so that a photo-logged roti and a
      // searched roti can never disagree.
      expect(suggestion.food.id, 'roti');
      expect(suggestion.food.macros.calories, findFood('roti')!.macros.calories);
      expect(suggestion.portions, 2);
      expect(suggestion.reason, contains('two chapatis'));
    });

    test('drops a food id the table does not have', () {
      final result = GeminiMealVision.resultFromJson({
        'matched': [row('dragon-steak'), row('roti')],
      });

      expect(result.suggestions.map((s) => s.food.id), ['roti']);
    });

    test('merges a repeated dish into one adjustable row', () {
      final result = GeminiMealVision.resultFromJson({
        'matched': [
          row('roti', portions: 1, confidence: 0.9),
          row('roti', portions: 2, confidence: 0.4),
        ],
      });

      expect(result.suggestions, hasLength(1));
      expect(result.suggestions.single.portions, 3);
      // The weaker sighting governs the merged row.
      expect(result.suggestions.single.confidence, 0.4);
    });

    test('snaps portions to the half steps the log screen can reach', () {
      final result = GeminiMealVision.resultFromJson({
        'matched': [row('roti', portions: 1.31)],
      });

      expect(result.suggestions.single.portions, 1.5);
    });

    test('clamps absurd or missing portions rather than trusting them', () {
      final result = GeminiMealVision.resultFromJson({
        'matched': [
          row('roti', portions: 400),
          row('plain-rice', portions: -2),
          {'foodId': 'dal-tadka', 'seenAs': 'dal', 'confidence': 0.8},
        ],
      });

      final byId = {
        for (final s in result.suggestions) s.food.id: s.portions,
      };
      expect(byId['roti'], 6);
      // Nonsense and absent both fall back to the "cannot tell" default of one
      // portion rather than to the floor, which would under-count the meal.
      expect(byId['plain-rice'], 1);
      expect(byId['dal-tadka'], 1);
    });

    test('never reports full confidence — the user still has to confirm', () {
      final result = GeminiMealVision.resultFromJson({
        'matched': [row('roti', confidence: 1)],
      });

      expect(result.suggestions.single.confidence, lessThan(1));
    });

    test('keeps foods it could not match instead of dropping them', () {
      final result = GeminiMealVision.resultFromJson({
        'matched': [row('roti')],
        'unmatched': ['mango pickle', '  ', 'papad'],
      });

      expect(result.unmatched, ['mango pickle', 'papad']);
      expect(result.foundNothing, isFalse);
    });

    test('an empty reply is "no food here", which is not a failure', () {
      final result = GeminiMealVision.resultFromJson({
        'matched': <dynamic>[],
        'unmatched': <dynamic>[],
      });

      expect(result.foundNothing, isTrue);
      expect(result.suggestions, isEmpty);
    });

    test('a photo with only unrecognisable food is not "no food here"', () {
      final result = GeminiMealVision.resultFromJson({
        'matched': <dynamic>[],
        'unmatched': ['bisi bele bath'],
      });

      // The distinction matters: the user should be told to search, not told
      // the photo held no food.
      expect(result.foundNothing, isFalse);
    });
  });

  test('every catalogue id resolves — the schema and the table cannot drift', () {
    for (final food in foodDatabase) {
      expect(findFood(food.id), isNotNull, reason: 'unresolvable id ${food.id}');
    }
  });
}
