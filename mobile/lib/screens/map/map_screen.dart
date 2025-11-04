import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/constants/app_colors.dart';
import '../../widgets/common/app_header.dart';
import '../../widgets/map/category_filter.dart';
import '../../widgets/map/pop_card.dart';
import '../../widgets/map/current_location_marker.dart';
import '../../models/pop.dart';
import '../pop/pop_detail_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  PopCategory _selectedCategory = PopCategory.all;
  Map<String, Offset> _popScreenPositions = {};
  BitmapDescriptor? _currentLocationIcon;
  String? _longPressedPopId;
  bool _isLongPressing = false;
  List<String> _popRenderOrder = []; // Stores pop IDs in render order (back to front)

  // Tokyo Station as fixed location (東京駅)
  static const LatLng _tokyoStation = LatLng(35.6812, 139.7671);
  static const CameraPosition _initialPosition = CameraPosition(
    target: _tokyoStation,
    zoom: 15.0,
  );

  // Sample pop data around Tokyo
  late final List<Pop> _pops = [
    Pop(
      id: '1',
      userId: 'user1',
      userName: 'Coffee Lover',
      userAvatar: '☕',
      message: '素敵なカフェ見つけた！',
      category: PopCategory.cafe,
      location: const LatLng(35.6795, 139.7690),
      locationName: 'Shibuya Cafe',
      createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
      likeCount: 12,
      commentCount: 3,
    ),
    Pop(
      id: '2',
      userId: 'user2',
      userName: 'Ramen Master',
      userAvatar: '🍜',
      message: '美味しいラーメン発見！',
      category: PopCategory.gourmet,
      location: const LatLng(35.6830, 139.7650),
      locationName: 'Ramen Street',
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      likeCount: 25,
      commentCount: 8,
    ),
    Pop(
      id: '3',
      userId: 'user3',
      userName: 'Movie Fan',
      userAvatar: '🎬',
      message: '映画見に来た！おすすめ',
      category: PopCategory.entertainment,
      location: const LatLng(35.6850, 139.7700),
      locationName: 'Cinema Complex',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      likeCount: 8,
      commentCount: 2,
    ),
    Pop(
      id: '4',
      userId: 'user4',
      userName: 'Runner',
      userAvatar: '🏃',
      message: 'ランニング中！気持ちいい',
      category: PopCategory.sports,
      location: const LatLng(35.6800, 139.7720),
      locationName: 'Park',
      createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
      likeCount: 15,
      commentCount: 5,
    ),
    Pop(
      id: '5',
      userId: 'user5',
      userName: 'Gamer',
      userAvatar: '🎮',
      message: 'ゲームセンター楽しい！',
      category: PopCategory.gaming,
      location: const LatLng(35.6780, 139.7640),
      locationName: 'Game Center',
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      likeCount: 20,
      commentCount: 7,
    ),
    Pop(
      id: '6',
      userId: 'user6',
      userName: 'Student',
      userAvatar: '📚',
      message: '勉強カフェで作業中',
      category: PopCategory.study,
      location: const LatLng(35.6820, 139.7710),
      locationName: 'Study Cafe',
      createdAt: DateTime.now().subtract(const Duration(minutes: 45)),
      likeCount: 10,
      commentCount: 1,
    ),
  ];

  // Dark blue map style with minimal labels (station names only)
  static const String _mapStyle = '''
[
  {
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#1d2c4d"
      }
    ]
  },
  {
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#8ec3b9"
      }
    ]
  },
  {
    "elementType": "labels.text.stroke",
    "stylers": [
      {
        "color": "#1a3646"
      }
    ]
  },
  {
    "featureType": "administrative.country",
    "elementType": "geometry.stroke",
    "stylers": [
      {
        "color": "#4b6878"
      }
    ]
  },
  {
    "featureType": "administrative.land_parcel",
    "elementType": "labels",
    "stylers": [
      {
        "visibility": "off"
      }
    ]
  },
  {
    "featureType": "administrative.province",
    "elementType": "geometry.stroke",
    "stylers": [
      {
        "color": "#4b6878"
      }
    ]
  },
  {
    "featureType": "landscape.man_made",
    "elementType": "geometry.stroke",
    "stylers": [
      {
        "color": "#334e87"
      }
    ]
  },
  {
    "featureType": "landscape.natural",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#023e58"
      }
    ]
  },
  {
    "featureType": "poi",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#283d6a"
      }
    ]
  },
  {
    "featureType": "poi",
    "elementType": "labels.text",
    "stylers": [
      {
        "visibility": "off"
      }
    ]
  },
  {
    "featureType": "poi",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#6f9ba5"
      }
    ]
  },
  {
    "featureType": "poi",
    "elementType": "labels.text.stroke",
    "stylers": [
      {
        "color": "#1d2c4d"
      }
    ]
  },
  {
    "featureType": "poi.park",
    "elementType": "geometry.fill",
    "stylers": [
      {
        "color": "#023e58"
      }
    ]
  },
  {
    "featureType": "poi.park",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#3C7680"
      }
    ]
  },
  {
    "featureType": "road",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#304a7d"
      }
    ]
  },
  {
    "featureType": "road",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#98a5be"
      }
    ]
  },
  {
    "featureType": "road",
    "elementType": "labels.text.stroke",
    "stylers": [
      {
        "color": "#1d2c4d"
      }
    ]
  },
  {
    "featureType": "road",
    "elementType": "labels",
    "stylers": [
      {
        "visibility": "off"
      }
    ]
  },
  {
    "featureType": "road.highway",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#2c6675"
      }
    ]
  },
  {
    "featureType": "road.highway",
    "elementType": "geometry.stroke",
    "stylers": [
      {
        "color": "#255763"
      }
    ]
  },
  {
    "featureType": "road.highway",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#b0d5df"
      }
    ]
  },
  {
    "featureType": "road.highway",
    "elementType": "labels.text.stroke",
    "stylers": [
      {
        "color": "#023e58"
      }
    ]
  },
  {
    "featureType": "transit",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#98a5be"
      }
    ]
  },
  {
    "featureType": "transit",
    "elementType": "labels.text.stroke",
    "stylers": [
      {
        "color": "#1d2c4d"
      }
    ]
  },
  {
    "featureType": "transit.line",
    "elementType": "geometry.fill",
    "stylers": [
      {
        "color": "#283d6a"
      }
    ]
  },
  {
    "featureType": "transit.station",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#3a4762"
      }
    ]
  },
  {
    "featureType": "transit.station",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#d59563"
      },
      {
        "visibility": "on"
      }
    ]
  },
  {
    "featureType": "water",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#0e1626"
      }
    ]
  },
  {
    "featureType": "water",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#4e6d70"
      }
    ]
  }
]
''';

  List<Pop> get _filteredPops {
    final filtered = _selectedCategory == PopCategory.all
        ? _pops
        : _pops.where((pop) => pop.category == _selectedCategory).toList();

    // Return in render order
    return _getOrderedPops(filtered);
  }

  List<Pop> _getOrderedPops(List<Pop> pops) {
    // Sort pops based on _popRenderOrder
    final orderedPops = <Pop>[];
    for (final popId in _popRenderOrder) {
      final pop = pops.firstWhere((p) => p.id == popId, orElse: () => pops.first);
      if (pops.contains(pop) && !orderedPops.contains(pop)) {
        orderedPops.add(pop);
      }
    }
    // Add any remaining pops not in order list
    for (final pop in pops) {
      if (!orderedPops.contains(pop)) {
        orderedPops.add(pop);
      }
    }
    return orderedPops;
  }

  @override
  void initState() {
    super.initState();
    // Use Tokyo Station as fixed location for mock data
    _setTokyoStationAsLocation();
    _createCurrentLocationIcon();
    // Initialize render order: newest pops first (by createdAt)
    _initializeRenderOrder();
  }

  void _initializeRenderOrder() {
    // Sort pops by createdAt (newest first = most recent time)
    final sortedPops = List<Pop>.from(_pops);
    sortedPops.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _popRenderOrder = sortedPops.map((pop) => pop.id).toList();
  }

  Future<void> _createCurrentLocationIcon() async {
    _currentLocationIcon = await CurrentLocationMarker.create();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _updatePopPositions() async {
    if (_mapController == null) return;

    final positions = <String, Offset>{};

    for (final pop in _filteredPops) {
      try {
        final screenCoordinate = await _mapController!.getScreenCoordinate(pop.location);
        positions[pop.id] = Offset(
          screenCoordinate.x.toDouble() - 75, // Center the card (width 150 / 2)
          screenCoordinate.y.toDouble() - 110, // Position above the point (adjusted for larger card)
        );
      } catch (e) {
        // Ignore errors for pops outside the visible area
      }
    }

    if (mounted) {
      setState(() {
        _popScreenPositions = positions;
      });
    }
  }

  void _showPopDetails(Pop pop) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          child: PopDetailScreen(pop: pop),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Fall back to Tokyo Station for mock data
        _setTokyoStationAsLocation();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          // Fall back to Tokyo Station for mock data
          _setTokyoStationAsLocation();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        // Fall back to Tokyo Station for mock data
        _setTokyoStationAsLocation();
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      setState(() {
        _currentPosition = position;
      });

      // Move camera to current location
      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLng(
            LatLng(position.latitude, position.longitude),
          ),
        );
      }
    } catch (e) {
      // Fall back to Tokyo Station for mock data
      _setTokyoStationAsLocation();
    }
  }

  void _setTokyoStationAsLocation() {
    setState(() {
      _currentPosition = Position(
        latitude: _tokyoStation.latitude,
        longitude: _tokyoStation.longitude,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              const AppHeader(title: 'Map'),

              // Map Content Area
              Expanded(
                child: Stack(
                  children: [
                    GoogleMap(
                      key: const ValueKey('google_map'),
                      initialCameraPosition: _initialPosition,
                      myLocationEnabled: false,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                      mapToolbarEnabled: false,
                      markers: _currentLocationIcon != null
                          ? {
                              // Current location marker (Tokyo Station for mock data)
                              Marker(
                                markerId: const MarkerId('current_location'),
                                position: _tokyoStation,
                                icon: _currentLocationIcon!,
                                anchor: const Offset(0.5, 0.5),
                                infoWindow: const InfoWindow(
                                  title: '現在地',
                                  snippet: '東京駅（モックデータ）',
                                ),
                              ),
                            }
                          : {},
                      onMapCreated: (controller) async {
                        _mapController = controller;
                        controller.setMapStyle(_mapStyle);

                        // Move to Tokyo Station for mock data
                        await controller.animateCamera(
                          CameraUpdate.newLatLng(_tokyoStation),
                        );

                        // Delay to ensure map is fully rendered
                        await Future.delayed(const Duration(milliseconds: 500));
                        await _updatePopPositions();
                      },
                      onCameraMove: (position) {
                        // Update pop positions in real-time when camera moves
                        _updatePopPositions();
                      },
                    ),

                    // Animated pop cards as overlays with single gesture detector
                    // Render long-pressed pop last to bring it to front
                    RawGestureDetector(
                      behavior: HitTestBehavior.translucent,
                      gestures: {
                        _CustomLongPressGestureRecognizer: GestureRecognizerFactoryWithHandlers<_CustomLongPressGestureRecognizer>(
                          () => _CustomLongPressGestureRecognizer(
                            duration: const Duration(milliseconds: 300),
                          ),
                          (_CustomLongPressGestureRecognizer instance) {
                            instance
                              ..onLongPressStart = (details) {
                                if (_isLongPressing) return;

                                // Find which pop was touched based on position
                                final touchPosition = details.localPosition;
                                Pop? touchedPop;

                                // Check pops in reverse order (top to bottom)
                                final popsToCheck = _filteredPops.reversed.toList();
                                for (final pop in popsToCheck) {
                                  final popPosition = _popScreenPositions[pop.id];
                                  if (popPosition == null) continue;

                                  // Check if touch is within pop card bounds
                                  // Card: 150 width, content height ~150, pin: 10
                                  if (touchPosition.dx >= popPosition.dx &&
                                      touchPosition.dx <= popPosition.dx + 150 &&
                                      touchPosition.dy >= popPosition.dy &&
                                      touchPosition.dy <= popPosition.dy + 160) {
                                    touchedPop = pop;
                                    break;
                                  }
                                }

                                if (touchedPop != null) {
                                  _isLongPressing = true;
                                  final popId = touchedPop.id;
                                  // Move touched pop to the end of render order (brings to front)
                                  _popRenderOrder.remove(popId);
                                  _popRenderOrder.add(popId);
                                  setState(() {
                                    _longPressedPopId = popId;
                                  });
                                }
                              }
                              ..onLongPressEnd = (details) {
                                if (_isLongPressing) {
                                  _isLongPressing = false;
                                  // Don't reset order - keep the pop at front
                                  // Only remove the scaling effect
                                  setState(() {
                                    _longPressedPopId = null;
                                  });
                                }
                              }
                              ..onLongPressCancel = () {
                                if (_isLongPressing) {
                                  _isLongPressing = false;
                                  // Don't reset order - keep the pop at front
                                  setState(() {
                                    _longPressedPopId = null;
                                  });
                                }
                              };
                          },
                        ),
                        TapGestureRecognizer: GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
                          () => TapGestureRecognizer(),
                          (TapGestureRecognizer instance) {
                            instance.onTapUp = (details) {
                              // Don't handle tap if currently long pressing
                              if (_isLongPressing) return;

                              // Handle tap to show pop details
                              final touchPosition = details.localPosition;
                              Pop? touchedPop;

                              final popsToCheck = _filteredPops.reversed.toList();
                              for (final pop in popsToCheck) {
                                final popPosition = _popScreenPositions[pop.id];
                                if (popPosition == null) continue;

                                if (touchPosition.dx >= popPosition.dx &&
                                    touchPosition.dx <= popPosition.dx + 150 &&
                                    touchPosition.dy >= popPosition.dy &&
                                    touchPosition.dy <= popPosition.dy + 160) {
                                  touchedPop = pop;
                                  break;
                                }
                              }

                              if (touchedPop != null) {
                                _showPopDetails(touchedPop);
                              }
                            };
                          },
                        ),
                      },
                      child: Stack(
                        children: _filteredPops.map((pop) {
                          final position = _popScreenPositions[pop.id];
                          if (position == null) return const SizedBox.shrink();

                          // Only scale while actively long pressing
                          final isThisPopLongPressed = _longPressedPopId == pop.id;

                          return Positioned(
                            left: position.dx,
                            top: position.dy,
                            child: IgnorePointer(
                              child: PopCard(
                                pop: pop,
                                enableAnimation: true,
                                isLongPressed: isThisPopLongPressed,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    // Category Filter
                    CategoryFilter(
                      selectedCategory: _selectedCategory,
                      onCategorySelected: (category) async {
                        setState(() {
                          _selectedCategory = category;
                        });
                        await _updatePopPositions(); // Update pop positions when category changes
                      },
                    ),

                    // Zoom and Recenter Controls
                    Positioned(
                      right: 16,
                      bottom: 16,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Zoom In button
                          FloatingActionButton(
                            mini: true,
                            heroTag: 'map_zoom_in',
                            backgroundColor: AppColors.cardBackground,
                            onPressed: () async {
                              if (_mapController != null) {
                                final zoom = await _mapController!.getZoomLevel();
                                _mapController!.animateCamera(
                                  CameraUpdate.zoomTo(zoom + 1),
                                );
                              }
                            },
                            child: const Icon(
                              Icons.add,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Zoom Out button
                          FloatingActionButton(
                            mini: true,
                            heroTag: 'map_zoom_out',
                            backgroundColor: AppColors.cardBackground,
                            onPressed: () async {
                              if (_mapController != null) {
                                final zoom = await _mapController!.getZoomLevel();
                                _mapController!.animateCamera(
                                  CameraUpdate.zoomTo(zoom - 1),
                                );
                              }
                            },
                            child: const Icon(
                              Icons.remove,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Recenter button (to Tokyo Station)
                          FloatingActionButton(
                            mini: true,
                            heroTag: 'map_recenter',
                            backgroundColor: AppColors.cardBackground,
                            onPressed: () {
                              _mapController?.animateCamera(
                                CameraUpdate.newLatLng(_tokyoStation),
                              );
                            },
                            child: const Icon(
                              Icons.my_location,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Custom LongPressGestureRecognizer with configurable duration
class _CustomLongPressGestureRecognizer extends LongPressGestureRecognizer {
  final Duration duration;

  _CustomLongPressGestureRecognizer({
    required this.duration,
  }) : super(
          duration: duration,
        );
}
