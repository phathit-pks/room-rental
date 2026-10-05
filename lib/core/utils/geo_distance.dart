import 'dart:math' as math;

/// Great-circle (haversine) distance between two coordinates, in meters.
double distanceBetweenMeters(
  double firstLatitude,
  double firstLongitude,
  double secondLatitude,
  double secondLongitude,
) {
  final latitudeDelta = _toRadians(secondLatitude - firstLatitude);
  final longitudeDelta = _toRadians(secondLongitude - firstLongitude);
  final a =
      math.sin(latitudeDelta / 2) * math.sin(latitudeDelta / 2) +
      math.cos(_toRadians(firstLatitude)) *
          math.cos(_toRadians(secondLatitude)) *
          math.sin(longitudeDelta / 2) *
          math.sin(longitudeDelta / 2);
  return 12742000 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

double _toRadians(double degrees) => degrees * math.pi / 180;
