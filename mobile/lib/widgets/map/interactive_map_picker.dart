import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/constants/app_colors.dart';
import '../../services/places_service.dart';
import '../../services/location_service.dart';
import '../../screens/schedule/steps/step2_location_screen.dart';

/// Interactive map picker with search and pin selection
class InteractiveMapPicker extends StatefulWidget {
  final LocationData? initialLocation;
  final Function(LocationData) onLocationSelected;

  const InteractiveMapPicker({
    super.key,
    this.initialLocation,
    required this.onLocationSelected,
  });

  @override
  State<InteractiveMapPicker> createState() => _InteractiveMapPickerState();
}

class _InteractiveMapPickerState extends State<InteractiveMapPicker> {
  final PlacesService _placesService = PlacesService();
  final LocationService _locationService = LocationService();
  final TextEditingController _searchController = TextEditingController();

  GoogleMapController? _mapController;
  LatLng _currentPosition = const LatLng(35.6762, 139.6503); // Default: Tokyo
  Set<Marker> _markers = {};
  LocationData? _selectedLocation;
  bool _isLoadingLocation = false;
  bool _isSearching = false;
  bool _hasShownPermissionPrompt = false; // Track if we've already shown the prompt

  // Search results
  List<PlacePrediction> _searchResults = [];
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _initializeMap();
    _searchController.addListener(_onSearchTextChanged);
    // Check permission and show prompt if needed
    _checkPermissionAndPromptIfNeeded();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  /// Check location permission and show prompt if not granted
  Future<void> _checkPermissionAndPromptIfNeeded() async {
    // Don't show prompt if we've already shown it in this session
    if (_hasShownPermissionPrompt) return;

    // Wait a moment for the screen to settle
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    try {
      final permission = await _locationService.checkPermission();
      print('[MapPicker] Current permission: $permission');

      // If permission is not "always", show prompt
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        _hasShownPermissionPrompt = true;
        _showPermissionPromptDialog();
      }
    } catch (e) {
      print('[MapPicker] Error checking permission: $e');
    }
  }

  /// Show dialog prompting user to enable location permission
  void _showPermissionPromptDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.location_on, color: Colors.blue, size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                '位置情報の許可',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'imaneは、あなたが目的地に到着したときに自動的に通知を送るため、位置情報の許可が必要です。',
              style: TextStyle(fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: AppColors.primary),
                      const SizedBox(width: 8),
                      const Text(
                        'バックグラウンドでの追跡が必要です',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '設定で「常に許可」を選択してください。',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '※ 手動で場所を選択する場合は「後で」を選択できます',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              '後で',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _openSettingsAndWaitForReturn();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('設定を開く'),
          ),
        ],
      ),
    );
  }

  /// Open app settings and check permission again when user returns
  Future<void> _openSettingsAndWaitForReturn() async {
    await _locationService.openAppSettings();

    // Wait for user to potentially change settings
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // Check permission again
    final permission = await _locationService.checkPermission();
    print('[MapPicker] Permission after settings: $permission');

    if (permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse) {
      // Permission granted - get current location
      _getCurrentLocation();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('位置情報が許可されました'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _initializeMap() async {
    // If initial location is provided, use it
    if (widget.initialLocation != null &&
        widget.initialLocation!.latitude != null &&
        widget.initialLocation!.longitude != null) {
      final initialPos = LatLng(
        widget.initialLocation!.latitude!,
        widget.initialLocation!.longitude!,
      );
      setState(() {
        _currentPosition = initialPos;
        _selectedLocation = widget.initialLocation;
        _addMarker(initialPos, widget.initialLocation!.name);
      });
    } else {
      // Try to get current location (but don't block if permission is denied)
      // User can still manually search or tap on map
      _getCurrentLocation();
    }
  }

  Future<void> _getCurrentLocation({bool showErrorMessage = false}) async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      // Check and request permission first
      final hasPermission = await _locationService.requestPermission();

      if (!hasPermission) {
        // Permission denied - show message to user only if explicitly requested
        if (mounted && showErrorMessage) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('位置情報の許可が必要です。設定から許可してください。'),
              backgroundColor: AppColors.error,
              action: SnackBarAction(
                label: '設定',
                textColor: Colors.white,
                onPressed: () {
                  _locationService.openAppSettings();
                },
              ),
              duration: const Duration(seconds: 5),
            ),
          );
        }
        return;
      }

      final position = await _locationService.getCurrentLocation();
      if (position != null && mounted) {
        final latLng = LatLng(position.latitude, position.longitude);
        setState(() {
          _currentPosition = latLng;
        });
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(latLng, 15),
        );
      }
    } catch (e) {
      print('Error getting current location: $e');
      if (mounted && showErrorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('現在地を取得できませんでした'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
        });
      }
    }
  }

  void _onSearchTextChanged() {
    final query = _searchController.text.trim();

    // Cancel previous timer
    _debounceTimer?.cancel();

    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    // Debounce search by 500ms
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    try {
      final predictions = await _placesService.getAutocompletePredictions(query);
      if (mounted) {
        setState(() {
          _searchResults = predictions;
          _isSearching = false;
        });
      }
    } catch (e) {
      print('Error performing search: $e');
      if (mounted) {
        setState(() {
          _isSearching = false;
          _searchResults = [];
        });

        // Show error message to user
        if (e.toString().contains('403')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'API設定エラー: Google Cloud ConsoleでAPI Keyの制限を「なし」または「HTTPリファラー」に変更してください',
              ),
              backgroundColor: AppColors.error,
              duration: const Duration(seconds: 5),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('検索エラー: ${e.toString()}'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _onSearchResultTapped(PlacePrediction prediction) async {
    // Clear search results
    setState(() {
      _searchResults = [];
      _searchController.text = prediction.mainText;
    });

    // Unfocus keyboard
    FocusScope.of(context).unfocus();

    // Get place details (coordinates) in Japanese
    final placeDetails = await _placesService.getPlaceDetails(
      prediction.placeId,
      language: 'ja',
    );

    if (placeDetails != null && mounted) {
      print('[MapPicker] Place details: name=${placeDetails.name}, address=${placeDetails.formattedAddress}');
      final latLng = LatLng(placeDetails.latitude, placeDetails.longitude);

      setState(() {
        _currentPosition = latLng;
        _selectedLocation = LocationData(
          name: placeDetails.name,
          address: placeDetails.formattedAddress,
          latitude: placeDetails.latitude,
          longitude: placeDetails.longitude,
        );
        _addMarker(latLng, placeDetails.name);
      });

      // Animate camera to the location
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(latLng, 15),
      );
    }
  }

  void _onMapTapped(LatLng position) async {
    // User tapped on map - place a marker
    setState(() {
      _currentPosition = position;
      _isLoadingLocation = true;
    });

    // Get address from coordinates using reverse geocoding (in Japanese)
    final placeDetails = await _placesService.reverseGeocode(
      position.latitude,
      position.longitude,
      language: 'ja',
    );

    if (mounted) {
      if (placeDetails != null) {
        setState(() {
          _selectedLocation = LocationData(
            name: placeDetails.name,
            address: placeDetails.formattedAddress,
            latitude: position.latitude,
            longitude: position.longitude,
          );
          _addMarker(position, placeDetails.name);
          _isLoadingLocation = false;
        });
      } else {
        // Fallback to coordinates if reverse geocoding fails
        setState(() {
          _selectedLocation = LocationData(
            name: '選択された場所',
            address: '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}',
            latitude: position.latitude,
            longitude: position.longitude,
          );
          _addMarker(position, '選択された場所');
          _isLoadingLocation = false;
        });
      }
    }
  }

  void _onMapLongPressed(LatLng position) async {
    // Long press on map - show more detailed information
    setState(() {
      _currentPosition = position;
      _isLoadingLocation = true;
    });

    // Get address from coordinates using reverse geocoding (in Japanese)
    final placeDetails = await _placesService.reverseGeocode(
      position.latitude,
      position.longitude,
      language: 'ja',
    );

    if (mounted) {
      if (placeDetails != null) {
        setState(() {
          _selectedLocation = LocationData(
            name: placeDetails.name,
            address: placeDetails.formattedAddress,
            latitude: position.latitude,
            longitude: position.longitude,
          );
          _addMarker(position, placeDetails.name);
          _isLoadingLocation = false;
        });
      } else {
        // Fallback to coordinates if reverse geocoding fails
        setState(() {
          _selectedLocation = LocationData(
            name: '選択された場所',
            address: '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}',
            latitude: position.latitude,
            longitude: position.longitude,
          );
          _addMarker(position, '選択された場所');
          _isLoadingLocation = false;
        });
      }
    }
  }

  void _addMarker(LatLng position, String title) {
    setState(() {
      _markers = {
        Marker(
          markerId: const MarkerId('selected_location'),
          position: position,
          infoWindow: InfoWindow(title: title),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      };
    });
  }

  void _onConfirmLocation() {
    if (_selectedLocation != null) {
      widget.onLocationSelected(_selectedLocation!);
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('場所を選択してください'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Google Map
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentPosition,
              zoom: 15,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
            },
            onTap: _onMapTapped,
            onLongPress: _onMapLongPressed,
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            zoomGesturesEnabled: true, // Enable pinch-to-zoom with 2 fingers
            mapToolbarEnabled: false,
            buildingsEnabled: true,
            trafficEnabled: false,
          ),

          // Top search bar
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Search box
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back),
                              onPressed: () => Navigator.pop(context),
                            ),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                decoration: InputDecoration(
                                  hintText: '場所や住所を検索',
                                  hintStyle: TextStyle(
                                    color: AppColors.textPlaceholder,
                                    fontSize: 14,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                            if (_searchController.text.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                },
                              ),
                          ],
                        ),
                      ),

                      // Search results
                      if (_searchResults.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          constraints: const BoxConstraints(maxHeight: 300),
                          child: ListView.separated(
                            shrinkWrap: true,
                            padding: const EdgeInsets.all(8),
                            itemCount: _searchResults.length,
                            separatorBuilder: (context, index) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final prediction = _searchResults[index];
                              return ListTile(
                                leading: Icon(
                                  Icons.location_on,
                                  color: AppColors.primary,
                                ),
                                title: Text(
                                  prediction.mainText,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                subtitle: Text(
                                  prediction.secondaryText,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                onTap: () => _onSearchResultTapped(prediction),
                              );
                            },
                          ),
                        ),

                      // Loading indicator for search
                      if (_isSearching)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Bottom buttons
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              // Extend white background below safe area to hide Google logo
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                top: false, // Don't add top padding
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Selected location info
                      if (_selectedLocation != null)
                        Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppColors.inputBackground,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              color: AppColors.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedLocation!.name,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    _selectedLocation!.address,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      Row(
                        children: [
                          // Current location button
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(color: AppColors.primary),
                            ),
                            child: IconButton(
                              icon: Icon(
                                Icons.my_location,
                                color: AppColors.primary,
                              ),
                              onPressed: _isLoadingLocation
                                  ? null
                                  : () => _getCurrentLocation(showErrorMessage: true),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Confirm button
                          Expanded(
                            child: SizedBox(
                              height: 56,
                              child: ElevatedButton(
                                onPressed: _selectedLocation != null ? _onConfirmLocation : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: AppColors.inputBorder,
                                  disabledForegroundColor: AppColors.textSecondary,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(28),
                                  ),
                                ),
                                child: const Text(
                                  'この場所を選択',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
          ),

          // Loading overlay
          if (_isLoadingLocation)
            Container(
              color: Colors.black26,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}
