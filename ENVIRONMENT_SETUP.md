# imane 環境設定ガイド

このドキュメントでは、imaneプロジェクトの開発環境と本番環境の設定方法を説明します。

## 📋 概要

imaneは、リポジトリを分けることなく**環境変数**で開発環境と本番環境を切り替える設計になっています。

- **バックエンド（FastAPI）**: `.env`ファイルで環境設定を管理
- **フロントエンド（Flutter）**: `--dart-define`で環境設定を管理
- **Firebase**: 開発用と本番用のプロジェクトを分離

---

## 🔧 バックエンド環境設定

### 1. 環境ファイルの作成

バックエンドには以下の3つの環境ファイルがあります：

```
backend/
├── .env.example       # サンプル設定（Gitに含まれる）
├── .env.development   # 開発環境設定（Gitに含まれる）
├── .env.production    # 本番環境設定（Gitに含まれる、要編集）
└── .env               # 実際に使用する設定（Gitには含まれない）
```

### 2. 開発環境のセットアップ

```bash
cd backend

# 開発環境用の.envを作成（初回のみ）
cp .env.development .env

# または、起動スクリプトを使用（自動的に.envを切り替えます）
./scripts/run-dev.sh
```

### 3. 本番環境のセットアップ

```bash
cd backend

# 本番環境用の.envを編集
nano .env.production

# 以下の項目を必ず変更してください：
# - FIREBASE_PROJECT_ID: 本番用FirebaseプロジェクトID
# - SECRET_KEY: 強力なランダム文字列（32文字以上）
# - ENCRYPTION_KEY: 強力なランダム文字列（32文字以上）
# - BATCH_TOKEN: 強力なランダム文字列（32文字以上）
# - ALLOWED_ORIGINS: 本番ドメイン（例: https://imane.app）

# ランダムキーの生成方法
python -c "import secrets; print(secrets.token_urlsafe(32))"

# 本番環境で起動
./scripts/run-prod.sh
```

### 4. 環境変数の説明

| 変数名 | 説明 | 開発環境 | 本番環境 |
|--------|------|----------|----------|
| `ENV` | 環境識別子 | `development` | `production` |
| `DEBUG` | デバッグモード | `True` | `False` |
| `FIREBASE_PROJECT_ID` | FirebaseプロジェクトID | 開発用ID | 本番用ID |
| `SECRET_KEY` | JWT署名キー | 簡単な文字列 | 強力なランダム文字列 |
| `ENCRYPTION_KEY` | データ暗号化キー | 簡単な文字列 | 強力なランダム文字列 |
| `BATCH_TOKEN` | バッチ処理認証トークン | 空欄可 | 必須 |
| `ALLOWED_ORIGINS` | CORS許可ドメイン | `*` | 本番ドメイン |

---

## 📱 フロントエンド環境設定

### 1. 開発環境での実行

#### iOSシミュレーターの場合

```bash
cd mobile

# スクリプトを使用
./scripts/run-dev-simulator.sh

# または手動で実行
flutter run \
  --dart-define=API_BASE_URL=http://localhost:8000/api/v1 \
  --dart-define=ENVIRONMENT=development
```

#### 実機（iPhone）の場合

```bash
cd mobile

# MacのIPアドレスを環境変数に設定
export API_HOST=192.168.0.41  # あなたのMacのIPアドレス

# スクリプトを使用
./scripts/run-dev-device.sh

# または手動で実行
flutter run \
  --dart-define=API_BASE_URL=http://192.168.0.41:8000/api/v1 \
  --dart-define=ENVIRONMENT=development
```

### 2. 本番環境でのビルド

```bash
cd mobile

# 本番APIのURLを環境変数に設定
export PROD_API_URL=https://api.imane.app/api/v1

# スクリプトを使用
./scripts/build-prod.sh

# または手動で実行
flutter build ios \
  --dart-define=API_BASE_URL=https://api.imane.app/api/v1 \
  --dart-define=ENVIRONMENT=production \
  --release
```

### 3. MacのIPアドレス確認方法

実機でテストする際は、MacのローカルIPアドレスが必要です：

```bash
# macOSでIPアドレスを確認
ipconfig getifaddr en0

# または
ifconfig | grep "inet " | grep -v 127.0.0.1
```

