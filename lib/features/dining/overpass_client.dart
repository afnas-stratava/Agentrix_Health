import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/config/app_info.dart';
import '../../domain/entities/dining/restaurant.dart';
import '../../domain/entities/profile/cuisine.dart';
import 'geo.dart';

/// OpenStreetMap's Overpass API — nearby restaurants and fast-food places.
///
/// No API key, no billing account, no signup: Overpass is free community map
/// data, queried directly from the device the same way [PlacesClient] used to
/// query Google. The trade-off is data shape, not reliability — OSM carries no
/// star rating and no price level, so [Restaurant.rating]/[Restaurant.priceLevel]
/// are always null for a live result here, and the ranker already treats a
/// null rating as "no signal" rather than a penalty (see `rank.dart`).
///
/// Overpass's public instance silently rejects requests with no identifying
/// User-Agent — no error body, just an empty or malformed response — which is
/// why [_userAgent] is mandatory on every call, not a nicety.
class OverpassClient {
  const OverpassClient({http.Client? httpClient}) : _httpClient = httpClient;

  final http.Client? _httpClient;

  /// The shared FOSSGIS instance (`overpass-api.de`) has no SLA and queues or
  /// hard-504s under load — confirmed live, repeatedly, over a dense area
  /// (Times Square, 2.5 km): "the server is probably too busy to handle your
  /// request." A result cap alone does not fix it, because Overpass still has
  /// to scan and filter the whole radius before the cap ever applies — the
  /// area itself is the expensive part, not the reply size.
  ///
  /// Two independently-hosted mirrors — not aliases of each other or of the
  /// primary — cover for that. All three are queried *concurrently* rather
  /// than one after another: a hung primary should not add its own timeout on
  /// top of whatever the next one takes too, and the first to answer wins.
  /// All three are the same free, keyless Overpass API, just different
  /// volunteer-run servers — current list per the OSM wiki's public-instance
  /// table.
  static final List<Uri> _endpoints = [
    Uri.parse('https://overpass-api.de/api/interpreter'),
    Uri.parse('https://overpass.private.coffee/api/interpreter'),
    Uri.parse('https://maps.mail.ru/osm/tools/overpass/api/interpreter'),
  ];

  static const String _userAgent =
      '${AppInfo.appName}/1.0 (+${AppInfo.supportEmail})';

  /// Per-mirror ceiling. Kept short relative to the whole-search budget
  /// because a slow mirror should be abandoned in favour of the next one,
  /// not sat on until the user gives up.
  static const Duration _timeout = Duration(seconds: 10);

  /// Returns null — not an empty list — when every mirror failed, so the
  /// caller can distinguish "nothing nearby" from "we could not look" and say
  /// so rather than inventing a result.
  Future<List<Restaurant>?> searchNearby({
    required double latitude,
    required double longitude,
    double radiusMetres = 2500,
  }) async {
    // Capped so a busy instance at least has less to build before replying —
    // it is not what makes the difference on its own (see [_endpoints]), but
    // there is no reason to ask for more than the ranker ever uses.
    final query =
        '''
[out:json][timeout:15];
(
  node["amenity"~"^(restaurant|fast_food)\$"](around:$radiusMetres,$latitude,$longitude);
  way["amenity"~"^(restaurant|fast_food)\$"](around:$radiusMetres,$latitude,$longitude);
);
out center tags 60;
''';

    // Race every mirror rather than trying them in turn: whichever answers
    // first — with a real result — wins, and the rest are left to finish or
    // fail on their own. Only when *all* of them come back empty-handed does
    // the whole search count as failed.
    final results = <List<Restaurant>?>[];
    final completer = Completer<List<Restaurant>?>();

    for (final endpoint in _endpoints) {
      unawaited(
        _tryEndpoint(
          endpoint,
          query,
          fromLatitude: latitude,
          fromLongitude: longitude,
        ).then((restaurants) {
          if (completer.isCompleted) return;
          if (restaurants != null) {
            completer.complete(restaurants);
            return;
          }
          results.add(null);
          if (results.length == _endpoints.length) completer.complete(null);
        }),
      );
    }

    return completer.future;
  }

