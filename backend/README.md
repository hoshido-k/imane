# imane Backend (FastAPI)

imaneアプリケーションのバックエンドAPIサーバー

---

## 📱 プロジェクト概要

**imane（イマネ）** は、「今ね、ここにいるよ」を自動で伝える位置情報ベースの自動通知アプリです。

このバックエンドは、以下の機能を提供します:
- 位置情報スケジュール管理
- お気に入り場所管理
- 位置情報トラッキング（10分間隔）
- ジオフェンシング（50m圏内判定）
- 自動通知（到着・滞在・退出）
- ユーザー認証・フレンド管理

---

## 🛠️ 技術スタック

- **FastAPI**: 高速なPython Webフレームワーク
- **Firebase Admin SDK**: 認証、Firestore、FCM
- **uv**: 高速なPython パッケージマネージャー
- **Python 3.11+**: ランタイム

---

## 🚀 セットアップ

### 1. uvのインストール

```bash
# macOS/Linux
curl -LsSf https://astral.sh/uv/install.sh | sh

# Windows
powershell -c "irm https://astral.sh/uv/install.ps1 | iex"
```

---

### 2. 依存関係のインストール

```bash
cd backend
uv sync
```

---

### 3. 環境変数の設定

`.env.example`を`.env`にコピーして編集:

```bash
cp .env.example .env
```

`.env` の内容（例）:

```env
# Application
APP_NAME=imane API
DEBUG=True

# Firebase設定
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_CREDENTIALS_PATH=./serviceAccountKey-dev.json

# JWT設定
SECRET_KEY=your-super-secret-jwt-key
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30

# 暗号化キー
ENCRYPTION_KEY=your-32-byte-encryption-key

# Location設定
GEOFENCE_RADIUS_METERS=50
LOCATION_UPDATE_INTERVAL_MINUTES=10
DATA_RETENTION_HOURS=24

# Notification設定
NOTIFICATION_STAY_DURATION_MINUTES=60
```

**暗号化キーの生成方法:**

```bash
python3 -c "import secrets; print(secrets.token_urlsafe(32))"
```

---

### 4. Firebase認証情報の設定

Firebaseコンソールからサービスアカウントキーをダウンロードし、環境に応じて保存:

```bash
# 開発環境用
mv ~/Downloads/imane-dev-xxxxx.json backend/serviceAccountKey-dev.json

# 本番環境用（準備時）
mv ~/Downloads/imane-prod-xxxxx.json backend/serviceAccountKey-prod.json
```

詳細は[FIREBASE_SETUP.md](../FIREBASE_SETUP.md)を参照。

---

### 5. 開発サーバー起動

```bash
uv run uvicorn app.main:app --reload
```

http://localhost:8000 でAPIサーバーが起動します。

---

## 📚 APIドキュメント

起動後、以下のURLでSwagger UIにアクセス可能:
- **Swagger UI**: http://localhost:8000/docs
- **ReDoc**: http://localhost:8000/redoc

---

## 📁 ディレクトリ構成

```
backend/
├── app/
│   ├── main.py              # FastAPI アプリケーションエントリーポイント
│   ├── config.py            # 環境設定
│   ├── api/
│   │   ├── dependencies.py  # 依存関係（認証など）
│   │   └── v1/              # API v1 エンドポイント
│   │       ├── auth.py      # 認証
│   │       ├── users.py     # ユーザー管理
│   │       ├── friends.py   # フレンド管理
│   │       ├── schedules.py # スケジュール管理（NEW）
│   │       ├── favorites.py # お気に入り場所（NEW）
│   │       ├── location.py  # 位置情報トラッキング（NEW）
│   │       └── notifications.py # 通知
│   ├── core/
│   │   └── firebase.py      # Firebase初期化
│   ├── schemas/             # Pydantic スキーマ（リクエスト/レスポンス）
│   │   ├── auth.py
│   │   ├── user.py
│   │   ├── friend.py
│   │   ├── schedule.py      # NEW
│   │   ├── favorite.py      # NEW
│   │   ├── location.py      # NEW
│   │   └── notification.py
│   ├── services/            # ビジネスロジック
│   │   ├── auth.py
│   │   ├── users.py
│   │   ├── friends.py
│   │   ├── geofencing.py    # NEW - ジオフェンシング判定
│   │   ├── auto_notification.py # NEW - 自動通知トリガー
│   │   └── notifications.py
│   └── utils/               # ユーティリティ関数
│       ├── jwt.py
│       ├── security.py
│       └── encryption.py
├── tests/                   # テストコード
│   ├── test_auth.py
│   ├── test_schedules.py    # NEW
│   ├── test_geofencing.py   # NEW
│   └── ...
├── pyproject.toml              # プロジェクト設定・依存関係
├── uv.lock                     # ロックファイル
├── .env.example                # 環境変数のサンプル
├── serviceAccountKey-dev.json  # Firebase認証情報・開発環境（.gitignore済み）
└── serviceAccountKey-prod.json # Firebase認証情報・本番環境（.gitignore済み）
```

