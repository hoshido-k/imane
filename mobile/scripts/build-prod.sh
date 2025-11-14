#!/bin/bash
# 本番環境用のiOSビルドを実行するスクリプト

set -e

echo "Building imane mobile app for PRODUCTION..."
echo "============================================="

cd "$(dirname "$0")/.."

# .envファイルから環境変数を読み込み（.env.productionを優先）
if [ -f ".env.production" ]; then
    echo "Loading production environment variables from .env.production..."
    export $(grep -v '^#' .env.production | xargs)
    echo "✓ Production environment variables loaded"
elif [ -f ".env" ]; then
    echo "Loading environment variables from .env..."
    export $(grep -v '^#' .env | xargs)
    echo "✓ Environment variables loaded"
else
    echo "WARNING: .env file not found. Please create one from .env.example"
    echo "Continuing with environment variables from shell..."
fi
echo ""

# Google Maps APIキーの確認
if [ -z "$GOOGLE_MAPS_API_KEY_PROD" ]; then
    echo "ERROR: GOOGLE_MAPS_API_KEY_PROD is not set!"
    echo "Please add it to your .env.production or .env file, or set it as an environment variable."
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
    echo "Please create ios/Runner/GoogleService-Info-Prod.plist from Firebase Console."
    exit 1
fi
echo ""

# 本番環境のAPI URL
PROD_API_URL="https://imane-api-654899417069.asia-northeast1.run.app/api/v1"

echo "Production API URL: $PROD_API_URL"
echo ""

# 本番環境用ビルド
fvm flutter build ios \
  --dart-define=API_BASE_URL="$PROD_API_URL" \
  --dart-define=ENVIRONMENT=production \
  --dart-define=GOOGLE_MAPS_API_KEY_PROD="$GOOGLE_MAPS_API_KEY_PROD" \
  --release

echo ""
echo "Production build completed successfully!"
echo "Open ios/Runner.xcworkspace in Xcode to archive and upload to App Store."
