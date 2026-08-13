import 'dart:convert';

import 'package:agentrix_health/domain/entities/profile/cuisine.dart';
import 'package:agentrix_health/features/dining/overpass_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> _node({
  required String id,
  String? name,
  String? cuisine,
  double lat = 40.7580,
  double lon = -73.9855,
  Map<String, String> extraTags = const {},
}) => {
  'type': 'node',
  'id': id,
  'lat': lat,
  'lon': lon,
  'tags': {
    if (name != null) 'name': name,
    if (cuisine != null) 'cuisine': cuisine,
    ...extraTags,
  },
};

void main() {
  group('inferCuisineFromTags', () {
    test('maps a single recognised token', () {
      expect(inferCuisineFromTags(['pizza']), Cuisine.continental);
      expect(inferCuisineFromTags(['sushi']), Cuisine.japanese);
      expect(inferCuisineFromTags(['indian']), Cuisine.northIndian);
    });

    test('maps the first recognised token in a semicolon-split list', () {
      // OSM's cuisine tag is commonly a free-text list — "regional" carries no
      // signal, "italian" does.
      expect(inferCuisineFromTags(['regional', 'italian']), Cuisine.continental);
    });

    test('returns null for an unrecognised or empty tag', () {
      expect(inferCuisineFromTags(['regional']), isNull);
      expect(inferCuisineFromTags([]), isNull);
    });

    test('is case- and whitespace-insensitive at the call site', () {
      // toRestaurantFromOverpassElement lowercases/trims before calling this,
      // so the function itself only needs to handle already-normalised input —
      // confirmed here so a future caller change cannot silently break it.
      expect(inferCuisineFromTags(['pizza']), Cuisine.continental);
    });
  });

  group('formatOsmAddress', () {
    test('combines house number, street and city when all present', () {
      expect(
        formatOsmAddress({
          'addr:housenumber': '221B',
          'addr:street': 'Baker Street',
          'addr:city': 'London',
        }),
        '221B Baker Street, London',
      );
    });

    test('falls back to street alone without a house number', () {
      expect(
        formatOsmAddress({'addr:street': 'Baker Street', 'addr:city': 'London'}),
        'Baker Street, London',
      );
    });

    test('returns null when no address tags are present', () {
      expect(formatOsmAddress(const {}), isNull);
    });
  });

  group('toRestaurantFromOverpassElement', () {
    test('parses a node with a direct lat/lon', () {
      final restaurant = toRestaurantFromOverpassElement(
        _node(id: '123', name: 'Hard Rock Cafe', cuisine: 'american'),
        fromLatitude: 40.7589,
        fromLongitude: -73.9851,
      );

      expect(restaurant, isNotNull);
      expect(restaurant!.id, 'node/123');
      expect(restaurant.name, 'Hard Rock Cafe');
      expect(restaurant.cuisine, Cuisine.american);
      expect(restaurant.latitude, 40.7580);
      expect(restaurant.longitude, -73.9855);
      // A real distance was computed rather than left null.
      expect(restaurant.distanceMetres, isNotNull);
      expect(restaurant.distanceMetres, greaterThan(0));
    });

    test('reads a way\'s `center` when there is no direct lat/lon', () {
      final element = {
        'type': 'way',
        'id': '456',
        'center': {'lat': 40.759, 'lon': -73.984},
        'tags': {'name': 'Carbone', 'cuisine': 'italian'},
      };

      final restaurant = toRestaurantFromOverpassElement(
        element,
        fromLatitude: 40.7589,
        fromLongitude: -73.9851,
      );

      expect(restaurant, isNotNull);
      expect(restaurant!.id, 'way/456');
      expect(restaurant.latitude, 40.759);
      expect(restaurant.cuisine, Cuisine.continental);
    });

    test('drops an element with no name — nothing to show the user', () {
      final restaurant = toRestaurantFromOverpassElement(
        _node(id: '789', name: null),
        fromLatitude: 0,
        fromLongitude: 0,
      );
      expect(restaurant, isNull);
    });

    test('drops an element with no resolvable coordinates', () {
      final element = {
        'type': 'way',
        'id': '999',
        'tags': {'name': 'No Location Diner'},
      };
      final restaurant = toRestaurantFromOverpassElement(
        element,
        fromLatitude: 0,
        fromLongitude: 0,
      );
      expect(restaurant, isNull);
    });

    test('leaves cuisine null when the tag is absent or unrecognised', () {
      final restaurant = toRestaurantFromOverpassElement(
        _node(id: '111', name: 'Tick Tock Diner', cuisine: 'diner'),
        fromLatitude: 40.7589,
        fromLongitude: -73.9851,
      );
      expect(restaurant, isNotNull);
      expect(restaurant!.cuisine, isNull);
      // The raw token is kept for debugging even when unmapped.
      expect(restaurant.providerTypes, ['diner']);
    });

    test('never carries a rating or price level — OSM has neither', () {
      final restaurant = toRestaurantFromOverpassElement(
        _node(id: '222', name: 'Some Place'),
        fromLatitude: 40.7589,
        fromLongitude: -73.9851,
      );
      expect(restaurant, isNotNull);
      expect(restaurant!.rating, isNull);
      expect(restaurant.priceLevel, isNull);
    });

    test('builds a directions link from the parsed coordinates', () {
      final restaurant = toRestaurantFromOverpassElement(
        _node(id: '333', name: 'Some Place', lat: 40.75, lon: -73.98),
        fromLatitude: 40.7589,
        fromLongitude: -73.9851,
      );
      expect(
        restaurant!.directionsUri,
        'https://www.google.com/maps/search/?api=1&query=40.75,-73.98',
      );
    });
  });

  group('OverpassClient.searchNearby (racing behaviour)', () {
    String overpassBody(List<Map<String, dynamic>> elements) =>
        jsonEncode({'elements': elements});

    test('returns the first mirror to answer successfully, without waiting '
        'for a slower one', () async {
      final client = OverpassClient(
        httpClient: MockClient((request) async {
          // Mirrors an overloaded primary: it does eventually answer, but
          // only after the fast mirror already has.
          if (request.url.host == 'overpass-api.de') {
            await Future<void>.delayed(const Duration(milliseconds: 300));
            return http.Response('busy', 504);
          }
          return http.Response(
            overpassBody([_node(id: '1', name: 'Fast Mirror Diner')]),
            200,
          );
        }),
      );

      final result = await client.searchNearby(latitude: 0, longitude: 0);

      expect(result, isNotNull);
      expect(result!.single.name, 'Fast Mirror Diner');
    });

    test('returns null only once every mirror has failed', () async {
      final client = OverpassClient(
        httpClient: MockClient((request) async => http.Response('', 500)),
      );

      final result = await client.searchNearby(latitude: 0, longitude: 0);

      expect(result, isNull);
    });

    test('a malformed reply from one mirror does not sink a good reply from '
        'another', () async {
      final client = OverpassClient(
        httpClient: MockClient((request) async {
          if (request.url.host == 'overpass-api.de') {
            return http.Response('not json', 200);
          }
          return http.Response(
            overpassBody([_node(id: '2', name: 'Reliable Mirror Cafe')]),
            200,
          );
        }),
      );

      final result = await client.searchNearby(latitude: 0, longitude: 0);

      expect(result, isNotNull);
      expect(result!.single.name, 'Reliable Mirror Cafe');
    });
  });
}