---

## 🔌 API エンドポイント一覧

### 認証・ユーザー
| メソッド | エンドポイント | 説明 |
|---------|--------------|------|
| POST | /api/v1/auth/signup | 新規登録 |
| POST | /api/v1/auth/login | ログイン |
| POST | /api/v1/auth/refresh | トークン更新 |
| GET | /api/v1/users/me | プロフィール取得 |
| PUT | /api/v1/users/me | プロフィール更新 |

### フレンド管理
| メソッド | エンドポイント | 説明 |
|---------|--------------|------|
| POST | /api/v1/friends/request | フレンドリクエスト送信 |
| POST | /api/v1/friends/accept | フレンドリクエスト承認 |
| GET | /api/v1/friends | フレンド一覧 |
| DELETE | /api/v1/friends/{id} | フレンド削除 |

### スケジュール管理（NEW）
| メソッド | エンドポイント | 説明 |
|---------|--------------|------|
| POST | /api/v1/schedules | スケジュール作成 |
| GET | /api/v1/schedules | スケジュール一覧 |
| GET | /api/v1/schedules/{id} | スケジュール詳細 |
| PUT | /api/v1/schedules/{id} | スケジュール更新 |

### お気に入り場所（NEW）
| メソッド | エンドポイント | 説明 |
|---------|--------------|------|
| POST | /api/v1/favorites | お気に入り追加 |
| GET | /api/v1/favorites | お気に入り一覧 |
| DELETE | /api/v1/favorites/{id} | お気に入り削除 |

### 位置情報トラッキング（NEW）
| メソッド | エンドポイント | 説明 |
|---------|--------------|------|
| POST | /api/v1/location/update | 位置情報送信（バックグラウンドから10分間隔） |
| GET | /api/v1/location/status | 現在のトラッキングステータス取得 |

### 通知
| メソッド | エンドポイント | 説明 |
|---------|--------------|------|
| POST | /api/v1/notifications/register | FCMトークン登録 |
| GET | /api/v1/notifications/history | 通知履歴（24時間） |

---

## 🧪 テスト

### テスト実行

```bash
# すべてのテストを実行
uv run pytest

# 特定のテストファイルを実行
uv run pytest tests/test_auth.py

# 詳細出力
uv run pytest -v

# カバレッジレポート付き
uv run pytest --cov=app --cov-report=html
```

---

## 🧹 コード品質管理

### Linter実行

```bash
# コードチェック
uv run ruff check .

# 自動修正
uv run ruff check --fix .
```

### フォーマット

```bash
# コードフォーマット
uv run ruff format .
```

---

## 📦 よく使うコマンド

```bash
# 依存関係の追加
uv add <package-name>

# 開発用依存関係の追加
uv add --dev <package-name>

# 依存関係の更新
uv sync

# 依存関係の削除
uv remove <package-name>

# Python バージョン確認
uv run python --version
```

---

## 🔥 Firebase設定

### Firestore Collections

imaneで使用するFirestoreコレクション:

- **users**: ユーザー情報
- **friends**: フレンド関係
- **location_schedules**: 位置情報スケジュール（NEW）
- **favorite_locations**: お気に入り場所（NEW）
- **location_history**: 位置情報履歴（24時間TTL）（NEW）
- **notification_history**: 通知履歴（24時間TTL）（NEW）
- **fcm_tokens**: FCMトークン

詳細は[REQUIREMENTS.md](../REQUIREMENTS.md)のデータモデルセクションを参照。

---

## 🌍 環境別設定

### 開発環境

```env
DEBUG=True
APP_NAME=imane API (Dev)
```

### 本番環境

```env
DEBUG=False
APP_NAME=imane API
SECRET_KEY=<強力なランダムキー>
ENCRYPTION_KEY=<強力なランダムキー>
```

本番環境ではCORS設定を厳格化:

```python
# app/main.py
origins = [
    "https://yourdomain.com",
]
```

---

## 🚨 トラブルシューティング

### エラー: "Permission denied"

**原因**: Firestoreセキュリティルールが厳しすぎる

**解決策**:
1. Firebase Console > Firestore Database > ルール を確認
2. 開発中は一時的にテストモードに変更

---

### エラー: "firebase-admin could not be initialized"

**原因**: サービスアカウントキーが正しく配置されていない

**解決策**:
1. `serviceAccountKey.json`のパスを確認
2. `.env`の`FIREBASE_CREDENTIALS_PATH`を確認

---

### エラー: "ModuleNotFoundError"

**原因**: 依存関係がインストールされていない

**解決策**:

```bash
uv sync
```

---

## 📖 参考リンク

- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [Firebase Admin SDK](https://firebase.google.com/docs/reference/admin/python)
- [uv Documentation](https://github.com/astral-sh/uv)
- [プロジェクト概要](../README.md)
- [要件定義書](../REQUIREMENTS.md)
- [開発ガイドライン](../CLAUDE.md)

---

**最終更新**: 2025-11-04
**Version**: 1.0.0
