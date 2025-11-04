import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/location_service.dart';

/// Location permission request screen
/// Guides users through the process of granting "Always Allow" permission
class LocationPermissionScreen extends StatefulWidget {
  final VoidCallback? onPermissionGranted;

  const LocationPermissionScreen({
    super.key,
    this.onPermissionGranted,
  });

  @override
  State<LocationPermissionScreen> createState() =>
      _LocationPermissionScreenState();
}

class _LocationPermissionScreenState extends State<LocationPermissionScreen> {
  final LocationService _locationService = LocationService();

  LocationPermission? _currentPermission;
  bool _isLoading = false;
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    _checkCurrentPermission();
  }

  /// Check current permission status
  Future<void> _checkCurrentPermission() async {
    final permission = await _locationService.checkPermission();
    setState(() {
      _currentPermission = permission;
      _statusMessage = _getPermissionStatusMessage(permission);
    });
  }

  /// Get human-readable permission status message
  String _getPermissionStatusMessage(LocationPermission permission) {
    switch (permission) {
      case LocationPermission.always:
        return '位置情報の権限が正しく設定されています';
      case LocationPermission.whileInUse:
        return '「常に許可」への変更をお願いします';
      case LocationPermission.denied:
        return '位置情報の権限が必要です';
      case LocationPermission.deniedForever:
        return '設定アプリから権限を有効にしてください';
      default:
        return '';
    }
  }

  /// Request location permission
  Future<void> _requestPermission() async {
    setState(() {
      _isLoading = true;
      _statusMessage = '権限を確認中...';
    });

    try {
      final granted = await _locationService.requestPermission();

      if (granted) {
        // Check if we have "Always" permission
        final hasAlways = await _locationService.hasAlwaysPermission();

        if (hasAlways) {
          setState(() {
            _statusMessage = '権限が正常に設定されました';
          });

          // Notify parent widget
          widget.onPermissionGranted?.call();

          // Navigate back or to next screen
          if (mounted) {
            Navigator.of(context).pop(true);
          }
        } else {
          // Show instruction to enable "Always Allow"
          setState(() {
            _statusMessage = '「常に許可」への変更をお願いします';
          });
          await _checkCurrentPermission();
          _showAlwaysAllowInstruction();
        }
      } else {
        setState(() {
          _statusMessage = '位置情報の権限が拒否されました';
        });
        await _checkCurrentPermission();
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'エラーが発生しました: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Show instruction dialog for enabling "Always Allow"
  void _showAlwaysAllowInstruction() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('「常に許可」への変更をお願いします'),
        content: const Text(
          'imaneをバックグラウンドでも動作させるために、'
          '「常に許可」への変更が必要です。\n\n'
          '設定方法:\n'
          '1. 「設定を開く」をタップ\n'
          '2. 「位置情報」を選択\n'
          '3. 「常に」を選択',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('後で'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _openAppSettings();
            },
            child: const Text('設定を開く'),
          ),
        ],
      ),
    );
  }

  /// Open app settings
  Future<void> _openAppSettings() async {
    await openAppSettings();

    // Check permission again after returning from settings
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        _checkCurrentPermission();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('位置情報の許可'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Icon
              const Icon(
                Icons.location_on,
                size: 80,
                color: Colors.blue,
              ),
              const SizedBox(height: 24),

              // Title
              const Text(
                '位置情報の許可が必要です',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Description
              const Text(
                'imaneは、あなたが目的地に到着したとき、'
                'バックグラウンドで自動的に大切な人に通知を送ります。\n\n'
                'そのため、アプリを開いていないときも位置情報を取得できるように、'
                '「常に許可」の設定をお願いします。',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Privacy note
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.privacy_tip, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          'プライバシーについて',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      '• 位置情報は10分間隔で取得されます\n'
                      '• すべてのデータは24時間後に自動削除されます\n'
                      '• スケジュールを設定したときのみ追跡します',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Status message
              if (_statusMessage.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _getStatusColor(),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _statusMessage,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 16),

              const Spacer(),

              // Request permission button
              if (_currentPermission != LocationPermission.always)
                ElevatedButton(
                  onPressed: _isLoading ? null : _requestPermission,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        )
                      : const Text(
                          '位置情報の許可を設定',
                          style: TextStyle(fontSize: 18),
                        ),
                ),

              // Open settings button (for denied forever)
              if (_currentPermission == LocationPermission.deniedForever)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: OutlinedButton(
                    onPressed: _openAppSettings,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      '設定アプリを開く',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                ),

              // Continue button (if already granted)
              if (_currentPermission == LocationPermission.always)
                ElevatedButton(
                  onPressed: () {
                    widget.onPermissionGranted?.call();
                    Navigator.of(context).pop(true);
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text(
                    '続ける',
                    style: TextStyle(fontSize: 18),
                  ),
                ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  /// Get color based on permission status
  Color _getStatusColor() {
    switch (_currentPermission) {
      case LocationPermission.always:
        return Colors.green;
      case LocationPermission.whileInUse:
        return Colors.orange;
      case LocationPermission.denied:
        return Colors.red;
      case LocationPermission.deniedForever:
        return Colors.red.shade900;
      default:
        return Colors.grey;
    }
  }
}
