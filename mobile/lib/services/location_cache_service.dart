import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Cached location data model
class CachedLocation {
  final double latitude;
  final double longitude;
  final double? accuracy;
  final DateTime timestamp;

  CachedLocation({
    required this.latitude,
    required this.longitude,
    this.accuracy,
    required this.timestamp,
  });

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  /// Create from JSON
  factory CachedLocation.fromJson(Map<String, dynamic> json) {
    return CachedLocation(
      latitude: json['latitude'],
      longitude: json['longitude'],
      accuracy: json['accuracy'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

/// Service for caching location updates when offline
class LocationCacheService {
  static final LocationCacheService _instance =
      LocationCacheService._internal();
  factory LocationCacheService() => _instance;
  LocationCacheService._internal();

  static const String _cacheKey = 'cached_locations';
  static const int _maxCacheSize = 100; // Maximum number of cached locations
  static const int _maxCacheAgeDays = 7; // Maximum age of cached locations

  /// Cache a location update
  Future<void> cacheLocation({
    required double latitude,
    required double longitude,
    double? accuracy,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Get existing cache
      final cachedList = await _getCachedList();

      // Add new location
      cachedList.add(CachedLocation(
        latitude: latitude,
        longitude: longitude,
        accuracy: accuracy,
        timestamp: DateTime.now(),
      ));

      // Clean up old entries
      _cleanupCache(cachedList);

      // Save back to SharedPreferences
      await _saveCachedList(cachedList);

      print('Location cached successfully. Total cached: ${cachedList.length}');
    } catch (e) {
      print('Error caching location: $e');
    }
  }

  /// Get all cached locations
  Future<List<CachedLocation>> getCachedLocations() async {
    return await _getCachedList();
  }

  /// Get cached locations from SharedPreferences
  Future<List<CachedLocation>> _getCachedList() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_cacheKey);

      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }

      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList
          .map((json) => CachedLocation.fromJson(json))
          .toList();
    } catch (e) {
      print('Error reading cached locations: $e');
      return [];
    }
  }

  /// Save cached locations to SharedPreferences
  Future<void> _saveCachedList(List<CachedLocation> locations) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = locations.map((loc) => loc.toJson()).toList();
      final jsonString = jsonEncode(jsonList);
      await prefs.setString(_cacheKey, jsonString);
    } catch (e) {
      print('Error saving cached locations: $e');
    }
  }

  /// Clean up old and excess cached locations
  void _cleanupCache(List<CachedLocation> locations) {
    // Remove locations older than _maxCacheAgeDays
    final cutoffDate = DateTime.now().subtract(
      Duration(days: _maxCacheAgeDays),
    );
    locations.removeWhere((loc) => loc.timestamp.isBefore(cutoffDate));

    // Keep only the most recent _maxCacheSize locations
    if (locations.length > _maxCacheSize) {
      locations.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      locations.removeRange(_maxCacheSize, locations.length);
    }
  }

  /// Remove a specific cached location
  Future<void> removeCachedLocation(CachedLocation location) async {
    try {
      final cachedList = await _getCachedList();
      cachedList.removeWhere((loc) =>
          loc.latitude == location.latitude &&
          loc.longitude == location.longitude &&
          loc.timestamp == location.timestamp);
      await _saveCachedList(cachedList);
      print('Cached location removed. Remaining: ${cachedList.length}');
    } catch (e) {
      print('Error removing cached location: $e');
    }
  }

  /// Clear all cached locations
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      print('Location cache cleared');
    } catch (e) {
      print('Error clearing cache: $e');
    }
  }

  /// Get number of cached locations
  Future<int> getCacheSize() async {
    final cachedList = await _getCachedList();
    return cachedList.length;
  }
}
