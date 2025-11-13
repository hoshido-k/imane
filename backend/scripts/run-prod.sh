#!/bin/bash
# 本番環境でバックエンドを起動するスクリプト

set -e

echo "Starting imane API in PRODUCTION mode..."
echo "==========================================="

# 本番環境の.envファイルを使用
export ENV=production

cd "$(dirname "$0")/.."

# 本番用の設定ファイルが存在するか確認
if [ ! -f .env.production ]; then
    echo "ERROR: .env.production file not found!"
    echo "Please copy .env.example to .env.production and configure it."
    exit 1
fi

# .env.productionを.envにコピー
if [ -f .env ]; then
    cp .env .env.backup
    echo "Backed up existing .env to .env.backup"
fi

cp .env.production .env
echo "Using .env.production configuration"
echo ""

# 本番環境の必須設定チェック
if grep -q "CHANGE-THIS" .env; then
    echo "ERROR: Please update all CHANGE-THIS placeholders in .env.production!"
    exit 1
fi

if grep -q "your-production-project-id" .env; then
    echo "ERROR: Please update Firebase project ID in .env.production!"
    exit 1
fi

echo "Configuration check passed."
echo ""

# サーバー起動（本番環境ではauto-reloadなし）
uv run uvicorn app.main:app --host 0.0.0.0 --port 8080 --workers 4
