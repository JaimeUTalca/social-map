import 'dart:math';
import '../models/latlng.dart';

class _FuzzCache {
  final LatLng offset;
  final DateTime expiresAt;

  _FuzzCache(this.offset, this.expiresAt);
}

/// Utility class for location privacy through fuzzing
class LocationFuzzing {
  static final Random _random = Random();
  
  // Cache to maintain the same fuzzed offset for each user for a period of time
  static final Map<String, _FuzzCache> _userOffsets = {};
  static const int _cacheDurationSeconds = 30; // Movimiento aleatorio cada 30 segundos
  
  /// Adds random offset to a location within specified radius (in meters)
  /// Maintains the same offset for [userId] for 30 seconds to prevent jittering
  static LatLng fuzzLocation(LatLng precise, String userId, {double radiusMeters = 300.0}) {
    final now = DateTime.now();
    
    // Check if we have a valid cached offset for this user
    if (_userOffsets.containsKey(userId) && _userOffsets[userId]!.expiresAt.isAfter(now)) {
      final cachedOffset = _userOffsets[userId]!.offset;
      return LatLng(
        precise.latitude + cachedOffset.latitude,
        precise.longitude + cachedOffset.longitude,
      );
    }
    
    // Generate new random offset
    final double distance = _random.nextDouble() * radiusMeters;
    final double angle = _random.nextDouble() * 2 * pi;
    
    // Convert meters to degrees (approximate)
    final double latOffset = (distance * cos(angle)) / 111320.0;
    final double lngOffset = (distance * sin(angle)) / (111320.0 * cos(precise.latitude * pi / 180));
    
    // Save to cache
    _userOffsets[userId] = _FuzzCache(
      LatLng(latOffset, lngOffset),
      now.add(const Duration(seconds: _cacheDurationSeconds)),
    );
    
    return LatLng(
      precise.latitude + latOffset,
      precise.longitude + lngOffset,
    );
  }
  
  /// Returns the fuzzing radius in meters (for UI display)
  static double get defaultRadiusMeters => 300.0;
}
