# BUBBLE Backend (FastAPI)

BUBBLEアプリケーションのバックエンドAPIサーバー

## 技術スタック

- **FastAPI**: 高速なPython Webフレームワーク
- **Firebase**: 認証、Firestore、Storage、FCM
- **Google Cloud Run**: サーバーレスホスティング
- **uv**: 高速なPython パッケージマネージャー

## セットアップ

### 1. uvのインストール

```bash
# macOS/Linux
curl -LsSf https://astral.sh/uv/install.sh | sh

# Windows
powershell -c "irm https://astral.sh/uv/install.ps1 | iex"
```

### 2. 依存関係のインストール

```bash
cd backend
uv sync
```

### 3. 環境変数の設定

`.env.example`を`.env`にコピーして編集

```bash
cp .env.example .env
```

### 4. Firebase認証情報の設定

Firebaseコンソールからサービスアカウントキーをダウンロードし、`firebase-credentials.json`として保存

### 5. 開発サーバー起動

```bash
uv run uvicorn app.main:app --reload
```

http://localhost:8000 でAPIサーバーが起動します

## APIドキュメント

起動後、以下のURLでSwagger UIにアクセス可能:
- http://localhost:8000/docs

## ディレクトリ構成

```
backend/
├── app/
│   ├── api/v1/          # APIエンドポイント
│   ├── core/            # コア機能（Firebase初期化等）
│   ├── models/          # データモデル
│   ├── schemas/         # リクエスト/レスポンススキーマ
│   ├── services/        # ビジネスロジック
│   ├── utils/           # ユーティリティ関数
│   └── tasks/           # バックグラウンドタスク
├── tests/               # テストコード
├── pyproject.toml       # プロジェクト設定・依存関係
└── uv.lock              # ロックファイル
```

## よく使うコマンド

```bash
# 依存関係の追加
uv add <package-name>

# 開発用依存関係の追加
uv add --dev <package-name>

# 依存関係の更新
uv sync

# テスト実行
uv run pytest

# Linter実行
uv run ruff check .

# フォーマット
uv run ruff format .
```

## デプロイ (Google Cloud Run)

```bash
gcloud run deploy bubble-api \
  --source . \
  --platform managed \
  --region asia-northeast1 \
  --allow-unauthenticated
```
