import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../widgets/map/interactive_map_picker.dart';
import '../../../services/places_service.dart';
import 'dart:async';

/// Location data model
class LocationData {
  final String name;
  final String address;
  final double? latitude;
  final double? longitude;

  LocationData({
    required this.name,
    required this.address,
    this.latitude,
    this.longitude,
  });
}

/// Step 2: Location selection screen
class Step2LocationScreen extends StatefulWidget {
  final LocationData? initialLocation;
  final Function(LocationData) onNext;
  final bool isEditMode;

  const Step2LocationScreen({
    super.key,
    this.initialLocation,
    required this.onNext,
    this.isEditMode = false,
  });

  @override
  State<Step2LocationScreen> createState() => _Step2LocationScreenState();
}

class _Step2LocationScreenState extends State<Step2LocationScreen> {
  int _currentTabIndex = 0;
  LocationData? _selectedLocation;
  LocationData? _tempSelectedLocation; // Temporary selection for map search

  // Manual input controllers
  final TextEditingController _postalCodeController = TextEditingController();
  final TextEditingController _prefectureController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _streetController = TextEditingController();
  final TextEditingController _buildingController = TextEditingController();

  // Map search controller
  final TextEditingController _searchController = TextEditingController();
  List<PlacePrediction> _searchResults = [];
  final PlacesService _placesService = PlacesService();
  Timer? _debounceTimer;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialLocation != null) {
      _selectedLocation = widget.initialLocation;
      // Don't pre-fill manual input fields - user can see selected location in prompt card
      // If they want to change it, they can manually input new data
    }
    // Listen to search input changes
    _searchController.addListener(_onSearchTextChanged);

    // Listen to manual input changes for button state
    _prefectureController.addListener(_updateState);
    _cityController.addListener(_updateState);
    _streetController.addListener(_updateState);
  }

  void _updateState() {
    setState(() {});
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

    // Debounce search by 500ms to avoid too many API calls
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
          _searchResults = [];
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _onSearchResultTapped(PlacePrediction prediction) async {
    // Clear search
    setState(() {
      _searchController.clear();
      _searchResults = [];
    });

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    // Get place details (coordinates)
    final placeDetails = await _placesService.getPlaceDetails(prediction.placeId);

    if (!mounted) return;
    Navigator.pop(context); // Close loading dialog

    if (placeDetails != null) {
      setState(() {
        _tempSelectedLocation = LocationData(
          name: placeDetails.name,
          address: placeDetails.formattedAddress,
          latitude: placeDetails.latitude,
          longitude: placeDetails.longitude,
        );
        _selectedLocation = _tempSelectedLocation;
      });
    }
  }

  @override
  void dispose() {
    _postalCodeController.dispose();
    _prefectureController.dispose();
    _cityController.dispose();
    _streetController.dispose();
    _buildingController.dispose();
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onNextPressed() {
    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('目的地を選択してください'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    widget.onNext(_selectedLocation!);
  }

  bool _isManualInputValid() {
    // If location is already selected (e.g., edit mode), button should be enabled
    if (_selectedLocation != null) return true;

    // Otherwise, check if manual input fields are filled
    return _prefectureController.text.trim().isNotEmpty &&
        _cityController.text.trim().isNotEmpty &&
        _streetController.text.trim().isNotEmpty;
  }

  void _onManualSubmit() {
    // If user has filled in manual input fields, create new LocationData
    if (_prefectureController.text.trim().isNotEmpty ||
        _cityController.text.trim().isNotEmpty ||
        _streetController.text.trim().isNotEmpty) {
      final address =
          '${_prefectureController.text} ${_cityController.text} ${_streetController.text} ${_buildingController.text}';
      setState(() {
        _selectedLocation = LocationData(
          name: _buildingController.text.isNotEmpty
              ? _buildingController.text
              : _cityController.text,
          address: address.trim(),
        );
      });
    }
    // If no manual input but existing location exists (edit mode), use existing
    // This is handled by _onNextPressed which checks _selectedLocation
    _onNextPressed();
  }

  void _onMapLocationConfirm() {
    // If user selected a new location from map, use it
    if (_tempSelectedLocation != null) {
      setState(() {
        _selectedLocation = _tempSelectedLocation;
      });
    }
    // If no new selection but existing location exists (edit mode), use existing
    else if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('場所を選択してください'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    // Proceed to next step with the selected location
    widget.onNext(_selectedLocation!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildPromptCard(),
                    _buildTabBar(),
                    _currentTabIndex == 0
                        ? _buildManualInputContent()
                        : _buildMapSearchContent(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isEditMode ? '目的地を編集' : '目的地を設定',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'ステップ 2 / 4',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Progress indicator
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.inputBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.inputBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPromptCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.location_on,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '目的地を選択してください',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.inputBackground,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '選択中の目的地',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _selectedLocation != null
                        ? _selectedLocation!.address
                        : '---',
                    style: TextStyle(
                      fontSize: _selectedLocation != null ? 14 : 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
        ),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _currentTabIndex = 0;
                  });
                },
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: _currentTabIndex == 0
                        ? AppColors.primary
                        : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '手動入力',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: _currentTabIndex == 0
                          ? Colors.white
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _currentTabIndex = 1;
                  });
                },
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: _currentTabIndex == 1
                        ? AppColors.primary
                        : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'マップ検索',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: _currentTabIndex == 1
                          ? Colors.white
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManualInputContent() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInputLabel('郵便番号'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _postalCodeController,
              hintText: '1000001',
              keyboardType: TextInputType.number,
              suffixIcon: IconButton(
                icon: Icon(Icons.search, color: AppColors.primary),
                onPressed: () {
                  // TODO: Search address by postal code
                },
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'ハイフンなしで入力',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            _buildInputLabel('都道府県'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _prefectureController,
              hintText: '東京都',
            ),
            const SizedBox(height: 20),
            _buildInputLabel('市区町村'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _cityController,
              hintText: '渋谷区',
            ),
            const SizedBox(height: 20),
            _buildInputLabel('町名・番地'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _streetController,
              hintText: '渋谷1-2-3',
            ),
            const SizedBox(height: 20),
            _buildInputLabel('建物名・部屋番号（任意）'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _buildingController,
              hintText: '渋谷ビル 101号室',
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isManualInputValid() ? _onManualSubmit : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.inputBorder,
                  disabledForegroundColor: AppColors.textSecondary,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: const Text(
                  'この住所を設定する',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapSearchContent() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Search box
              Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.search, color: AppColors.textSecondary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '場所を検索',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  'Search location',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: '場所や住所を検索',
                          hintStyle: TextStyle(
                            color: AppColors.textPlaceholder,
                            fontSize: 14,
                          ),
                          filled: true,
                          fillColor: AppColors.inputBackground,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(Icons.search, color: AppColors.primary),
                            onPressed: () {
                              // TODO: Perform search
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => InteractiveMapPicker(
                                  initialLocation: _selectedLocation,
                                  onLocationSelected: (location) {
                                    setState(() {
                                      _tempSelectedLocation = location;
                                      _selectedLocation = location;
                                    });
                                  },
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(22),
                            ),
                          ),
                          icon: const Icon(
                            Icons.map,
                            size: 20,
                          ),
                          label: const Text(
                            'マップから選択',
                            style: TextStyle(
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              // Station list
              ..._buildStationList(),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Confirm button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: (_tempSelectedLocation != null || _selectedLocation != null)
                  ? _onMapLocationConfirm
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.inputBorder,
                disabledForegroundColor: AppColors.textSecondary,
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              child: const Text(
                'この場所を設定する',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildStationList() {
    // Show loading indicator
    if (_isSearching) {
      return [
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        ),
      ];
    }

    // Only show results if search query is not empty
    if (_searchResults.isEmpty) {
      return [];
    }

    return _searchResults.map((prediction) {
      final isSelected = _tempSelectedLocation?.name == prediction.mainText;

      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withOpacity(0.2)
                  : AppColors.inputBackground,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.location_on,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
              size: 20,
            ),
          ),
          title: Text(
            prediction.mainText,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: AppColors.textPrimary,
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
        ),
      );
    }).toList();
  }

  Widget _buildInputLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    TextInputType? keyboardType,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          color: AppColors.textPlaceholder,
          fontSize: 14,
        ),
        filled: true,
        fillColor: AppColors.inputBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        suffixIcon: suffixIcon,
      ),
    );
  }
}
