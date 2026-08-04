import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:google_generative_ai/google_generative_ai.dart';

import '../../domain/entities/nutrition/food_definition.dart';
import '../../features/nutrition/food_database.dart';
import '../../features/nutrition/suggest_plate.dart';

/// Reads a meal photo with Gemini and returns the dishes on the plate.
///
/// This is the vision call [suggestPlate] describes but does not make. The
/// photo goes in as [DataPart] and food-table ids come back, so the macros
/// attached to a recognised dish are the same audited numbers the search path
/// uses — the model chooses *which* row, never what is in it.
///
/// That constraint is enforced by the schema rather than the prompt:
/// `foodId` is an [Schema.enumString] over [foodDatabase] ids, so a hallucinated
/// dish is not a value the model is able to emit. Anything it sees that has no
/// row lands in [MealVisionResult.unmatched] as free text and is shown to the
/// user to search for by hand, because silently dropping half a plate is how a
/// food log quietly under-counts.
///
/// Throws on transport failure — no key, no network, a safety filter, malformed
/// JSON. Returns an *empty* result when the call succeeded and there was simply
/// no food in the frame. Callers must keep those apart: the first is "we could
/// not look", the second is "we looked and there was nothing", and telling the
/// user the wrong one is the trap [FallbackLabParser] fell into.
class GeminiMealVision {
  const GeminiMealVision({
    required this.apiKey,
    this.model = 'gemini-flash-latest',
  });

  final String apiKey;

  /// Matches [GeminiChatService] and [GeminiLabParser]: `gemini-flash-latest`
  /// is the alias Google points at whichever flash model this project has
  /// quota for.
  final String model;

  bool get isConfigured => apiKey.trim().isNotEmpty;

  /// Inline payloads only — this path does not use the Files API. Meal photos
  /// arrive downscaled to 1600px at quality 80, roughly 300KB, so this ceiling
  /// exists to reject something pathological rather than to catch normal use.
  static const int maxInlineBytes = 15 * 1024 * 1024;

  Future<MealVisionResult> identify({
    required String photoPath,
    required MealSlot slot,
  }) async {
    final file = File(photoPath);
    if (!await file.exists()) {
      throw StateError('Meal photo no longer exists at $photoPath');
    }

    final bytes = await file.readAsBytes();
    if (bytes.lengthInBytes > maxInlineBytes) {
      throw StateError(
        'Photo is ${(bytes.lengthInBytes / 1024 / 1024).toStringAsFixed(1)}MB, '
        'above the ${maxInlineBytes ~/ (1024 * 1024)}MB inline limit',
      );
    }

    final generativeModel = GenerativeModel(
      model: model,
      apiKey: apiKey,
      systemInstruction: Content.system(_systemPrompt),
      generationConfig: GenerationConfig(
        // Observation, not composition — the same photo should give the same
        // plate on every run.
        temperature: 0,
        responseMimeType: 'application/json',
        responseSchema: _responseSchema(),
      ),
    );

    final response = await generativeModel.generateContent([
      Content.multi([
        DataPart(_mimeTypeFor(photoPath), bytes),
        TextPart(_instructionFor(slot)),
      ]),
    ]);

    final text = response.text?.trim();
    if (text == null || text.isEmpty) {
      throw StateError('Gemini returned no text for the meal photo');
    }

    final decoded = jsonDecode(text);
    if (decoded is! Map<String, dynamic>) {
      throw StateError(
        'Gemini returned ${decoded.runtimeType}, expected an object',
      );
    }

    return resultFromJson(decoded);
  }

  /// Maps Gemini's reply onto [PlateSuggestion]s.
  ///
  /// Split out and left public so portion clamping, de-duplication and unknown
  /// ids are testable without a network call — which is where the failure modes
  /// that actually matter live.
  @visibleForTesting
  static MealVisionResult resultFromJson(Map<String, dynamic> json) {
    final rows = (json['matched'] as List?) ?? const [];

    // A dish can legitimately appear twice in one photo — two rotis on the same
    // plate. Summing portions keeps that as one adjustable row rather than two
    // identical ones the user has to reason about.
    final byId = <String, ({FoodDefinition food, double portions, double confidence, String seenAs})>{};

    for (final row in rows) {
      if (row is! Map) continue;
      final map = Map<String, dynamic>.from(row);

      final food = findFood((map['foodId'] as String?)?.trim() ?? '');
      // Unreachable through the enum schema, but a model that ignores the
      // schema must not be able to inject a dish with no macros behind it.
      if (food == null) continue;

      final portions = _cleanPortions((map['portions'] as num?)?.toDouble());
      final confidence = ((map['confidence'] as num?)?.toDouble() ?? 0.7)
          .clamp(0.0, _confidenceCeiling)
          .toDouble();
      final seenAs = (map['seenAs'] as String?)?.trim();

      final existing = byId[food.id];
      byId[food.id] = existing == null
          ? (
              food: food,
              portions: portions,
              confidence: confidence,
              seenAs: seenAs?.isNotEmpty == true ? seenAs! : food.name,
            )
          : (
              food: food,
              portions: _cleanPortions(existing.portions + portions),
              // The less certain sighting governs the pair: if one of the two
              // was a guess, the merged row is no better than a guess.
              confidence: existing.confidence < confidence
                  ? existing.confidence
                  : confidence,
              seenAs: existing.seenAs,
            );
    }

    final unmatched = <String>[];
    for (final item in (json['unmatched'] as List?) ?? const []) {
      final name = (item as Object?).toString().trim();
      if (name.isNotEmpty) unmatched.add(name);
    }

    return MealVisionResult(
      suggestions: [
        for (final entry in byId.values)
          PlateSuggestion(
            food: entry.food,
            confidence: entry.confidence,
            portions: entry.portions,
            reason: entry.seenAs.toLowerCase() == entry.food.name.toLowerCase()
                ? 'seen in your photo'
                : 'seen as “${entry.seenAs}”',
          ),
      ],
      unmatched: unmatched,
    );
  }

