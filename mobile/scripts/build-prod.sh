#!/bin/bash
# 本番環境用のiOSビルドを実行するスクリプト

set -e

echo "Building imane mobile app for PRODUCTION..."
echo "============================================="

cd "$(dirname "$0")/.."

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

# 本番環境のAPI URLを確認
PROD_API_URL=${PROD_API_URL:-https://api.imane.app/api/v1}

echo "Production API URL: $PROD_API_URL"
echo ""

# 本番環境が設定されていない場合は警告
if [[ $PROD_API_URL == *"api.imane.app"* ]]; then
    echo "WARNING: Using placeholder production URL!"
    echo "Set PROD_API_URL environment variable before building for production."
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# 本番環境用ビルド
flutter build ios \
  --dart-define=API_BASE_URL=$PROD_API_URL \
  --dart-define=ENVIRONMENT=production \
  --release

echo ""
echo "Production build completed successfully!"
echo "Open ios/Runner.xcworkspace in Xcode to archive and upload to App Store."
