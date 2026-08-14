import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/dining/restaurant.dart';
import '../../features/dining/fixtures.dart';
import '../../features/dining/rank.dart';
import 'nutrition_providers.dart';
import 'user_profile_provider.dart';

/// Why a nearby search did not produce a usable list. Unreachable in this
/// build — [nearbyRestaurantsProvider] always succeeds — kept because the UI
/// still switches on it; a real backend restores the location/Overpass path
/// that can produce these.
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

/// No backend in this build: always the fixture list, immediately — no
/// location permission dance, no Overpass call. A real backend restores the
/// location/Overpass search this replaced.
final nearbyRestaurantsProvider = FutureProvider<NearbyResult>(
  (ref) async => const NearbyResult.success(fixtureRestaurants),
);

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
