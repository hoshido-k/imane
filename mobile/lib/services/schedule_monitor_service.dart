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
    print('[$timestamp] [ScheduleMonitor] ========================================');
    print('[$timestamp] [ScheduleMonitor] 監視開始');
    print('[$timestamp] [ScheduleMonitor] ========================================');

    // 既存のタイマーをキャンセル
    if (_monitorTimer != null) {
      print('[$timestamp] [ScheduleMonitor] 既存のタイマーをキャンセル');
      _monitorTimer?.cancel();
    }

    // 即座に1回チェック
    print('[$timestamp] [ScheduleMonitor] 初回チェックを実行');
    _checkSchedules();

    // 1分ごとにチェック
    _monitorTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      final t = DateTime.now().toIso8601String();
      print('[$t] [ScheduleMonitor] ⏰ タイマー実行（1分経過）');
      _checkSchedules();
    });

    print('[$timestamp] [ScheduleMonitor] タイマー設定完了（1分間隔）');
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
    final timestamp = DateTime.now().toIso8601String();
    print('[$timestamp] [ScheduleMonitor] === スケジュールチェック開始 ===');

    try {
      // 自分のスケジュールを取得
      final response = await _apiService.get('/schedules');
      print('[$timestamp] [ScheduleMonitor] API応答: $response');

      final schedules = response['schedules'] as List<dynamic>;
      print('[$timestamp] [ScheduleMonitor] スケジュール数: ${schedules.length}');

      if (schedules.isEmpty) {
        // スケジュールがない場合は追跡停止
        print('[$timestamp] [ScheduleMonitor] スケジュールなし');
        if (_isTracking) {
          print('[$timestamp] [ScheduleMonitor] 追跡中なので停止します');
          await _stopTracking();
        }
        return;
      }

      // UTC時刻で比較（タイムゾーンの問題を回避）
      final nowUtc = DateTime.now().toUtc();
      print('[$timestamp] [ScheduleMonitor] 現在時刻 (UTC): $nowUtc');

      bool hasActiveOrArrived = false;
      bool shouldStartTracking = false;

      for (var schedule in schedules) {
        final status = schedule['status'] as String;
        final startTimeStr = schedule['start_time'] as String;
        final startTimeUtc = DateTime.parse(startTimeStr); // UTCのまま
        final startTimeLocal = startTimeUtc.toLocal(); // ローカル時刻（表示用）

        print('[$timestamp] [ScheduleMonitor] --- スケジュール ---');
        print('  ID: ${schedule['id']}');
        print('  status: $status');
        print('  start_time (UTC): $startTimeUtc');
        print('  start_time (JST表示): $startTimeLocal');

        // ACTIVEまたはARRIVEDのスケジュールがあるかチェック
        if (status == 'active' || status == 'arrived') {
          hasActiveOrArrived = true;
          print('  → ACTIVE/ARRIVED状態を検出');

          // start_timeが到達しているかチェック（UTC同士で比較）
          if (nowUtc.isAfter(startTimeUtc) || nowUtc.isAtSameMomentAs(startTimeUtc)) {
            shouldStartTracking = true;
            print('  → ✅ start_time到達！追跡開始が必要');
          } else {
            final remainingMinutes = startTimeUtc.difference(nowUtc).inMinutes;
            print('  → ⏰ start_timeまで残り${remainingMinutes}分');
          }
        } else {
          print('  → status=${status}のため対象外');
        }
      }

      print('[$timestamp] [ScheduleMonitor] チェック結果:');
      print('  - hasActiveOrArrived: $hasActiveOrArrived');
      print('  - shouldStartTracking: $shouldStartTracking');
      print('  - _isTracking: $_isTracking');

      // 追跡の開始/停止を判断
      if (hasActiveOrArrived && shouldStartTracking) {
        if (!_isTracking) {
          print('[$timestamp] [ScheduleMonitor] 🚀 位置情報追跡を開始します');
          await _startTracking();
        } else {
          print('[$timestamp] [ScheduleMonitor] ℹ️ 既に追跡中');
        }
      } else if (!hasActiveOrArrived) {
        if (_isTracking) {
          print('[$timestamp] [ScheduleMonitor] 🛑 アクティブな予定なし → 追跡停止');
          await _stopTracking();
        } else {
          print('[$timestamp] [ScheduleMonitor] ℹ️ アクティブな予定なし、追跡もなし');
        }
      } else {
        print('[$timestamp] [ScheduleMonitor] ℹ️ start_time未到達、待機中');
      }
    } catch (e, stackTrace) {
      print('[$timestamp] [ScheduleMonitor] ❌ エラー発生: $e');
      print('[$timestamp] [ScheduleMonitor] スタックトレース: $stackTrace');
    }

    print('[$timestamp] [ScheduleMonitor] === スケジュールチェック完了 ===');
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
