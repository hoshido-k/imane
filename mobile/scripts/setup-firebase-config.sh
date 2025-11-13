#!/bin/bash

# Firebase設定ファイルを環境に応じて切り替えるスクリプト
# Usage: ./setup-firebase-config.sh [dev|prod]

set -e

# 引数から環境を取得
ENVIRONMENT="${1:-dev}"

# パスの設定
RUNNER_DIR="${SRCROOT}/Runner"
SOURCE_FILE=""
TARGET_FILE="${RUNNER_DIR}/GoogleService-Info.plist"

# 環境に応じてソースファイルを選択
if [ "$ENVIRONMENT" = "prod" ] || [ "$ENVIRONMENT" = "production" ]; then
    SOURCE_FILE="${RUNNER_DIR}/GoogleService-Info-Prod.plist"
    echo "🚀 Setting up PRODUCTION Firebase configuration"
elif [ "$ENVIRONMENT" = "dev" ] || [ "$ENVIRONMENT" = "development" ]; then
    SOURCE_FILE="${RUNNER_DIR}/GoogleService-Info-Dev.plist"
    echo "🔧 Setting up DEVELOPMENT Firebase configuration"
else
    echo "❌ Error: Invalid environment '$ENVIRONMENT'"
    echo "Usage: $0 [dev|prod]"
    exit 1
fi

# ソースファイルの存在確認
if [ ! -f "$SOURCE_FILE" ]; then
    echo "❌ Error: Source file not found: $SOURCE_FILE"
    exit 1
fi

# GoogleService-Info.plist をコピー
cp "$SOURCE_FILE" "$TARGET_FILE"
echo "✅ Copied $SOURCE_FILE to $TARGET_FILE"

# 確認用にPROJECT_IDを表示
PROJECT_ID=$(/usr/libexec/PlistBuddy -c "Print :PROJECT_ID" "$TARGET_FILE" 2>/dev/null || echo "unknown")
echo "📋 PROJECT_ID: $PROJECT_ID"

exit 0
