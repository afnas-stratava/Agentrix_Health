import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../domain/entities/dining/restaurant.dart';
import '../../features/dining/fixtures.dart';
import '../../features/dining/places.dart';
import '../../features/dining/rank.dart';
import 'nutrition_providers.dart';
import 'user_profile_provider.dart';

final placesClientProvider = Provider<PlacesClient>(
  (ref) => const PlacesClient(apiKey: PlacesClient.apiKeyFromEnvironment),
);

/// Where the nearby list came from, so the UI can disclose a fallback.
enum NearbyOrigin {
  /// Live Places results, ranked against a real location.
  live,

  /// Curated archetypes — no key, no permission, no network, or no results.
  fixture,
}

class NearbyResult {
  const NearbyResult({required this.restaurants, required this.origin});

  final List<Restaurant> restaurants;
  final NearbyOrigin origin;

  bool get isFallback => origin == NearbyOrigin.fixture;
}

/// Nearby restaurants.
///
/// Degrades in one direction only, and never to an error: no key → fixtures;
/// permission refused → fixtures; request failed or timed out → fixtures; zero
/// results → fixtures. The UI states which it is showing.
final nearbyRestaurantsProvider = FutureProvider<NearbyResult>((ref) async {
  const fallback = NearbyResult(
    restaurants: fixtureRestaurants,
    origin: NearbyOrigin.fixture,
  );

  final client = ref.watch(placesClientProvider);
  if (!client.isConfigured) return fallback;

  final position = await _currentPosition();
  if (position == null) return fallback;

  final live = await client.searchNearby(
    latitude: position.latitude,
    longitude: position.longitude,
  );

  if (live == null || live.isEmpty) return fallback;
  return NearbyResult(restaurants: live, origin: NearbyOrigin.live);
});

Future<Position?> _currentPosition() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return null;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 8),
      ),
    );
  } catch (error) {
    // A location fix is a nice-to-have here, never a blocker.
    debugPrint('Location unavailable: $error');
    return null;
  }
}

final diningModeProvider = NotifierProvider<DiningModeNotifier, DiningMode>(
  DiningModeNotifier.new,
);

class DiningModeNotifier extends Notifier<DiningMode> {
  @override
  DiningMode build() =>
      ref.watch(cheatDayProvider) ? DiningMode.cheat : DiningMode.aligned;

  void select(DiningMode mode) => state = mode;
}

/// Ranked dish-level recommendations.
///
/// Everything that shapes this — remaining macros, the day's focus tags, diet
/// pattern, allergens, cuisine order — comes from the same providers the brief
/// and the food log read, so a recommendation can never contradict the plan.
final diningPicksProvider = Provider<List<RestaurantPick>>((ref) {
  final nearby = ref.watch(nearbyRestaurantsProvider).valueOrNull;
  if (nearby == null) return const [];

  return rankRestaurants(
    restaurants: nearby.restaurants,
    profile: ref.watch(userProfileProvider),
    targets: ref.watch(nutritionTargetsProvider),
    consumed: ref.watch(consumedTodayProvider),
    mode: ref.watch(diningModeProvider),
    focusTags: ref.watch(focusTagsProvider),
  );
});

/// The one-line "order this, here" the Home screen shows.
final diningHeadlineProvider = Provider<String?>(
  (ref) => headlineDiningPick(ref.watch(diningPicksProvider)),
);
