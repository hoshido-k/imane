import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

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
  List<Map<String, String>> _searchResults = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialLocation != null) {
      _selectedLocation = widget.initialLocation;
      // Pre-fill manual input fields with existing data
      _streetController.text = widget.initialLocation!.address;
      // Optionally set building name as the location name
      if (widget.initialLocation!.name.isNotEmpty) {
        _buildingController.text = widget.initialLocation!.name;
      }
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
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    // Filter stations by search query
    final allStations = [
      {'name': '東京駅', 'address': '東京都千代田区丸の内1丁目'},
      {'name': '渋谷駅', 'address': '東京都渋谷区道玄坂1丁目'},
      {'name': '新宿駅', 'address': '東京都新宿区新宿3丁目'},
      {'name': '池袋駅', 'address': '東京都豊島区南池袋1丁目'},
      {'name': '品川駅', 'address': '東京都港区高輪3丁目'},
      {'name': '上野駅', 'address': '東京都台東区上野7丁目'},
      {'name': '秋葉原駅', 'address': '東京都千代田区外神田1丁目'},
      {'name': '六本木駅', 'address': '東京都港区六本木6丁目'},
      {'name': '表参道駅', 'address': '東京都港区北青山3丁目'},
      {'name': '銀座駅', 'address': '東京都中央区銀座4丁目'},
    ];

    setState(() {
      _searchResults = allStations
          .where((station) =>
              station['name']!.contains(query) ||
              station['address']!.contains(query))
          .toList();
    });
  }

  @override
  void dispose() {
    _postalCodeController.dispose();
    _prefectureController.dispose();
    _cityController.dispose();
    _streetController.dispose();
    _buildingController.dispose();
    _searchController.dispose();
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
    return _prefectureController.text.trim().isNotEmpty &&
        _cityController.text.trim().isNotEmpty &&
        _streetController.text.trim().isNotEmpty;
  }

  void _onManualSubmit() {
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
    _onNextPressed();
  }

  void _onMapLocationConfirm() {
    if (_tempSelectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('場所を選択してください'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    setState(() {
      _selectedLocation = _tempSelectedLocation;
    });
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
                        ? '${_selectedLocation!.name}\n${_selectedLocation!.address}'
                        : '---',
                    style: TextStyle(
                      fontSize: _selectedLocation != null ? 16 : 18,
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
                        child: OutlinedButton.icon(
                          onPressed: () {
                            // TODO: Use current location
                          },
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: AppColors.textSecondary),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(22),
                            ),
                          ),
                          icon: Icon(
                            Icons.my_location,
                            color: AppColors.textPrimary,
                            size: 20,
                          ),
                          label: Text(
                            '現在地を使用',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Map placeholder
                Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8DCC8),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 48,
                            color: AppColors.primary,
                          ),
                          const SizedBox(height: 8),
                          if (_tempSelectedLocation != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppColors.primary,
                                  width: 2,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    _tempSelectedLocation!.name,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    _tempSelectedLocation!.address,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            Text(
                              '場所を選択してください',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                        ],
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
              onPressed: _tempSelectedLocation != null ? _onMapLocationConfirm : null,
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
    // Only show results if search query is not empty
    if (_searchResults.isEmpty) {
      return [];
    }

    return _searchResults.map((station) {
      final isSelected = _tempSelectedLocation?.name == station['name'];

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
            station['name']!,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
          subtitle: Text(
            station['address']!,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          onTap: () {
            setState(() {
              _tempSelectedLocation = LocationData(
                name: station['name']!,
                address: station['address']!,
              );
              _selectedLocation = _tempSelectedLocation;
            });
          },
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
