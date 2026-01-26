import 'dart:math';
import '../models/latlng.dart';

/// Utility class for location privacy through fuzzing
class LocationFuzzing {
  static final Random _random = Random();
  
  /// Adds random offset to a location within specified radius (in meters)
  /// Returns a new LatLng that is within [radiusMeters] of the original position
  static LatLng fuzzLocation(LatLng precise, {double radiusMeters = 100.0}) {
    // Generate random distance within radius (0 to radiusMeters)
    final double distance = _random.nextDouble() * radiusMeters;
    
    // Generate random angle (0 to 2π)
    final double angle = _random.nextDouble() * 2 * pi;
    
    // Convert meters to degrees (approximate)
    // 1 degree latitude ≈ 111,320 meters
    // 1 degree longitude ≈ 111,320 * cos(latitude) meters
    final double latOffset = (distance * cos(angle)) / 111320.0;
    final double lngOffset = (distance * sin(angle)) / (111320.0 * cos(precise.latitude * pi / 180));
    
    return LatLng(
      precise.latitude + latOffset,
      precise.longitude + lngOffset,
    );
  }
  
  /// Returns the fuzzing radius in meters (for UI display)
  static double get defaultRadiusMeters => 100.0;
}
