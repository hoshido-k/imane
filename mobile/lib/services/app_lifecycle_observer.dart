import 'package:flutter/material.dart';
import 'location_service.dart';
import 'schedule_monitor_service.dart';

/// App lifecycle observer to manage location tracking
/// when app goes to background/foreground
class AppLifecycleObserver extends WidgetsBindingObserver {
  final LocationService _locationService = LocationService();
  final ScheduleMonitorService _scheduleMonitor = ScheduleMonitorService();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final timestamp = DateTime.now().toIso8601String();

    switch (state) {
      case AppLifecycleState.resumed:
        print('[$timestamp] [AppLifecycle] ⬆️ App RESUMED (foreground)');
        print('[$timestamp] [AppLifecycle] Location tracking status:');
        print('  - Foreground auto-update: ${_locationService.isForegroundAutoUpdateEnabled}');
        print('  - Background tracking: ${_locationService.isTracking}');

        // フォアグラウンド復帰時にスケジュールをチェック
        print('[$timestamp] [AppLifecycle] スケジュールチェックを実行');
        _scheduleMonitor.startMonitoring();
        break;

      case AppLifecycleState.inactive:
        print('[$timestamp] [AppLifecycle] ⏸️ App INACTIVE (transitioning)');
        break;

      case AppLifecycleState.paused:
        print('[$timestamp] [AppLifecycle] ⬇️ App PAUSED (background)');
        print('[$timestamp] [AppLifecycle] Location tracking status:');
        print('  - Foreground auto-update: ${_locationService.isForegroundAutoUpdateEnabled}');
        print('  - Background tracking: ${_locationService.isTracking}');
        break;

      case AppLifecycleState.detached:
        print('[$timestamp] [AppLifecycle] ❌ App DETACHED (closing)');
        break;

      case AppLifecycleState.hidden:
        print('[$timestamp] [AppLifecycle] 🔒 App HIDDEN');
        break;
    }
  }
}
