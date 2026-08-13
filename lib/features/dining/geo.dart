import 'dart:math' as math;

/// Great-circle distance in metres.
///
/// Neither Places nor Overpass return a distance for a search result, and
/// straight-line is the honest thing to show anyway: a walking-route distance
/// implies a routing call this app does not make.
double haversineMetres(double lat1, double lon1, double lat2, double lon2) {
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
