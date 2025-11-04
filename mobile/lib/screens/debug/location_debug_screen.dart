import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import '../../services/location_service.dart';

/// Debug screen for testing location tracking
/// このファイルは実機テスト用です。テスト完了後に削除してください。
class LocationDebugScreen extends StatefulWidget {
  const LocationDebugScreen({super.key});

  @override
  State<LocationDebugScreen> createState() => _LocationDebugScreenState();
}

class _LocationDebugScreenState extends State<LocationDebugScreen> {
  final LocationService _locationService = LocationService();

  LocationPermission? _permission;
  bool _isTracking = false;
  Position? _currentPosition;
  DateTime? _lastUpdateTime;
  int _cachedLocationCount = 0;
  List<String> _logs = [];
  Timer? _updateTimer;

  @override
  void initState() {
    super.initState();
    _initDebugScreen();
    // 5秒ごとに状態を更新
    _updateTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _refreshStatus();
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  Future<void> _initDebugScreen() async {
    await _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    final permission = await _locationService.checkPermission();
    final isTracking = _locationService.isTracking;
    final cachedCount = await _locationService.getCachedLocationCount();
    final currentPos = await _locationService.getCurrentLocation();

    setState(() {
      _permission = permission;
      _isTracking = isTracking;
      _cachedLocationCount = cachedCount;
      _currentPosition = currentPos;
      if (isTracking) {
        _lastUpdateTime = DateTime.now();
      }
    });
  }

  void _addLog(String message) {
    setState(() {
      final timestamp = DateTime.now().toString().substring(11, 19);
      _logs.insert(0, '[$timestamp] $message');
      if (_logs.length > 50) {
        _logs.removeLast();
      }
    });
  }

  Future<void> _startTracking() async {
    _addLog('トラッキング開始を試みています...');
    final success = await _locationService.startTracking();
    if (success) {
      _addLog('✅ トラッキング開始成功');
      await _refreshStatus();
    } else {
      _addLog('❌ トラッキング開始失敗');
    }
  }

  Future<void> _stopTracking() async {
    _addLog('トラッキング停止中...');
    await _locationService.stopTracking();
    _addLog('✅ トラッキング停止');
    await _refreshStatus();
  }

  Future<void> _retryFailedLocations() async {
    _addLog('キャッシュされた位置情報を再送信中...');
    await _locationService.retryFailedLocations();
    _addLog('✅ 再送信完了');
    await _refreshStatus();
  }

  Future<void> _clearCache() async {
    _addLog('キャッシュをクリア中...');
    await _locationService.clearLocationCache();
    _addLog('✅ キャッシュクリア完了');
    await _refreshStatus();
  }

  String _getPermissionString(LocationPermission? permission) {
    switch (permission) {
      case LocationPermission.always:
        return '✅ Always (常に許可)';
      case LocationPermission.whileInUse:
        return '⚠️ While In Use (使用中のみ)';
      case LocationPermission.denied:
        return '❌ Denied (拒否)';
      case LocationPermission.deniedForever:
        return '❌ Denied Forever (永久拒否)';
      default:
        return '不明';
    }
  }

  Color _getPermissionColor(LocationPermission? permission) {
    switch (permission) {
      case LocationPermission.always:
        return Colors.green;
      case LocationPermission.whileInUse:
        return Colors.orange;
      case LocationPermission.denied:
      case LocationPermission.deniedForever:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Location Debug'),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshStatus,
            tooltip: '状態を更新',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshStatus,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Status Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ステータス',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(),
                    _buildStatusRow(
                      '権限',
                      _getPermissionString(_permission),
                      _getPermissionColor(_permission),
                    ),
                    _buildStatusRow(
                      'トラッキング',
                      _isTracking ? '✅ 実行中' : '⭕️ 停止中',
                      _isTracking ? Colors.green : Colors.grey,
                    ),
                    _buildStatusRow(
                      'キャッシュ数',
                      '$_cachedLocationCount 件',
                      _cachedLocationCount > 0 ? Colors.orange : Colors.green,
                    ),
                    if (_lastUpdateTime != null)
                      _buildStatusRow(
                        '最終更新',
                        _formatDateTime(_lastUpdateTime!),
                        Colors.blue,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Current Location Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '現在位置',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(),
                    if (_currentPosition != null) ...[
                      _buildInfoRow(
                        '緯度',
                        _currentPosition!.latitude.toStringAsFixed(6),
                      ),
                      _buildInfoRow(
                        '経度',
                        _currentPosition!.longitude.toStringAsFixed(6),
                      ),
                      _buildInfoRow(
                        '精度',
                        '${_currentPosition!.accuracy.toStringAsFixed(1)}m',
                      ),
                      _buildInfoRow(
                        '高度',
                        '${_currentPosition!.altitude.toStringAsFixed(1)}m',
                      ),
                      _buildInfoRow(
                        '速度',
                        '${_currentPosition!.speed.toStringAsFixed(1)}m/s',
                      ),
                      _buildInfoRow(
                        '取得時刻',
                        _formatDateTime(_currentPosition!.timestamp),
                      ),
                    ] else
                      const Text('位置情報を取得していません'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Control Buttons
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'コントロール',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(),
                    if (!_isTracking)
                      ElevatedButton.icon(
                        onPressed: _startTracking,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('トラッキング開始'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      )
                    else
                      ElevatedButton.icon(
                        onPressed: _stopTracking,
                        icon: const Icon(Icons.stop),
                        label: const Text('トラッキング停止'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _refreshStatus,
                      icon: const Icon(Icons.refresh),
                      label: const Text('現在位置を取得'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _cachedLocationCount > 0
                          ? _retryFailedLocations
                          : null,
                      icon: const Icon(Icons.cloud_upload),
                      label: Text('キャッシュを再送信 ($_cachedLocationCount)'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _cachedLocationCount > 0 ? _clearCache : null,
                      icon: const Icon(Icons.delete),
                      label: const Text('キャッシュをクリア'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Logs Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'ログ',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _logs.clear();
                            });
                          },
                          child: const Text('クリア'),
                        ),
                      ],
                    ),
                    const Divider(),
                    Container(
                      height: 300,
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _logs.isEmpty
                          ? const Center(
                              child: Text(
                                'ログはありません',
                                style: TextStyle(color: Colors.white54),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _logs.length,
                              itemBuilder: (context, index) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  child: Text(
                                    _logs[index],
                                    style: const TextStyle(
                                      color: Colors.greenAccent,
                                      fontFamily: 'Courier',
                                      fontSize: 12,
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Info Card
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'テスト情報',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '• 位置情報は10分間隔で自動更新されます\n'
                      '• バックグラウンドでも動作します\n'
                      '• オフライン時はキャッシュに保存されます\n'
                      '• オンライン復帰時に自動で再送信されます\n\n'
                      '⚠️ このデバッグ画面はテスト完了後に削除してください',
                      style: TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontFamily: 'Courier'),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}:'
        '${dateTime.second.toString().padLeft(2, '0')}';
  }
}
