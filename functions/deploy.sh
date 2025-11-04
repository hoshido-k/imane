#!/bin/bash
# Cloud Functions デプロイスクリプト
# uvで管理しつつ、Firebase CLIの要求に対応

set -e

echo "📦 Generating requirements.txt from pyproject.toml..."
uv pip compile pyproject.toml -o requirements.txt

echo "🔧 Setting up standard venv for Firebase..."
if [ ! -d "venv" ] || [ -L "venv" ]; then
    rm -rf venv
    python3 -m venv venv
    source venv/bin/activate
    pip install -r requirements.txt > /dev/null 2>&1
    deactivate
    echo "✅ venv setup complete"
fi

echo "🚀 Deploying to Firebase..."
cd ..
firebase deploy --only functions

echo "✅ Deployment complete!"
