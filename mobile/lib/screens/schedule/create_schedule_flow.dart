import 'package:flutter/material.dart';
import '../../models/schedule.dart' show LocationSchedule, LatLng;
import '../../services/api_service.dart';
import '../../services/location_service.dart';
import 'steps/step1_datetime_screen.dart';
import 'steps/step2_location_screen.dart';
import 'steps/step3_recipients_screen.dart';
import 'steps/step4_confirm_screen.dart';

/// Create schedule flow - manages all 4 steps
/// Can be used for both creating new schedules and editing existing ones
class CreateScheduleFlow extends StatefulWidget {
  final LocationSchedule? existingSchedule;

  const CreateScheduleFlow({
    super.key,
    this.existingSchedule,
  });

  @override
  State<CreateScheduleFlow> createState() => _CreateScheduleFlowState();
}

class _CreateScheduleFlowState extends State<CreateScheduleFlow> {
  final ApiService _apiService = ApiService();

  // Data collected from each step
  DateTime? _selectedDateTime;
  LocationData? _selectedLocation;
  List<String>? _selectedRecipientIds;

  bool _isCreating = false;
  bool get _isEditMode => widget.existingSchedule != null;

  @override
  void initState() {
    super.initState();
    // Initialize with existing data if editing
    if (widget.existingSchedule != null) {
      final schedule = widget.existingSchedule!;
      _selectedDateTime = schedule.startTime;
      _selectedLocation = LocationData(
        name: schedule.destinationName,
        address: schedule.destinationAddress,
        latitude: schedule.destinationCoords.latitude,
        longitude: schedule.destinationCoords.longitude,
      );
      _selectedRecipientIds = List.from(schedule.notifyToUserIds);
    }
  }

  void _navigateToStep2() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Step2LocationScreen(
          initialLocation: _selectedLocation,
          isEditMode: _isEditMode,
          onNext: (location) {
            setState(() {
              _selectedLocation = location;
            });
            _navigateToStep3();
          },
        ),
      ),
    );
  }

  void _navigateToStep3() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Step3RecipientsScreen(
          initialRecipients: _selectedRecipientIds,
          isEditMode: _isEditMode,
          onNext: (recipientIds) {
            setState(() {
              _selectedRecipientIds = recipientIds;
            });
            _navigateToStep4();
          },
        ),
      ),
    );
  }

  Future<void> _navigateToStep4() async {
    // Fetch friend names from API
    List<String> recipientNames = [];
    try {
      final response = await _apiService.get('/friends');

      List<dynamic> friendsJson;
      if (response is Map && response['friends'] != null) {
        friendsJson = response['friends'];
      } else if (response is List) {
        friendsJson = response;
      } else {
        friendsJson = [];
      }

      // Create a map of friend_id -> friend_display_name
      final friendMap = <String, String>{};
      for (final friendData in friendsJson) {
        final friendId = friendData['friend_id'] as String?;
        final friendName = friendData['friend_display_name'] as String? ??
                          friendData['friend_email'] as String? ??
                          'Unknown';
        if (friendId != null) {
          friendMap[friendId] = friendName;
        }
      }

      // Map selected IDs to names
      recipientNames = _selectedRecipientIds!.map((id) {
        return friendMap[id] ?? 'Unknown';
      }).toList();

    } catch (e) {
      print('[CreateSchedule] Error fetching friend names: $e');
      // Fallback to Unknown if API fails
      recipientNames = _selectedRecipientIds!.map((id) => 'Unknown').toList();
    }

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Step4ConfirmScreen(
          dateTime: _selectedDateTime!,
          location: _selectedLocation!,
          recipientIds: _selectedRecipientIds!,
          recipientNames: recipientNames,
          onConfirm: _createSchedule,
          isLoading: _isCreating,
          isEditMode: _isEditMode,
        ),
      ),
    );
  }

  Future<void> _createSchedule() async {
    if (_isCreating) return;

    setState(() {
      _isCreating = true;
    });

    try {
      final action = _isEditMode ? 'update' : 'creation';
      print('[CreateSchedule] Starting schedule $action...');
      print('[CreateSchedule] DateTime: $_selectedDateTime');
      print('[CreateSchedule] Location: ${_selectedLocation!.name}');
      print('[CreateSchedule] Recipients: $_selectedRecipientIds');

      // Create schedule object (backend will use current user from auth token)
      final scheduleData = {
        'destination_name': _selectedLocation!.name,
        'destination_address': _selectedLocation!.address,
        'destination_coords': {
          'lat': _selectedLocation!.latitude ?? 35.6812,
          'lng': _selectedLocation!.longitude ?? 139.7671,
        },
        'notify_to_user_ids': _selectedRecipientIds!,
        'start_time': _selectedDateTime!.toIso8601String(),
        'end_time': _selectedDateTime!.add(const Duration(hours: 2)).toIso8601String(),
        'notify_on_arrival': true,
        'notify_after_minutes': 60,
        'notify_on_departure': true,
        'favorite': false,
      };

      print('[CreateSchedule] Sending data: $scheduleData');

      // Send to API - use PUT for edit, POST for create
      final response = _isEditMode
          ? await _apiService.put('/schedules/${widget.existingSchedule!.id}', body: scheduleData)
          : await _apiService.post('/schedules', body: scheduleData);

      print('[CreateSchedule] SUCCESS! Response: $response');
      print('[CreateSchedule] Response type: ${response.runtimeType}');

      if (!mounted) return;

      // Start location tracking after schedule creation
      try {
        final locationService = LocationService();
        final hasPermission = await locationService.hasAlwaysPermission();

        if (hasPermission) {
          print('[CreateSchedule] Starting location tracking...');
          final trackingStarted = await locationService.startTracking();
          if (trackingStarted) {
            print('[CreateSchedule] Location tracking started successfully');
          } else {
            print('[CreateSchedule] Failed to start location tracking');
          }
        } else {
          print('[CreateSchedule] Location permission not granted - tracking not started');
          // Show permission reminder
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('位置情報の「常に許可」を有効にすると、自動的に到着通知が送信されます'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }
      } catch (e) {
        print('[CreateSchedule] Error starting location tracking: $e');
        // Continue even if tracking fails
      }

      if (!mounted) return;

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditMode ? '予定を更新しました' : '予定を作成しました'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );

      // Wait a moment for the backend to process
      await Future.delayed(const Duration(milliseconds: 500));

      // Return to schedule list screen - pop all screens in the flow
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e, stackTrace) {
      print('[CreateSchedule] ERROR: $e');
      print('[CreateSchedule] Error type: ${e.runtimeType}');
      print('[CreateSchedule] Stack trace: $stackTrace');

      if (!mounted) return;

      // Error message is logged to console for debugging
      // Snackbar display is commented out to avoid UI disruption during development
      // String errorMessage = 'エラー: $e';
      // if (e.toString().contains('SocketException')) {
      //   errorMessage = 'バックエンドサーバーに接続できません。サーバーが起動しているか確認してください。';
      // }

      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(
      //     content: Text(errorMessage),
      //     backgroundColor: Colors.red,
      //     duration: const Duration(seconds: 4),
      //   ),
      // );
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Step 1 is the entry point
    return Step1DateTimeScreen(
      initialDateTime: _selectedDateTime,
      isEditMode: _isEditMode,
      onNext: (dateTime) {
        setState(() {
          _selectedDateTime = dateTime;
        });
        _navigateToStep2();
      },
    );
  }
}