---

## 🔥 Firebase設定

### 1. Firebaseプロジェクトの作成

開発環境と本番環境で別々のFirebaseプロジェクトを作成することを推奨します：

```
Firebaseコンソール (https://console.firebase.google.com/)
├── imane-dev-xxxxx   (開発環境)
└── imane-prod-xxxxx  (本番環境)
```

### 2. バックエンド用のサービスアカウントキー

各Firebaseプロジェクトからサービスアカウントキーをダウンロード：

```
backend/
├── serviceAccountKey-dev.json   (開発用)
└── serviceAccountKey-prod.json  (本番用)
```

**注意**: これらのファイルは`.gitignore`に含まれており、Gitにコミットされません。

### 3. フロントエンド用のGoogleService-Info.plist

iOSプロジェクト設定からダウンロード：

```
mobile/ios/Runner/
├── GoogleService-Info-Dev.plist   (開発用)
├── GoogleService-Info-Prod.plist  (本番用)
└── GoogleService-Info.plist       (実際に使用するファイル)
```

使用する環境に応じてコピー：

```bash
# 開発環境
cp GoogleService-Info-Dev.plist GoogleService-Info.plist

# 本番環境
cp GoogleService-Info-Prod.plist GoogleService-Info.plist
```

---

## 🚀 実際のワークフロー

### 開発時

```bash
# 1. バックエンドを起動（開発環境）
cd backend
./scripts/run-dev.sh

# 2. 新しいターミナルでフロントエンドを起動（実機）
cd mobile
export API_HOST=192.168.0.41  # あなたのMacのIP
./scripts/run-dev-device.sh
```

### 本番リリース時

```bash
# 1. バックエンドのデプロイ（Cloud Run等）
cd backend
# .env.productionを編集
gcloud run deploy imane-api \
  --source . \
  --env-vars-file .env.production

# 2. フロントエンドのビルド
cd mobile
# 本番用Firebase設定に切り替え
cp ios/Runner/GoogleService-Info-Prod.plist ios/Runner/GoogleService-Info.plist
# ビルド
./scripts/build-prod.sh
```

---

## ⚠️ セキュリティチェックリスト

本番環境にデプロイする前に、以下を必ず確認してください：

### バックエンド

- [ ] `.env.production`の`SECRET_KEY`を強力なランダム文字列に変更
- [ ] `.env.production`の`ENCRYPTION_KEY`を強力なランダム文字列に変更
- [ ] `.env.production`の`BATCH_TOKEN`を設定
- [ ] `.env.production`の`FIREBASE_PROJECT_ID`を本番用に変更
- [ ] `.env.production`の`ALLOWED_ORIGINS`を本番ドメインに制限
- [ ] `serviceAccountKey-prod.json`を配置
- [ ] `DEBUG=False`に設定

### フロントエンド

- [ ] 本番用の`PROD_API_URL`を設定
- [ ] `GoogleService-Info-Prod.plist`を配置
- [ ] `ENVIRONMENT=production`でビルド

### Firebase

- [ ] Firestore セキュリティルールを設定
- [ ] Firebase Storage セキュリティルールを設定
- [ ] Firebase Authentication の本番設定完了

---

## 🐛 トラブルシューティング

### バックエンドが起動しない

```bash
# 環境変数を確認
cd backend
cat .env

# Firebaseの認証情報を確認
ls -la serviceAccountKey*.json
```

### フロントエンドがAPIに接続できない

```bash
# 1. バックエンドが起動しているか確認
curl http://localhost:8000/api/v1/

# 2. 実機の場合、MacのIPアドレスを確認
ipconfig getifaddr en0

# 3. ファイアウォールでポート8000が開いているか確認
```

### 環境が切り替わらない

```bash
# Flutterのキャッシュをクリア
cd mobile
flutter clean
flutter pub get

# 再ビルド
./scripts/run-dev-device.sh
```

---

## 📚 参考資料

- [FastAPI環境変数管理](https://fastapi.tiangolo.com/advanced/settings/)
- [Flutter --dart-define](https://dart.dev/tools/dart-compile#compile-option---define)
- [Firebase プロジェクト設定](https://firebase.google.com/docs/projects/learn-more)

---

**最終更新日**: 2025-11-12
