#!/bin/bash
# 開発環境でiOSシミュレーターで起動するスクリプト

set -e

echo "Starting imane mobile app in DEVELOPMENT mode (iOS Simulator)..."
echo "=================================================================="

cd "$(dirname "$0")/.."

# 開発環境のFirebase設定ファイルに切り替え
if [ -f "ios/Runner/GoogleService-Info-Dev.plist" ]; then
    echo "Switching to development Firebase configuration..."
    cp ios/Runner/GoogleService-Info-Dev.plist ios/Runner/GoogleService-Info.plist
    echo "✓ Using GoogleService-Info-Dev.plist"
fi
echo ""

# 開発環境の設定でFlutterアプリを起動
flutter run \
  --dart-define=API_BASE_URL=http://localhost:8000/api/v1 \
  --dart-define=ENVIRONMENT=development \
  -d "iPhone 17"

echo ""
echo "App started successfully!"
