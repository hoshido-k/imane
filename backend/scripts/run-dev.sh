#!/bin/bash
# 開発環境でバックエンドを起動するスクリプト

set -e

echo "Starting imane API in DEVELOPMENT mode..."
echo "==========================================="

# 開発環境の.envファイルを使用
export ENV=development

cd "$(dirname "$0")/.."

# 開発用の設定ファイルが存在するか確認
if [ ! -f .env.development ]; then
    echo "ERROR: .env.development file not found!"
    echo "Please copy .env.example to .env.development and configure it."
    exit 1
fi

# .env.developmentを.envにコピー（既存の.envをバックアップ）
if [ -f .env ]; then
    cp .env .env.backup
    echo "Backed up existing .env to .env.backup"
fi

cp .env.development .env
echo "Using .env.development configuration"
echo ""

# サーバー起動
uv run uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