  /// Held below 1 for the same reason the ranked path is: the entry only
  /// reaches full confidence when the user confirms it on the screen.
  static const double _confidenceCeiling = 0.95;

  /// Snapped to the half-portion steps the log screen's +/- buttons use, so an
  /// estimate the user adjusts once lands on a value they can reach again.
  static double _cleanPortions(double? raw) {
    final value = raw == null || raw.isNaN || raw <= 0 ? 1.0 : raw;
    final snapped = (value * 2).round() / 2;
    return snapped.clamp(0.5, 6.0).toDouble();
  }

  static String _mimeTypeFor(String path) {
    final name = path.toLowerCase();
    if (name.endsWith('.png')) return 'image/png';
    if (name.endsWith('.webp')) return 'image/webp';
    if (name.endsWith('.heic')) return 'image/heic';
    if (name.endsWith('.heif')) return 'image/heif';
    return 'image/jpeg';
  }
}

/// What the model saw.
class MealVisionResult {
  const MealVisionResult({
    required this.suggestions,
    this.unmatched = const [],
  });

  /// Dishes matched to a food-table row, ready to confirm.
  final List<PlateSuggestion> suggestions;

  /// Foods visible in the photo that the food table has no row for. Surfaced
  /// rather than dropped so the user can search for something close.
  final List<String> unmatched;

  /// True when the call succeeded and there was no food in the frame. Distinct
  /// from a thrown failure, and the two must read differently to the user.
  bool get foundNothing => suggestions.isEmpty && unmatched.isEmpty;
}

/// Rendered verbatim above a photo-derived list, the counterpart to
/// [suggestionBasis]. Says both what produced the list and what about it is
/// least trustworthy — a model can see that there is rice on the plate far more
/// reliably than it can see how much.
const String photoReadBasis =
    'Read from your photo automatically. What is on the plate is usually right; '
    'how much of it is an estimate. Check each row and adjust the portions '
    'before saving.';

/// Shown when the call itself failed. Names the cause, because "we could not
/// look" and "we looked and saw no food" are different facts and the list below
/// is the profile-ranked one either way.
const String photoUnreadableNote =
    'That photo could not be read just now, so the list below is the usual '
    'ranked one rather than anything from your picture.';

/// Shown when the model read the photo and found no food in it.
const String photoNoFoodNote =
    'Nothing recognisable as food turned up in that photo. It is still attached '
    'to this entry — add what you ate by searching below.';

const String _systemPrompt = '''
You identify food in photographs of meals. You are a careful observer, not a
nutritionist and not a critic.

Absolute rules:
- Report ONLY food you can actually see in the frame. Never add a dish because
  it commonly accompanies one that is present.
- If the photo contains no food at all, return empty arrays. An empty result is
  correct and expected; an invented plate is a serious error.
- You must choose foodId from the provided catalogue. If something is visible
  but nothing in the catalogue is a fair match, put a short plain-English name
  in `unmatched` instead of forcing a wrong row. A rough match is worse than an
  honest gap, because the wrong row carries the wrong macros.
- Estimate `portions` as a multiple of the portion size stated for that
  catalogue entry, judged against the plate, cutlery or hands in the frame. One
  portion is the default when you cannot tell.
- Do not comment on whether the meal is healthy, and do not describe the person
  who is eating it.
''';

/// The catalogue is built from [foodDatabase] rather than written out, so a food
/// added to the table is immediately something the model can return.
String _catalogue() => [
  for (final food in foodDatabase)
    '${food.id} | ${food.name} | one portion = ${food.portionLabel}',
].join('\n');

String _instructionFor(MealSlot slot) =>
    '''
Identify every food and drink visible in this photograph.

This was logged as ${slot.label.toLowerCase()}, which may help you read an
ambiguous item — but trust the picture over the meal time.

For each item you recognise, return the catalogue `foodId`, the `seenAs` label
describing what you actually saw in your own words, an estimated `portions`
multiplier, and a `confidence` from 0.0 to 1.0 reflecting how sure you are of
the identification.

Put anything visible that the catalogue cannot represent into `unmatched` as a
short name.

Catalogue — id | name | portion:
${_catalogue()}
''';

/// Built per call rather than held as a const because the id list comes from
/// [foodDatabase], which the schema has to mirror exactly.
Schema _responseSchema() => Schema.object(
  properties: {
    'matched': Schema.array(
      description: 'Foods visible in the photo that match a catalogue row',
      items: Schema.object(
        properties: {
          'foodId': Schema.enumString(
            enumValues: [for (final food in foodDatabase) food.id],
            description: 'Catalogue id of the matching food',
          ),
          'seenAs': Schema.string(
            description: 'What you saw, in your own words',
          ),
          'portions': Schema.number(
            description: 'Multiples of the catalogue portion size',
          ),
          'confidence': Schema.number(description: '0.0 to 1.0'),
        },
        requiredProperties: ['foodId', 'seenAs', 'portions', 'confidence'],
      ),
    ),
    'unmatched': Schema.array(
      description: 'Visible foods with no fair match in the catalogue',
      items: Schema.string(),
    ),
  },
  requiredProperties: ['matched'],
);
