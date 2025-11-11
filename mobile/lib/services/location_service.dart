import 'dart:async';
import 'package:background_location/background_location.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'api_service.dart';
import 'location_cache_service.dart';
import 'popup_notification_service.dart';
import '../models/notification_history.dart';

/// Location tracking service for imane
/// Handles background location tracking and sends updates to the backend API
class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  final ApiService _apiService = ApiService();
  final LocationCacheService _cacheService = LocationCacheService();
  final Connectivity _connectivity = Connectivity();

  bool _isTracking = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  DateTime? _lastUpdateTime;
  bool _isOnline = true;

  // Location update interval (in milliseconds)
  // TODO: 本番環境では10分 (10 * 60 * 1000) に戻す
  static const int _updateIntervalMs = 1 * 60 * 1000; // 1 minute (60 seconds) for testing

  // Minimum distance filter in meters
  // TODO: 本番環境では50.0mに戻す
  static const double _distanceFilterMeters = 5.0; // 5m for testing (was 50.0)

  /// Check if location tracking is currently active
  bool get isTracking => _isTracking;

  /// Check location permission status
  Future<LocationPermission> checkPermission() async {
    return await Geolocator.checkPermission();
  }

  /// Request location permission
  /// Returns true if permission is granted (Always or WhenInUse)
  Future<bool> requestPermission() async {
    // First check current permission
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    // For background tracking, we need "Always" permission
    if (permission == LocationPermission.whileInUse) {
      // Request "Always" permission using permission_handler
      final status = await Permission.locationAlways.request();
      return status.isGranted;
    }

    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  /// Check if the user has granted "Always Allow" permission
  Future<bool> hasAlwaysPermission() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always;
  }

  /// Start background location tracking
  /// Sends location updates every 10 minutes to the backend API
  Future<bool> startTracking() async {
    final timestamp = DateTime.now().toIso8601String();
    print('[$timestamp] [LocationService] === Starting location tracking ===');

    if (_isTracking) {
      print('[$timestamp] [LocationService] Already tracking - skipping');
      return true;
    }

    // Check permission first
    print('[$timestamp] [LocationService] Checking location permission...');

    // Check current permission status
    final currentPermission = await Geolocator.checkPermission();
    print('[$timestamp] [LocationService] Current permission: $currentPermission');

    final hasPermission = await requestPermission();
    if (!hasPermission) {
      print('[$timestamp] [LocationService] ✗ Permission denied');
      print('[$timestamp] [LocationService] ⚠️ Please go to: Settings → Privacy → Location Services → imane → Select "Always"');
      return false;
    }

    final finalPermission = await Geolocator.checkPermission();
    print('[$timestamp] [LocationService] ✓ Permission granted: $finalPermission');

    if (finalPermission != LocationPermission.always) {
      print('[$timestamp] [LocationService] ⚠️ Warning: Permission is not "Always". Background tracking may not work properly.');
      print('[$timestamp] [LocationService] ⚠️ Current: $finalPermission, Required: LocationPermission.always');
    }

    try {
      print('[$timestamp] [LocationService] Configuring background location...');
      print('  - Update interval: ${_updateIntervalMs}ms (${_updateIntervalMs / 1000}s)');
      print('  - Distance filter: ${_distanceFilterMeters}m');

      // Configure background location settings
      await BackgroundLocation.setAndroidNotification(
        title: 'imane',
        message: '位置情報を追跡中',
        icon: '@mipmap/ic_launcher',
      );

      // Set Android configuration
      await BackgroundLocation.setAndroidConfiguration(_updateIntervalMs);

      // Start location service
      await BackgroundLocation.startLocationService(
        distanceFilter: _distanceFilterMeters,
      );

      print('[$timestamp] [LocationService] Registering location update listener...');

      // Listen to location updates
      BackgroundLocation.getLocationUpdates((location) {
        print('[$timestamp] [LocationService] 🔔 Location callback triggered!');
        _handleLocationUpdate(location);
      });

      _isTracking = true;
      await _saveTrackingState(true);

      // Start connectivity monitoring
      _startConnectivityMonitoring();

      print('[$timestamp] [LocationService] ✓ Location tracking started successfully');
      print('[$timestamp] [LocationService] ⚠️ Distance filter: ${_distanceFilterMeters}m - Move at least this distance to trigger updates');
      print('[$timestamp] [LocationService] ⚠️ Update interval: ${_updateIntervalMs / 1000}s - Wait at least this long between updates');
      return true;
    } catch (e) {
      print('[$timestamp] [LocationService] ✗ Error starting location tracking: $e');
      return false;
    }
  }

  /// Stop background location tracking
  Future<void> stopTracking() async {
    if (!_isTracking) {
      print('Location tracking is not active');
      return;
    }

    try {
      await _connectivitySubscription?.cancel();
      _connectivitySubscription = null;

      await BackgroundLocation.stopLocationService();

      _isTracking = false;
      await _saveTrackingState(false);
      print('Location tracking stopped successfully');
    } catch (e) {
      print('Error stopping location tracking: $e');
    }
  }

  /// Handle location update from background service
  Future<void> _handleLocationUpdate(Location location) async {
    final now = DateTime.now();
    final timestamp = now.toIso8601String();

    print('[$timestamp] [LocationService] Location update received:');
    print('  - Latitude: ${location.latitude}');
    print('  - Longitude: ${location.longitude}');
    print('  - Accuracy: ${location.accuracy}m');
    print('  - Tracking active: $_isTracking');

    // Check if enough time has passed since last update
    if (_lastUpdateTime != null) {
      final timeDiff = now.difference(_lastUpdateTime!).inMilliseconds;
      final timeDiffSeconds = (timeDiff / 1000).toStringAsFixed(1);
      final requiredSeconds = (_updateIntervalMs / 1000).toStringAsFixed(1);

      print('  - Time since last update: ${timeDiffSeconds}s (required: ${requiredSeconds}s)');

      if (timeDiff < _updateIntervalMs) {
        print('  - Result: SKIPPED (interval not met)');
        return;
      }
    } else {
      print('  - First location update in this session');
    }

    _lastUpdateTime = now;
    print('  - Result: PROCESSING - sending to backend API');

    // Send location to backend API
    await _sendLocationWithRetry(location);
  }

  /// Start monitoring network connectivity
  void _startConnectivityMonitoring() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (List<ConnectivityResult> results) {
        final wasOffline = !_isOnline;
        _isOnline = results.isNotEmpty &&
                    results.any((result) => result != ConnectivityResult.none);

        print('Connectivity changed. Online: $_isOnline');

        // If we just came back online, retry cached locations
        if (_isOnline && wasOffline) {
          print('Connection restored. Retrying cached locations...');
          _retryCachedLocations();
        }
      },
    );
  }

  /// Send location with retry logic
  Future<void> _sendLocationWithRetry(Location location) async {
    final timestamp = DateTime.now().toIso8601String();
    print('[$timestamp] [LocationService] Attempting to send location to API...');

    try {
      await _sendLocationToApi(location);
      print('[$timestamp] [LocationService] ✓ Location sent successfully to backend');
    } catch (e) {
      print('[$timestamp] [LocationService] ✗ Failed to send location: $e');
      // Cache the location for later retry
      await _cacheService.cacheLocation(
        latitude: location.latitude!,
        longitude: location.longitude!,
        accuracy: location.accuracy,
      );
      print('[$timestamp] [LocationService] Location cached for later retry');
    }
  }

  /// Retry sending cached locations
  Future<void> _retryCachedLocations() async {
    try {
      final cachedLocations = await _cacheService.getCachedLocations();

      if (cachedLocations.isEmpty) {
        print('No cached locations to retry');
        return;
      }

      print('Retrying ${cachedLocations.length} cached locations...');

      int successCount = 0;
      int failCount = 0;

      for (final cachedLocation in cachedLocations) {
        try {
          await _apiService.updateLocation(
            latitude: cachedLocation.latitude,
            longitude: cachedLocation.longitude,
            accuracy: cachedLocation.accuracy,
          );

          // Remove from cache on success
          await _cacheService.removeCachedLocation(cachedLocation);
          successCount++;
        } catch (e) {
          print('Failed to retry cached location: $e');
          failCount++;
        }
      }

      print('Retry complete. Success: $successCount, Failed: $failCount');
    } catch (e) {
      print('Error retrying cached locations: $e');
    }
  }

  /// Send location data to backend API
  Future<void> _sendLocationToApi(Location location) async {
    final timestamp = DateTime.now().toIso8601String();

    try {
      print('[$timestamp] [LocationService] Calling API updateLocation...');
      print('  - Endpoint: /location/update');
      print('  - Coords: (${location.latitude}, ${location.longitude})');
      print('  - Accuracy: ${location.accuracy ?? 0.0}m');

      final response = await _apiService.updateLocation(
        latitude: location.latitude!,
        longitude: location.longitude!,
        accuracy: location.accuracy ?? 0.0,
      );

      print('[$timestamp] [LocationService] API response received:');
      print('  - Response: $response');
      print('[$timestamp] [LocationService] ✓ Location sent to API successfully');

      // Handle triggered notifications from backend
      _handleTriggeredNotifications(response, location);
    } catch (e) {
      print('[$timestamp] [LocationService] ✗ Failed to send location to API: $e');
      rethrow;
    }
  }

  /// Handle notifications triggered by backend
  void _handleTriggeredNotifications(Map<String, dynamic> response, Location location) {
    try {
      final triggeredNotifications = response['triggered_notifications'] as List?;
      final scheduleUpdates = response['schedule_updates'] as List?;

      if (triggeredNotifications == null || triggeredNotifications.isEmpty) {
        return;
      }

      print('[LocationService] Processing ${triggeredNotifications.length} triggered notifications');

      // Get popup service
      final popupService = PopupNotificationService();

      // Process each notification
      for (final notification in triggeredNotifications) {
        final type = notification['type'] as String?;
        final scheduleId = notification['schedule_id'] as String?;

        if (type == null || scheduleId == null) continue;

        // Find corresponding schedule update for details
        final scheduleUpdate = scheduleUpdates?.firstWhere(
          (update) => update['schedule_id'] == scheduleId,
          orElse: () => null,
        );

        final destinationName = scheduleUpdate?['destination_name'] as String? ?? '目的地';
        final distance = scheduleUpdate?['distance'] as double?;

        // Create notification title and body based on type
        final notificationType = NotificationType.fromString(type);
        final String title;
        String body; // Non-final to allow modification
        final String? mapLink;

        switch (notificationType) {
          case NotificationType.arrival:
            title = '到着通知';
            body = '今ね、$destinationNameへ到着したよ';
            if (distance != null) {
              body += '\n距離: ${distance.toStringAsFixed(0)}m';
            }
            mapLink = 'https://www.google.com/maps?q=${location.latitude},${location.longitude}';
            break;
          case NotificationType.stay:
            title = '滞在通知';
            body = '今ね、$destinationNameに滞在しているよ';
            mapLink = 'https://www.google.com/maps?q=${location.latitude},${location.longitude}';
            break;
          case NotificationType.departure:
            title = '出発通知';
            body = '今ね、${destinationName}から出発したよ';
            mapLink = null;
            break;
        }

        // Show popup notification
        print('[LocationService] Showing popup: $title - $body');
        popupService.show(
          title: title,
          body: body,
          type: notificationType,
          mapLink: mapLink,
        );
      }
    } catch (e) {
      print('[LocationService] Error handling triggered notifications: $e');
    }
  }

  /// Get current location (one-time request)
  Future<Position?> getCurrentLocation() async {
    try {
      final hasPermission = await requestPermission();
      if (!hasPermission) {
        print('Location permission not granted');
        return null;
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
        ),
      );
    } catch (e) {
      print('Error getting current location: $e');
      return null;
    }
  }

  /// Save tracking state to SharedPreferences
  Future<void> _saveTrackingState(bool isTracking) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('location_tracking_active', isTracking);
  }

  /// Load tracking state from SharedPreferences
  Future<bool> loadTrackingState() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('location_tracking_active') ?? false;
  }

  /// Resume tracking on app restart if it was previously active
  Future<void> resumeTrackingIfNeeded() async {
    final wasTracking = await loadTrackingState();
    if (wasTracking && !_isTracking) {
      print('Resuming location tracking from previous session');
      await startTracking();
    }
  }

  /// Calculate distance between two coordinates using Haversine formula
  /// Returns distance in meters
  double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  /// Get number of cached locations waiting to be sent
  Future<int> getCachedLocationCount() async {
    return await _cacheService.getCacheSize();
  }

  /// Manually trigger retry of cached locations
  Future<void> retryFailedLocations() async {
    await _retryCachedLocations();
  }

  /// Clear all cached locations
  Future<void> clearLocationCache() async {
    await _cacheService.clearCache();
  }

  /// Open app settings (iOS Settings)
  Future<bool> openAppSettings() async {
    return await Geolocator.openAppSettings();
  }

  /// Open location settings
  Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }

  /// Dispose resources
  Future<void> dispose() async {
    await stopTracking();
  }
}
