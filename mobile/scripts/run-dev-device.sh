#!/bin/bash
# 開発環境で実機（iPhone）で起動するスクリプト

set -e

echo "Starting imane mobile app in DEVELOPMENT mode (Real Device)..."
echo "==============================================================="

cd "$(dirname "$0")/.."

# 開発環境のFirebase設定ファイルに切り替え
if [ -f "ios/Runner/GoogleService-Info-Dev.plist" ]; then
    echo "Switching to development Firebase configuration..."
    cp ios/Runner/GoogleService-Info-Dev.plist ios/Runner/GoogleService-Info.plist
    echo "✓ Using GoogleService-Info-Dev.plist"
fi
echo ""

# 実機IPアドレスを環境変数から取得（デフォルト値を使用）
API_HOST=${API_HOST:-192.168.0.41}

echo "Using API host: $API_HOST"
echo ""

# 開発環境の設定でFlutterアプリを起動
flutter run \
  --dart-define=API_BASE_URL=http://$API_HOST:8000/api/v1 \
  --dart-define=ENVIRONMENT=development

echo ""
echo "App started successfully!"
