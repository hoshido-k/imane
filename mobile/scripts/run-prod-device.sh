#!/bin/bash
# 本番環境用のiOS実機起動スクリプト

set -e

echo "Running imane mobile app on DEVICE with PRODUCTION environment..."
echo "================================================================="

cd "$(dirname "$0")/.."

# .envファイルから環境変数を読み込み
if [ -f ".env" ]; then
    echo "Loading environment variables from .env..."
    export $(grep -v '^#' .env | xargs)
    echo "✓ Environment variables loaded"
else
    echo "WARNING: .env file not found"
fi
echo ""

# Google Maps APIキーの確認
if [ -z "$GOOGLE_MAPS_API_KEY_PROD" ]; then
    echo "ERROR: GOOGLE_MAPS_API_KEY_PROD is not set!"
    echo "Please add it to your .env file."
    exit 1
fi
echo "✓ Google Maps API key (prod) configured"
echo ""

# 本番環境のFirebase設定ファイルに切り替え
if [ -f "ios/Runner/GoogleService-Info-Prod.plist" ]; then
    echo "Switching to production Firebase configuration..."
    cp ios/Runner/GoogleService-Info-Prod.plist ios/Runner/GoogleService-Info.plist
    echo "✓ Using GoogleService-Info-Prod.plist"
else
    echo "ERROR: GoogleService-Info-Prod.plist not found!"
    exit 1
fi
echo ""

# 本番環境のAPI URL
PROD_API_URL="https://imane-api-654899417069.asia-northeast1.run.app/api/v1"

echo "Production API URL: $PROD_API_URL"
echo "Device: iPhone (Physical Device)"
echo ""

# 本番環境で実機起動（デバイスを自動選択）
# 実機が接続されている場合、シミュレーターより優先されます
fvm flutter run \
  --dart-define=API_BASE_URL="$PROD_API_URL" \
  --dart-define=ENVIRONMENT=production \
  --dart-define=GOOGLE_MAPS_API_KEY_PROD="$GOOGLE_MAPS_API_KEY_PROD"

echo ""
echo "App launched successfully on device with production backend!"
