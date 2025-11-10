import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/constants/app_colors.dart';
import '../../services/location_service.dart';

/// Location tracking test screen for debugging
/// Allows manual location sending and automatic foreground updates
class LocationTestScreen extends StatefulWidget {
  const LocationTestScreen({super.key});

  @override
  State<LocationTestScreen> createState() => _LocationTestScreenState();
}

class _LocationTestScreenState extends State<LocationTestScreen> {
  final LocationService _locationService = LocationService();

  bool _isAutoUpdateEnabled = false;
  bool _isSending = false;
  Position? _lastPosition;
  Map<String, dynamic>? _lastResponse;
  String? _lastError;
  DateTime? _lastUpdateTime;

  @override
  void initState() {
    super.initState();
    _checkAutoUpdateStatus();
  }

  @override
  void dispose() {
    // Stop auto-update when leaving screen
    if (_isAutoUpdateEnabled) {
      _locationService.stopForegroundAutoUpdate();
    }
    super.dispose();
  }

  void _checkAutoUpdateStatus() {
    setState(() {
      _isAutoUpdateEnabled = _locationService.isForegroundAutoUpdateEnabled;
    });
  }

  Future<void> _toggleAutoUpdate() async {
    if (_isAutoUpdateEnabled) {
      // Stop auto-update
      _locationService.stopForegroundAutoUpdate();
      setState(() {
        _isAutoUpdateEnabled = false;
      });
      _showSnackbar('自動送信を停止しました', Colors.orange);
    } else {
      // Start auto-update
      await _locationService.startForegroundAutoUpdate();
      setState(() {
        _isAutoUpdateEnabled = true;
      });
      _showSnackbar('自動送信を開始しました（5秒間隔）', Colors.green);
    }
  }

  Future<void> _sendLocationManually() async {
    if (_isSending) return;

    setState(() {
      _isSending = true;
      _lastError = null;
    });

    try {
      final result = await _locationService.sendCurrentLocationManually();

      setState(() {
        if (result['success']) {
          final position = result['position'];
          _lastPosition = Position(
            latitude: position['latitude'],
            longitude: position['longitude'],
            accuracy: position['accuracy'],
            altitude: 0,
            heading: 0,
            speed: 0,
            speedAccuracy: 0,
            timestamp: DateTime.now(),
            altitudeAccuracy: 0,
            headingAccuracy: 0,
          );
          _lastResponse = result['response'];
          _lastUpdateTime = DateTime.parse(result['timestamp']);
          _showSnackbar('位置情報を送信しました', Colors.green);
        } else {
          _lastError = result['error'];
          _showSnackbar('送信に失敗しました', Colors.red);
        }
      });
    } catch (e) {
      setState(() {
        _lastError = e.toString();
      });
      _showSnackbar('エラーが発生しました', Colors.red);
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  void _showSnackbar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('位置情報テスト'),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Status card
              _buildStatusCard(),
              const SizedBox(height: 24),

              // Auto-update toggle
              _buildAutoUpdateCard(),
              const SizedBox(height: 16),

              // Manual send button
              _buildManualSendButton(),
              const SizedBox(height: 24),

              // Last location info
              if (_lastPosition != null) _buildLocationInfo(),
              if (_lastResponse != null) ...[
                const SizedBox(height: 16),
                _buildResponseInfo(),
              ],
              if (_lastError != null) ...[
                const SizedBox(height: 16),
                _buildErrorInfo(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _isAutoUpdateEnabled ? Icons.location_on : Icons.location_off,
                color: _isAutoUpdateEnabled ? Colors.green : Colors.grey,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _isAutoUpdateEnabled ? '自動送信中' : '待機中',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (_isAutoUpdateEnabled) ...[
            const SizedBox(height: 12),
            const Text(
              '5秒ごとに位置情報を自動送信しています',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAutoUpdateCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '自動送信',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '5秒間隔で位置情報を送信',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _isAutoUpdateEnabled,
            onChanged: (value) => _toggleAutoUpdate(),
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildManualSendButton() {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: _isSending ? null : _sendLocationManually,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child: _isSending
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            : const Text(
                '今すぐ送信',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  Widget _buildLocationInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '最新の位置情報',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _buildInfoRow('緯度', _lastPosition!.latitude.toStringAsFixed(6)),
          _buildInfoRow('経度', _lastPosition!.longitude.toStringAsFixed(6)),
          _buildInfoRow('精度', '${_lastPosition!.accuracy.toStringAsFixed(1)}m'),
          if (_lastUpdateTime != null)
            _buildInfoRow(
              '送信時刻',
              '${_lastUpdateTime!.hour.toString().padLeft(2, '0')}:'
                  '${_lastUpdateTime!.minute.toString().padLeft(2, '0')}:'
                  '${_lastUpdateTime!.second.toString().padLeft(2, '0')}',
            ),
        ],
      ),
    );
  }

  Widget _buildResponseInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'APIレスポンス',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _lastResponse.toString(),
            style: const TextStyle(
              fontSize: 12,
              fontFamily: 'monospace',
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red.shade700),
              const SizedBox(width: 8),
              Text(
                'エラー',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.red.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _lastError!,
            style: TextStyle(
              fontSize: 12,
              color: Colors.red.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
