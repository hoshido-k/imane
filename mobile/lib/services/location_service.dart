import 'dart:async';
import 'package:background_location/background_location.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'api_service.dart';
import 'location_cache_service.dart';

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

  // Foreground auto-update (for debugging)
  Timer? _foregroundTimer;
  bool _isForegroundAutoUpdateEnabled = false;

  // Location update interval (in milliseconds)
  // TODO: 本番環境では10分 (10 * 60 * 1000) に戻す
  static const int _updateIntervalMs = 1 * 5 * 1000; // 1 minute for testing

  // Minimum distance filter in meters
  static const double _distanceFilterMeters = 50.0;

  /// Check if location tracking is currently active
  bool get isTracking => _isTracking;

  /// Check if foreground auto-update is enabled
  bool get isForegroundAutoUpdateEnabled => _isForegroundAutoUpdateEnabled;

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
    final hasPermission = await requestPermission();
    if (!hasPermission) {
      print('[$timestamp] [LocationService] ✗ Permission denied');
      return false;
    }
    print('[$timestamp] [LocationService] ✓ Permission granted');

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
        _handleLocationUpdate(location);
      });

      _isTracking = true;
      await _saveTrackingState(true);

      // Start connectivity monitoring
      _startConnectivityMonitoring();

      print('[$timestamp] [LocationService] ✓ Location tracking started successfully');
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
    } catch (e) {
      print('[$timestamp] [LocationService] ✗ Failed to send location to API: $e');
      rethrow;
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

  /// Start foreground auto-update (for debugging)
  /// This sends location updates every 5 seconds while the app is in foreground
  Future<void> startForegroundAutoUpdate() async {
    if (_isForegroundAutoUpdateEnabled) {
      print('[LocationService] Foreground auto-update is already running');
      return;
    }

    print('[LocationService] Starting foreground auto-update...');
    _isForegroundAutoUpdateEnabled = true;

    // Start timer to send location every 5 seconds
    _foregroundTimer = Timer.periodic(
      Duration(milliseconds: _updateIntervalMs),
      (timer) async {
        try {
          print('[LocationService] [Timer] Fetching location...');
          final position = await getCurrentLocation();

          if (position != null) {
            print('[LocationService] [Timer] Location fetched, sending to API...');
            await _apiService.updateLocation(
              latitude: position.latitude,
              longitude: position.longitude,
              accuracy: position.accuracy,
            );
            print('[LocationService] [Timer] ✓ Location sent successfully');
          } else {
            print('[LocationService] [Timer] ✗ Failed to get location');
          }
        } catch (e) {
          print('[LocationService] [Timer] ✗ Error: $e');
        }
      },
    );

    print('[LocationService] Foreground auto-update started');
  }

  /// Stop foreground auto-update
  void stopForegroundAutoUpdate() {
    if (!_isForegroundAutoUpdateEnabled) {
      print('[LocationService] Foreground auto-update is not running');
      return;
    }

    print('[LocationService] Stopping foreground auto-update...');
    _foregroundTimer?.cancel();
    _foregroundTimer = null;
    _isForegroundAutoUpdateEnabled = false;
    print('[LocationService] Foreground auto-update stopped');
  }

  /// Send current location manually (for debugging)
  Future<Map<String, dynamic>> sendCurrentLocationManually() async {
    final timestamp = DateTime.now().toIso8601String();
    print('[$timestamp] [LocationService] Manual location send requested...');

    try {
      // Get current location
      print('[$timestamp] [LocationService] Fetching current location...');
      final position = await getCurrentLocation();

      if (position == null) {
        throw Exception('Failed to get current location');
      }

      print('[$timestamp] [LocationService] Location fetched:');
      print('  - Latitude: ${position.latitude}');
      print('  - Longitude: ${position.longitude}');
      print('  - Accuracy: ${position.accuracy}m');

      // Send to API
      print('[$timestamp] [LocationService] Sending to API...');
      final response = await _apiService.updateLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
      );

      print('[$timestamp] [LocationService] ✓ Manual send successful');
      print('  - Response: $response');

      return {
        'success': true,
        'position': {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'accuracy': position.accuracy,
        },
        'response': response,
        'timestamp': timestamp,
      };
    } catch (e) {
      print('[$timestamp] [LocationService] ✗ Manual send failed: $e');
      return {
        'success': false,
        'error': e.toString(),
        'timestamp': timestamp,
      };
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    stopForegroundAutoUpdate();
    await stopTracking();
  }
}
