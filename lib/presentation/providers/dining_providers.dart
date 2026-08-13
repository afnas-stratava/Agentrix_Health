import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../domain/entities/dining/restaurant.dart';
import '../../features/dining/overpass_client.dart';
import '../../features/dining/rank.dart';
import 'nutrition_providers.dart';
import 'user_profile_provider.dart';

final overpassClientProvider = Provider<OverpassClient>(
  (ref) => const OverpassClient(),
);

/// Why a nearby search did not produce a usable list — surfaced to the user
/// verbatim rather than papered over with invented restaurants. Each one maps
/// to a distinct message and, where there is one, a one-tap fix in the UI.
enum NearbyFailureReason {
  locationServicesOff,
  permissionDenied,
  permissionDeniedForever,
  searchFailed,
  noResults,
}

class NearbyResult {
  const NearbyResult.success(this.restaurants) : failure = null;

  const NearbyResult.failure(NearbyFailureReason reason)
    : restaurants = const [],
      failure = reason;

  final List<Restaurant> restaurants;
  final NearbyFailureReason? failure;

  bool get isSuccess => failure == null;
}

class _LocationAttempt {
  const _LocationAttempt.ok(this.position) : failure = null;
  const _LocationAttempt.failed(NearbyFailureReason reason)
    : position = null,
      failure = reason;

  final Position? position;
  final NearbyFailureReason? failure;
}

/// Nearby restaurants, from OpenStreetMap's Overpass API.
///
/// Never invents a result: a disabled location service, a refused permission
/// and a failed search each report distinctly, and the UI is expected to
/// explain whichever one happened rather than silently substituting something
/// else. See `NearbyFailureReason`.
final nearbyRestaurantsProvider = FutureProvider<NearbyResult>((ref) async {
  final location = await _currentPosition();
  if (location.failure != null) {
    return NearbyResult.failure(location.failure!);
  }

  final position = location.position!;
  final restaurants = await ref
      .watch(overpassClientProvider)
      .searchNearby(latitude: position.latitude, longitude: position.longitude);

  if (restaurants == null) {
    return const NearbyResult.failure(NearbyFailureReason.searchFailed);
  }
  if (restaurants.isEmpty) {
    return const NearbyResult.failure(NearbyFailureReason.noResults);
  }
  return NearbyResult.success(restaurants);
});

Future<_LocationAttempt> _currentPosition() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return const _LocationAttempt.failed(
        NearbyFailureReason.locationServicesOff,
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      return const _LocationAttempt.failed(
        NearbyFailureReason.permissionDeniedForever,
      );
    }
    if (permission == LocationPermission.denied) {
      return const _LocationAttempt.failed(
        NearbyFailureReason.permissionDenied,
      );
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 8),
      ),
    );
    return _LocationAttempt.ok(position);
  } catch (error) {
    debugPrint('Location unavailable: $error');
    return const _LocationAttempt.failed(NearbyFailureReason.searchFailed);
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
  if (nearby == null || !nearby.isSuccess) return const [];

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