  Future<List<Restaurant>?> _tryEndpoint(
    Uri endpoint,
    String query, {
    required double fromLatitude,
    required double fromLongitude,
  }) async {
    final client = _httpClient ?? http.Client();
    try {
      final response = await client
          .post(
            endpoint,
            headers: const {'User-Agent': _userAgent},
            body: {'data': query},
          )
          .timeout(_timeout);

      if (response.statusCode != 200) {
        debugPrint('Overpass search failed at $endpoint (${response.statusCode}).');
        return null;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;
      final elements = decoded['elements'];
      if (elements is! List) return const [];

      return elements
          .whereType<Map<String, dynamic>>()
          .map(
            (element) => toRestaurantFromOverpassElement(
              element,
              fromLatitude: fromLatitude,
              fromLongitude: fromLongitude,
            ),
          )
          .whereType<Restaurant>()
          .toList()
        ..sort(
          (a, b) => (a.distanceMetres ?? double.infinity).compareTo(
            b.distanceMetres ?? double.infinity,
          ),
        );
    } catch (error) {
      debugPrint('Overpass search error at $endpoint: $error');
      return null;
    } finally {
      if (_httpClient == null) client.close();
    }
  }
}

/// OSM `cuisine` tag values mapped onto our cuisine vocabulary. The tag is
/// free text and often a semicolon-separated list — see
/// https://wiki.openstreetmap.org/wiki/Key:cuisine — so this is deliberately
/// forgiving rather than exhaustive; anything not listed leaves the
/// restaurant's cuisine null, same as an unrecognised Places type did.
const List<(String, Cuisine)> _cuisineTagMap = [
  ('south_indian', Cuisine.southIndian),
  ('north_indian', Cuisine.northIndian),
  ('indian', Cuisine.northIndian),
  ('mediterranean', Cuisine.mediterranean),
  ('greek', Cuisine.mediterranean),
  ('middle_eastern', Cuisine.middleEastern),
  ('lebanese', Cuisine.middleEastern),
  ('turkish', Cuisine.middleEastern),
  ('kebab', Cuisine.middleEastern),
  ('japanese', Cuisine.japanese),
  ('sushi', Cuisine.japanese),
  ('ramen', Cuisine.japanese),
  ('thai', Cuisine.thai),
  ('vietnamese', Cuisine.eastAsian),
  ('chinese', Cuisine.chinese),
  ('korean', Cuisine.korean),
  ('asian', Cuisine.eastAsian),
  ('mexican', Cuisine.mexican),
  ('tex-mex', Cuisine.mexican),
  ('burger', Cuisine.american),
  ('american', Cuisine.american),
  ('steak_house', Cuisine.american),
  ('steak', Cuisine.american),
  ('bbq', Cuisine.american),
  ('barbecue', Cuisine.american),
  ('pizza', Cuisine.continental),
  ('italian', Cuisine.continental),
];

@visibleForTesting
Cuisine? inferCuisineFromTags(List<String> cuisineTokens) {
  for (final token in cuisineTokens) {
    for (final (tag, cuisine) in _cuisineTagMap) {
      if (token == tag) return cuisine;
    }
  }
  return null;
}

@visibleForTesting
String? formatOsmAddress(Map<String, dynamic> tags) {
  final houseNumber = tags['addr:housenumber'] as String?;
  final street = tags['addr:street'] as String?;
  final city = tags['addr:city'] as String?;

  final line = houseNumber != null && street != null
      ? '$houseNumber $street'
      : street;

  final parts = [
    line,
    city,
  ].whereType<String>().where((s) => s.isNotEmpty).toList();
  return parts.isEmpty ? null : parts.join(', ');
}

@visibleForTesting
Restaurant? toRestaurantFromOverpassElement(
  Map<String, dynamic> element, {
  required double fromLatitude,
  required double fromLongitude,
}) {
  final tags = (element['tags'] as Map?)?.cast<String, dynamic>() ?? const {};
  final name = (tags['name'] as String?)?.trim();
  if (name == null || name.isEmpty) return null;

  final type = element['type'];
  final osmId = element['id'];
  if (type is! String || osmId == null) return null;

  var lat = (element['lat'] as num?)?.toDouble();
  var lon = (element['lon'] as num?)?.toDouble();
  if (lat == null || lon == null) {
    final center = element['center'] as Map?;
    lat = (center?['lat'] as num?)?.toDouble();
    lon = (center?['lon'] as num?)?.toDouble();
  }
  if (lat == null || lon == null) return null;

  final cuisineTag = tags['cuisine'] as String?;
  final cuisineTokens =
      cuisineTag
          ?.split(';')
          .map((token) => token.trim().toLowerCase())
          .where((token) => token.isNotEmpty)
          .toList() ??
      const [];

  return Restaurant(
    id: '$type/$osmId',
    name: name,
    source: RestaurantSource.live,
    cuisine: inferCuisineFromTags(cuisineTokens),
    providerTypes: cuisineTokens,
    distanceMetres: haversineMetres(fromLatitude, fromLongitude, lat, lon),
    latitude: lat,
    longitude: lon,
    address: formatOsmAddress(tags),
  );
}
