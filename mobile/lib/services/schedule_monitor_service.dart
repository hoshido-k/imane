import 'dart:async';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/services/location_service.dart';
import '../core/config/location_config.dart';

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

  /// 監視を開始（設定された間隔でチェック）
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

    // 設定された間隔でチェック
    _monitorTimer = Timer.periodic(
      Duration(minutes: LocationConfig.scheduleMonitorIntervalMinutes),
      (timer) {
        final t = DateTime.now().toIso8601String();
        print('[$t] [ScheduleMonitor] ⏰ タイマー実行（${LocationConfig.scheduleMonitorIntervalMinutes}分経過）');
        _checkSchedules();
      },
    );

    print('[$timestamp] [ScheduleMonitor] タイマー設定完了（${LocationConfig.scheduleMonitorIntervalMinutes}分間隔）');
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

      // 現在時刻（JST）
      final now = DateTime.now();
      print('[$timestamp] [ScheduleMonitor] 現在時刻 (JST): $now');

      bool hasActiveOrArrived = false;
      bool shouldStartTracking = false;

      for (var schedule in schedules) {
        final status = schedule['status'] as String;
        final startTimeStr = schedule['start_time'] as String;

        // APIレスポンスのJST時刻をパース
        // バックエンドは+09:00付きのISO 8601形式で返すため、DateTime.parseで正しく解釈される
        // その後toLocal()でデバイスのローカル時刻に変換して比較
        final startTime = DateTime.parse(startTimeStr).toLocal();

        print('[$timestamp] [ScheduleMonitor] --- スケジュール ---');
        print('  ID: ${schedule['id']}');
        print('  status: $status');
        print('  start_time: $startTime');
        print('  start_time (raw): $startTimeStr');

        // ACTIVEまたはARRIVEDのスケジュールがあるかチェック
        if (status == 'active' || status == 'arrived') {
          hasActiveOrArrived = true;
          print('  → ACTIVE/ARRIVED状態を検出');

          // start_timeが到達しているかチェック
          if (now.isAfter(startTime) || now.isAtSameMomentAs(startTime)) {
            shouldStartTracking = true;
            print('  → ✅ start_time到達！追跡開始が必要');
          } else {
            final remainingMinutes = startTime.difference(now).inMinutes;
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
          // LocationServiceの実際の状態を確認
          final actuallyTracking = _locationService.isTracking;
          print('[$timestamp] [ScheduleMonitor] LocationService.isTracking = $actuallyTracking');

          if (!actuallyTracking) {
            print('[$timestamp] [ScheduleMonitor] ⚠️ 状態不整合検出！ScheduleMonitorは追跡中だがLocationServiceは停止中');
            print('[$timestamp] [ScheduleMonitor] 🔄 追跡を再開します');
            _isTracking = false; // 状態をリセット
            await _startTracking(); // 再開
          } else {
            // 追跡中でもbackground_locationのコールバックが呼ばれない場合があるため
            // 定期的に現在地を取得して送信（シミュレーター対応）
            print('[$timestamp] [ScheduleMonitor] 📍 定期的な位置情報更新を実行');
            await _manualLocationUpdate();
          }
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

      // バックグラウンド追跡を開始（権限がある場合）
      final hasPermission = await _locationService.hasAlwaysPermission();
      print('[$timestamp] [ScheduleMonitor] Always権限チェック: $hasPermission');

      if (!hasPermission) {
        print('[$timestamp] [ScheduleMonitor] ❌ バックグラウンド権限なし');
        print('[$timestamp] [ScheduleMonitor] ⚠️ 設定 → プライバシー → 位置情報サービス → imane → "常に"を選択してください');
        // 権限がない場合は _isTracking を true にしない
        return;
      }

      print('[$timestamp] [ScheduleMonitor] 📍 LocationService.startTracking() を呼び出します...');
      final trackingStarted = await _locationService.startTracking();
      print('[$timestamp] [ScheduleMonitor] 📍 startTracking() の結果: $trackingStarted');

      if (trackingStarted) {
        print('[$timestamp] [ScheduleMonitor] ✓ バックグラウンド追跡開始成功');
        _isTracking = true;
      } else {
        print('[$timestamp] [ScheduleMonitor] ❌ バックグラウンド追跡開始失敗');
        _isTracking = false;
      }
    } catch (e) {
      final timestamp = DateTime.now().toIso8601String();
      print('[$timestamp] [ScheduleMonitor] ❌ 追跡開始エラー: $e');
      _isTracking = false;
    }
  }

  /// 手動で位置情報を更新（シミュレーター用）
  Future<void> _manualLocationUpdate() async {
    try {
      final timestamp = DateTime.now().toIso8601String();
      print('[$timestamp] [ScheduleMonitor] 現在地を手動取得中...');

      final position = await _locationService.getCurrentLocation();

      if (position == null) {
        print('[$timestamp] [ScheduleMonitor] 現在地の取得失敗');
        return;
      }

      print('[$timestamp] [ScheduleMonitor] 現在地取得成功:');
      print('  - Latitude: ${position.latitude}');
      print('  - Longitude: ${position.longitude}');
      print('  - Accuracy: ${position.accuracy}m');

      // バックエンドに送信
      final apiService = ApiService();
      final response = await apiService.post(
        '/location/update',
        body: {
          'coords': {
            'lat': position.latitude,
            'lng': position.longitude,
          },
          'accuracy': position.accuracy,
        },
        requiresAuth: true,
      );

      print('[$timestamp] [ScheduleMonitor] 位置情報送信完了');
      print('  - Response: $response');

      // 通知がトリガーされたかチェック
      final triggeredNotifications = response['triggered_notifications'] as List?;
      if (triggeredNotifications != null && triggeredNotifications.isNotEmpty) {
        print('[$timestamp] [ScheduleMonitor] ✅ ${triggeredNotifications.length}件の通知がトリガーされました');
      }
    } catch (e) {
      final timestamp = DateTime.now().toIso8601String();
      print('[$timestamp] [ScheduleMonitor] 手動位置更新エラー: $e');
    }
  }

  /// 位置情報追跡を停止
  Future<void> _stopTracking() async {
    try {
      final timestamp = DateTime.now().toIso8601String();
      print('[$timestamp] [ScheduleMonitor] === 位置情報追跡停止 ===');

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
