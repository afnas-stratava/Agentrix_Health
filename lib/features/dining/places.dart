import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../domain/entities/dining/restaurant.dart';
import '../../domain/entities/profile/cuisine.dart';
import 'fixtures.dart';

/// Google Places API (New) — Nearby Search.
/// Ported from `src/features/dining/places.ts`.
///
/// Called directly from the device because this build has no backend. The key is
/// therefore in the bundle and MUST be restricted, in the Google Cloud console,
/// to this bundle identifier and to the Places API alone; an unrestricted key in
/// a shipped app is a billing incident waiting to happen.
///
/// Every failure path here is non-fatal: the caller falls back to the curated
/// [fixtureRestaurants], so a dead network, an exhausted quota or a missing key
/// degrades the feature to "plausible nearby restaurants" rather than an error
/// screen. On conference wifi that is the difference between a demo and no demo.
class PlacesClient {
  const PlacesClient({this.apiKey, http.Client? httpClient})
    : _httpClient = httpClient;

  /// Supply via `--dart-define=PLACES_API_KEY=…`; empty disables live search.
  static const String apiKeyFromEnvironment = String.fromEnvironment(
    'PLACES_API_KEY',
  );

  final String? apiKey;
  final http.Client? _httpClient;

  bool get isConfigured => (apiKey ?? '').isNotEmpty;

  static final Uri _endpoint = Uri.parse(
    'https://places.googleapis.com/v1/places:searchNearby',
  );

  /// The field mask is mandatory on the new API and is what you are billed on —
  /// asking for photos or opening hours here would move this into a pricier SKU
  /// for no benefit, since the UI shows neither.
  static const String _fieldMask =
      'places.id,'
      'places.displayName,'
      'places.primaryType,'
      'places.types,'
      'places.rating,'
      'places.userRatingCount,'
      'places.priceLevel,'
      'places.location,'
      'places.shortFormattedAddress,'
      'places.googleMapsUri';

  static const Duration _timeout = Duration(seconds: 8);

