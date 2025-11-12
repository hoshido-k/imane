/// Location and geofencing configuration
///
/// This file centralizes all location-related settings to make them
/// easily configurable and maintainable.
class LocationConfig {
  // Private constructor to prevent instantiation
  LocationConfig._();

  /// ジオフェンス半径（メートル）
  ///
  /// 目的地への到着を検知する距離。
  /// バックエンドの GEOFENCE_RADIUS_METERS と一致させる必要があります。
  ///
  /// Default: 50.0m (本番環境)
  static const double distanceFilterMeters = 50.0;

  /// 位置情報更新間隔（ミリ秒）
  ///
  /// バックグラウンドで位置情報を取得する間隔。
  /// バックエンドの LOCATION_UPDATE_INTERVAL_MINUTES と一致させる必要があります。
  ///
  /// Default: 5 minutes = 300,000ms (本番環境)
  static const int locationUpdateIntervalMs = 1 * 60 * 1000; // 5分

  /// スケジュール監視タイマー間隔（分）
  ///
  /// アクティブなスケジュールをチェックし、位置追跡の開始/停止を
  /// 判断するタイマーの実行間隔。
  ///
  /// Default: 5 minutes (本番環境)
  static const int scheduleMonitorIntervalMinutes = 1;

  /// 滞在時間通知のデフォルト値（分）
  ///
  /// このアプリでは滞在時間はスケジュールごとに設定可能で、
  /// バックエンドの notify_after_minutes から取得します。
  /// この値はフォールバック用のデフォルト値です。
  ///
  /// Default: 60 minutes
  static const int defaultStayDurationMinutes = 1;

  /// テスト用設定
  ///
  /// 開発・テスト時に使用する設定値。
  /// 本番環境では使用しないでください。
  static const _TestConfig test = _TestConfig();
}

/// テスト用の設定値
///
/// 開発・デバッグ時に短い間隔でテストするための設定。
class _TestConfig {
  const _TestConfig();

  /// テスト用: 距離フィルター
  static const double distanceFilterMeters = 5.0;

  /// テスト用: 位置情報更新間隔（1分）
  static const int locationUpdateIntervalMs = 1 * 60 * 1000;

  /// テスト用: スケジュール監視間隔（1分）
  static const int scheduleMonitorIntervalMinutes = 1;
}
