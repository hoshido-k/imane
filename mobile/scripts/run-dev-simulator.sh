#!/bin/bash
# 開発環境でiOSシミュレーターで起動するスクリプト

set -e

echo "Starting imane mobile app in DEVELOPMENT mode (iOS Simulator)..."
echo "=================================================================="

cd "$(dirname "$0")/.."

# .envファイルから環境変数を読み込み
if [ -f ".env" ]; then
    echo "Loading environment variables from .env..."
    export $(grep -v '^#' .env | xargs)
    echo "✓ Environment variables loaded"
else
    echo "WARNING: .env file not found. Please create one from .env.example"
    echo "Continuing with environment variables from shell..."
fi
echo ""

# Google Maps APIキーの確認
if [ -z "$GOOGLE_MAPS_API_KEY_DEV" ]; then
    echo "ERROR: GOOGLE_MAPS_API_KEY_DEV is not set!"
    echo "Please add it to your .env file or set it as an environment variable."
    exit 1
fi
echo "✓ Google Maps API key (dev) configured"
echo ""

# 開発環境のFirebase設定ファイルに切り替え
if [ -f "ios/Runner/GoogleService-Info-Dev.plist" ]; then
    echo "Switching to development Firebase configuration..."
    cp ios/Runner/GoogleService-Info-Dev.plist ios/Runner/GoogleService-Info.plist
    echo "✓ Using GoogleService-Info-Dev.plist"
fi
echo ""

# 開発環境の設定でFlutterアプリを起動
fvm flutter run \
  --dart-define=API_BASE_URL=http://localhost:8000/api/v1 \
  --dart-define=ENVIRONMENT=development \
  --dart-define=GOOGLE_MAPS_API_KEY_DEV=$GOOGLE_MAPS_API_KEY_DEV \
  -d "iPhone 17"

echo ""
echo "App started successfully!"