  /// Returns null — not an empty list — when live search could not be performed,
  /// so the caller can distinguish "nothing nearby" from "we could not look".
  Future<List<Restaurant>?> searchNearby({
    required double latitude,
    required double longitude,
    double radiusMetres = 2500,
    int maxResults = 20,
  }) async {
    if (!isConfigured) return null;

    final client = _httpClient ?? http.Client();
    try {
      final response = await client
          .post(
            _endpoint,
            headers: {
              'Content-Type': 'application/json',
              'X-Goog-Api-Key': apiKey!,
              'X-Goog-FieldMask': _fieldMask,
            },
            body: jsonEncode({
              'includedTypes': ['restaurant'],
              'maxResultCount': maxResults,
              'locationRestriction': {
                'circle': {
                  'center': {'latitude': latitude, 'longitude': longitude},
                  'radius': radiusMetres,
                },
              },
            }),
          )
          .timeout(_timeout);

      if (response.statusCode != 200) {
        debugPrint(
          'Places search failed (${response.statusCode}); using fixtures.',
        );
        return null;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;
      final places = decoded['places'];
      if (places is! List) return const [];

      return places
          .whereType<Map<String, dynamic>>()
          .map(
            (place) => _toRestaurant(
              place,
              fromLatitude: latitude,
              fromLongitude: longitude,
            ),
          )
          .whereType<Restaurant>()
          .toList();
    } catch (error) {
      // Non-fatal by design — the caller falls back to fixtures.
      debugPrint('Places search error: $error');
      return null;
    } finally {
      if (_httpClient == null) client.close();
    }
  }
}

/// Provider type strings mapped onto our cuisine vocabulary.
///
/// Ordered most specific first — `south_indian_restaurant` must win over
/// `indian_restaurant`, which must win over the bare `restaurant`.
const List<(String, Cuisine)> _typeToCuisine = [
  ('south_indian_restaurant', Cuisine.southIndian),
  ('north_indian_restaurant', Cuisine.northIndian),
  ('indian_restaurant', Cuisine.northIndian),
  ('mediterranean_restaurant', Cuisine.mediterranean),
  ('greek_restaurant', Cuisine.mediterranean),
  ('middle_eastern_restaurant', Cuisine.middleEastern),
  ('lebanese_restaurant', Cuisine.middleEastern),
  ('turkish_restaurant', Cuisine.middleEastern),
  ('japanese_restaurant', Cuisine.japanese),
  ('sushi_restaurant', Cuisine.japanese),
  ('ramen_restaurant', Cuisine.japanese),
  ('thai_restaurant', Cuisine.thai),
  ('vietnamese_restaurant', Cuisine.eastAsian),
  ('chinese_restaurant', Cuisine.chinese),
  ('korean_restaurant', Cuisine.korean),
  ('asian_restaurant', Cuisine.eastAsian),
  ('mexican_restaurant', Cuisine.mexican),
  ('hamburger_restaurant', Cuisine.american),
  ('american_restaurant', Cuisine.american),
  ('steak_house', Cuisine.american),
  ('pizza_restaurant', Cuisine.continental),
  ('italian_restaurant', Cuisine.continental),
];

Cuisine? _inferCuisine(String? primaryType, List<String> types) {
  for (final (token, cuisine) in _typeToCuisine) {
    if (primaryType == token) return cuisine;
  }
  for (final (token, cuisine) in _typeToCuisine) {
    if (types.contains(token)) return cuisine;
  }
  return null;
}

/// Google returns `PRICE_LEVEL_MODERATE`-style enums on the new API.
int? _parsePriceLevel(Object? raw) {
  if (raw is num) return raw.toInt().clamp(1, 4);
  if (raw is! String) return null;
  return switch (raw) {
    'PRICE_LEVEL_INEXPENSIVE' => 1,
    'PRICE_LEVEL_MODERATE' => 2,
    'PRICE_LEVEL_EXPENSIVE' => 3,
    'PRICE_LEVEL_VERY_EXPENSIVE' => 4,
    _ => null,
  };
}

Restaurant? _toRestaurant(
  Map<String, dynamic> place, {
  required double fromLatitude,
  required double fromLongitude,
}) {
  final id = place['id'];
  final name = (place['displayName'] as Map?)?['text'];
  if (id is! String || name is! String || name.isEmpty) return null;

  final types =
      (place['types'] as List?)?.whereType<String>().toList() ?? const [];
  final location = place['location'] as Map?;
  final latitude = (location?['latitude'] as num?)?.toDouble();
  final longitude = (location?['longitude'] as num?)?.toDouble();

  return Restaurant(
    id: id,
    name: name,
    cuisine: _inferCuisine(place['primaryType'] as String?, types),
    providerTypes: types,
    rating: (place['rating'] as num?)?.toDouble(),
    ratingCount: (place['userRatingCount'] as num?)?.toInt() ?? 0,
    priceLevel: _parsePriceLevel(place['priceLevel']),
    distanceMetres: latitude == null || longitude == null
        ? null
        : haversineMetres(fromLatitude, fromLongitude, latitude, longitude),
    address: place['shortFormattedAddress'] as String?,
    source: RestaurantSource.places,
    mapsUri: place['googleMapsUri'] as String?,
  );
}

/// Great-circle distance in metres.
///
/// Places does not return a distance, and straight-line is the honest thing to
/// show anyway: a walking-route distance implies a routing call we do not make.
double haversineMetres(
  double lat1,
  double lon1,
  double lat2,
  double lon2,
) {
  const earthRadiusMetres = 6371000.0;
  double toRadians(double degrees) => degrees * math.pi / 180;

  final dLat = toRadians(lat2 - lat1);
  final dLon = toRadians(lon2 - lon1);
  final a =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(toRadians(lat1)) *
          math.cos(toRadians(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  return earthRadiusMetres * 2 * math.asin(math.sqrt(a));
}
