import 'dart:async';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/services/location_service.dart';

/// スケジュール監視サービス
///
/// アクティブなスケジュールを監視し、start_time到達時に位置情報追跡を開始します。
/// また、全スケジュールがCOMPLETED/EXPIREDになったら追跡を停止します。
class ScheduleMonitorService {
  static final ScheduleMonitorService _instance = ScheduleMonitorService._internal();
  factory ScheduleMonitorService() => _instance;
  ScheduleMonitorService._internal();

  final ApiService _apiService = ApiService();
  final LocationService _locationService = LocationService();

  Timer? _monitorTimer;
  bool _isTracking = false;

  /// 監視を開始（1分ごとにチェック）
  void startMonitoring() {
    final timestamp = DateTime.now().toIso8601String();
    print('[$timestamp] [ScheduleMonitor] 監視開始');

    // 即座に1回チェック
    _checkSchedules();

    // 1分ごとにチェック
    _monitorTimer?.cancel();
    _monitorTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _checkSchedules();
    });
  }

  /// 監視を停止
  void stopMonitoring() {
    final timestamp = DateTime.now().toIso8601String();
    print('[$timestamp] [ScheduleMonitor] 監視停止');

    _monitorTimer?.cancel();
    _monitorTimer = null;
  }

  /// アクティブなスケジュールをチェック
  Future<void> _checkSchedules() async {
    try {
      final timestamp = DateTime.now().toIso8601String();
      print('[$timestamp] [ScheduleMonitor] スケジュールチェック開始');

      // 自分のスケジュールを取得
      final response = await _apiService.get('/schedules');
      final schedules = response['schedules'] as List<dynamic>;

      print('[$timestamp] [ScheduleMonitor] スケジュール数: ${schedules.length}');

      if (schedules.isEmpty) {
        // スケジュールがない場合は追跡停止
        if (_isTracking) {
          print('[$timestamp] [ScheduleMonitor] スケジュールなし → 追跡停止');
          await _stopTracking();
        }
        return;
      }

      final now = DateTime.now();
      bool hasActiveOrArrived = false;
      bool shouldStartTracking = false;

      for (var schedule in schedules) {
        final status = schedule['status'] as String;
        final startTimeStr = schedule['start_time'] as String;
        final startTime = DateTime.parse(startTimeStr);

        print('[$timestamp] [ScheduleMonitor] スケジュール: ${schedule['id']}');
        print('  - status: $status');
        print('  - start_time: $startTime');
        print('  - 現在時刻: $now');

        // ACTIVEまたはARRIVEDのスケジュールがあるかチェック
        if (status == 'active' || status == 'arrived') {
          hasActiveOrArrived = true;

          // start_timeが到達しているかチェック
          if (now.isAfter(startTime) || now.isAtSameMomentAs(startTime)) {
            shouldStartTracking = true;
            print('[$timestamp] [ScheduleMonitor] start_time到達 → 追跡開始が必要');
          } else {
            final remainingMinutes = startTime.difference(now).inMinutes;
            print('[$timestamp] [ScheduleMonitor] start_timeまで残り${remainingMinutes}分');
          }
        }
      }

      // 追跡の開始/停止を判断
      if (hasActiveOrArrived && shouldStartTracking) {
        if (!_isTracking) {
          print('[$timestamp] [ScheduleMonitor] 位置情報追跡を開始します');
          await _startTracking();
        } else {
          print('[$timestamp] [ScheduleMonitor] 既に追跡中');
        }
      } else if (!hasActiveOrArrived) {
        if (_isTracking) {
          print('[$timestamp] [ScheduleMonitor] アクティブな予定なし → 追跡停止');
          await _stopTracking();
        }
      }
    } catch (e) {
      final timestamp = DateTime.now().toIso8601String();
      print('[$timestamp] [ScheduleMonitor] エラー: $e');
    }
  }

  /// 位置情報追跡を開始
  Future<void> _startTracking() async {
    try {
      final timestamp = DateTime.now().toIso8601String();
      print('[$timestamp] [ScheduleMonitor] === 位置情報追跡開始 ===');

      // フォアグラウンド自動更新を開始
      await _locationService.startForegroundAutoUpdate();
      print('[$timestamp] [ScheduleMonitor] ✓ フォアグラウンド自動更新開始');

      // バックグラウンド追跡を開始（権限がある場合）
      final hasPermission = await _locationService.hasAlwaysPermission();
      if (hasPermission) {
        final trackingStarted = await _locationService.startTracking();
        if (trackingStarted) {
          print('[$timestamp] [ScheduleMonitor] ✓ バックグラウンド追跡開始');
        }
      } else {
        print('[$timestamp] [ScheduleMonitor] バックグラウンド権限なし');
      }

      _isTracking = true;
    } catch (e) {
      final timestamp = DateTime.now().toIso8601String();
      print('[$timestamp] [ScheduleMonitor] 追跡開始エラー: $e');
    }
  }

  /// 位置情報追跡を停止
  Future<void> _stopTracking() async {
    try {
      final timestamp = DateTime.now().toIso8601String();
      print('[$timestamp] [ScheduleMonitor] === 位置情報追跡停止 ===');

      // フォアグラウンド自動更新を停止
      _locationService.stopForegroundAutoUpdate();
      print('[$timestamp] [ScheduleMonitor] ✓ フォアグラウンド自動更新停止');

      // バックグラウンド追跡を停止
      await _locationService.stopTracking();
      print('[$timestamp] [ScheduleMonitor] ✓ バックグラウンド追跡停止');

      _isTracking = false;
    } catch (e) {
      final timestamp = DateTime.now().toIso8601String();
      print('[$timestamp] [ScheduleMonitor] 追跡停止エラー: $e');
    }
  }
}
