import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmap;
import '../../models/schedule.dart';
import '../../models/favorite_location.dart';
import '../../services/api_service.dart';

/// Schedule creation screen
class CreateScheduleScreen extends StatefulWidget {
  const CreateScheduleScreen({super.key});

  @override
  State<CreateScheduleScreen> createState() => _CreateScheduleScreenState();
}

class _CreateScheduleScreenState extends State<CreateScheduleScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();

  // Form fields
  final TextEditingController _destinationNameController =
      TextEditingController();
  final TextEditingController _destinationAddressController =
      TextEditingController();

  LatLng? _selectedLocation;
  DateTime _startTime = DateTime.now();
  DateTime _endTime = DateTime.now().add(const Duration(hours: 2));
  List<String> _selectedFriendIds = [];
  bool _notifyOnArrival = true;
  bool _notifyOnDeparture = true;
  int _notifyAfterMinutes = 60;
  bool _saveAsFavorite = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _destinationNameController.dispose();
    _destinationAddressController.dispose();
    super.dispose();
  }

  /// Open map selection dialog
  Future<void> _selectLocationOnMap() async {
    final result = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (context) => _MapSelectionScreen(
          initialLocation: _selectedLocation,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _selectedLocation = result;
      });
      // TODO: Reverse geocoding to get address
      _destinationAddressController.text =
          '${result.latitude.toStringAsFixed(6)}, ${result.longitude.toStringAsFixed(6)}';
    }
  }

  /// Open favorite locations selection
  Future<void> _selectFromFavorites() async {
    // TODO: Implement favorite locations selection
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('お気に入り選択機能は実装中です')),
    );
  }

  /// Open friend selection dialog
  Future<void> _selectFriends() async {
    // TODO: Implement friend selection
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('フレンド選択機能は実装中です')),
    );
  }

  /// Select start time
  Future<void> _selectStartTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_startTime),
      );

      if (time != null) {
        setState(() {
          _startTime = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );

          // Ensure end time is after start time
          if (_endTime.isBefore(_startTime)) {
            _endTime = _startTime.add(const Duration(hours: 2));
          }
        });
      }
    }
  }

  /// Select end time
  Future<void> _selectEndTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _endTime,
      firstDate: _startTime,
      lastDate: _startTime.add(const Duration(days: 7)),
    );

    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_endTime),
      );

      if (time != null) {
        setState(() {
          _endTime = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  /// Create schedule
  Future<void> _createSchedule() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('目的地を選択してください')),
      );
      return;
    }

    if (_selectedFriendIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('通知先を選択してください')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // TODO: Get user ID from auth service
      final schedule = LocationSchedule(
        userId: 'current_user_id', // TODO: Replace with actual user ID
        destinationName: _destinationNameController.text.trim(),
        destinationAddress: _destinationAddressController.text.trim(),
        destinationCoords: _selectedLocation!,
        notifyToUserIds: _selectedFriendIds,
        startTime: _startTime,
        endTime: _endTime,
        notifyOnArrival: _notifyOnArrival,
        notifyAfterMinutes: _notifyAfterMinutes,
        notifyOnDeparture: _notifyOnDeparture,
        favorite: _saveAsFavorite,
      );

      // Send to API
      await _apiService.post('/schedules', body: schedule.toJson());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('スケジュールを作成しました')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('スケジュール作成'),
        backgroundColor: Colors.blue,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Destination name
            TextFormField(
              controller: _destinationNameController,
              decoration: const InputDecoration(
                labelText: '目的地の名前',
                hintText: '例: 渋谷駅、自宅',
                prefixIcon: Icon(Icons.place),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '目的地の名前を入力してください';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Destination address
            TextFormField(
              controller: _destinationAddressController,
              decoration: const InputDecoration(
                labelText: '住所',
                hintText: '地図から選択するか、直接入力',
                prefixIcon: Icon(Icons.location_on),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '住所を入力してください';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),

            // Map selection buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _selectLocationOnMap,
                    icon: const Icon(Icons.map),
                    label: const Text('地図から選択'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _selectFromFavorites,
                    icon: const Icon(Icons.star),
                    label: const Text('お気に入り'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Time range
            const Text(
              '時間範囲',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.access_time),
                      title: const Text('開始時刻'),
                      subtitle: Text(_formatDateTime(_startTime)),
                      onTap: _selectStartTime,
                      trailing: const Icon(Icons.edit),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.access_time),
                      title: const Text('終了時刻'),
                      subtitle: Text(_formatDateTime(_endTime)),
                      onTap: _selectEndTime,
                      trailing: const Icon(Icons.edit),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Notification settings
            const Text(
              '通知設定',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('到着時に通知'),
                      subtitle: const Text('目的地に到着したとき'),
                      value: _notifyOnArrival,
                      onChanged: (value) {
                        setState(() {
                          _notifyOnArrival = value;
                        });
                      },
                    ),
                    SwitchListTile(
                      title: const Text('滞在中に通知'),
                      subtitle: Text('到着から${_notifyAfterMinutes}分後'),
                      value: _notifyAfterMinutes > 0,
                      onChanged: (value) {
                        setState(() {
                          _notifyAfterMinutes = value ? 60 : 0;
                        });
                      },
                    ),
                    SwitchListTile(
                      title: const Text('退出時に通知'),
                      subtitle: const Text('目的地から出発したとき'),
                      value: _notifyOnDeparture,
                      onChanged: (value) {
                        setState(() {
                          _notifyOnDeparture = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Friend selection
            const Text(
              '通知先',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.people),
                title: Text(
                  _selectedFriendIds.isEmpty
                      ? 'フレンドを選択'
                      : '${_selectedFriendIds.length}人選択中',
                ),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: _selectFriends,
              ),
            ),
            const SizedBox(height: 24),

            // Save as favorite
            CheckboxListTile(
              title: const Text('お気に入りに保存'),
              subtitle: const Text('次回からすぐに選択できます'),
              value: _saveAsFavorite,
              onChanged: (value) {
                setState(() {
                  _saveAsFavorite = value ?? false;
                });
              },
            ),
            const SizedBox(height: 24),

            // Create button
            ElevatedButton(
              onPressed: _isLoading ? null : _createSchedule,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'スケジュールを作成',
                      style: TextStyle(fontSize: 18),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.month}/${dateTime.day} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

/// Map selection screen
class _MapSelectionScreen extends StatefulWidget {
  final LatLng? initialLocation;

  const _MapSelectionScreen({this.initialLocation});

  @override
  State<_MapSelectionScreen> createState() => _MapSelectionScreenState();
}

class _MapSelectionScreenState extends State<_MapSelectionScreen> {
  gmap.GoogleMapController? _mapController;
  LatLng _selectedLocation = const LatLng(35.6812, 139.7671); // Tokyo default

  @override
  void initState() {
    super.initState();
    if (widget.initialLocation != null) {
      _selectedLocation = widget.initialLocation!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('地図から選択'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context, _selectedLocation);
            },
            child: const Text(
              '完了',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          gmap.GoogleMap(
            initialCameraPosition: gmap.CameraPosition(
              target: gmap.LatLng(
                _selectedLocation.latitude,
                _selectedLocation.longitude,
              ),
              zoom: 15,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
            },
            onTap: (gmap.LatLng position) {
              setState(() {
                _selectedLocation = LatLng(position.latitude, position.longitude);
              });
            },
            markers: {
              gmap.Marker(
                markerId: const gmap.MarkerId('selected'),
                position: gmap.LatLng(
                  _selectedLocation.latitude,
                  _selectedLocation.longitude,
                ),
              ),
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
          ),
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '選択した位置',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_selectedLocation.latitude.toStringAsFixed(6)}, ${_selectedLocation.longitude.toStringAsFixed(6)}',
                      style: const TextStyle(fontFamily: 'Courier'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
