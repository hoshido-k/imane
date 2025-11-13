# デプロイ手順書

**最終更新日**: 2025年11月13日

このガイドは、imaneアプリの本番環境へのデプロイ手順をまとめたものです。

---

## 目次

1. [前提条件](#1-前提条件)
2. [本番Firebase プロジェクトの準備](#2-本番firebase-プロジェクトの準備)
3. [バックエンド API のデプロイ](#3-バックエンド-api-のデプロイ)
4. [Firebase サービスのデプロイ](#4-firebase-サービスのデプロイ)
5. [iOS アプリのデプロイ](#5-ios-アプリのデプロイ)
6. [デプロイ後の確認](#6-デプロイ後の確認)
7. [トラブルシューティング](#7-トラブルシューティング)

---

## 1. 前提条件

### 1.1 必要なツール

- [×] **Firebase CLI**
  ```bash
  npm install -g firebase-tools
  firebase --version  # 13.0.0以上
  ```

- [×] **Google Cloud SDK（gcloud）**
  ```bash
  curl https://sdk.cloud.google.com | bash
  gcloud --version
  ```

- [×] **Python 3.11+ & uv**
  ```bash
  python --version
  uv --version
  ```

- [×] **Flutter 3.x**
  ```bash
  flutter --version
  flutter doctor  # すべて緑色のチェックマーク
  ```

- [×] **Xcode 15.x（iOS デプロイ用）**
  ```bash
  xcodebuild -version
  ```

### 1.2 アカウント・権限

- [×] **Firebase プロジェクトの Owner 権限**
- [×] **Google Cloud プロジェクトの Owner 権限**
- [×] **Apple Developer Program 登録済み**

---

## 2. 本番Firebase プロジェクトの準備

### 2.1 Firebase プロジェクト作成

```bash
# Firebase Console で手動作成済みの場合はスキップ
# プロジェクトID: imane-production
```

1. https://console.firebase.google.com/ にアクセス
2. 「プロジェクトを追加」
3. プロジェクト名: `imane Production`
4. プロジェクトID: `imane-production`
5. Google Analytics: 有効化（推奨）

### 2.2 Firebase プロジェクトの設定

```bash
# Firebase プロジェクトの切り替え
firebase use production

# 現在のプロジェクトを確認
firebase projects:list
```

### 2.3 本番用サービスアカウントキーの取得

1. **Firebase Console にアクセス**
   - https://console.firebase.google.com/
   - プロジェクト: `imane-production`

2. **サービスアカウントキーを生成**
   - Project Settings > Service Accounts
   - 「新しい秘密鍵の生成」をクリック
   - `serviceAccountKey-prod.json` として保存

3. **ファイルを安全な場所に配置**
   ```bash
   # backend/ ディレクトリに配置
   mv ~/Downloads/serviceAccountKey-*.json backend/serviceAccountKey-prod.json

   # .gitignore に含まれていることを確認
   grep "serviceAccountKey" backend/.gitignore
   ```

### 2.4 iOS アプリを Firebase に追加

1. **Firebase Console で iOS アプリを追加**
   - Project Settings > General
   - 「アプリを追加」 > iOS
   - Apple Bundle ID: `com.yourcompany.imane`（実際の Bundle ID）
   - App Store ID: 空欄（後で追加）

2. **GoogleService-Info-Prod.plist をダウンロード**
   - ダウンロードした `GoogleService-Info.plist` を `mobile/ios/Runner/GoogleService-Info-Prod.plist` に配置

---

## 3. バックエンド API のデプロイ

### 3.1 デプロイ先の選択

imane のバックエンド（FastAPI）は以下のいずれかにデプロイできます：

- **Google Cloud Run**（推奨）- サーバーレス、自動スケーリング
- **Google Compute Engine** - VM ベース
- **Heroku** - 簡単なデプロイ（有料）
- **AWS Elastic Beanstalk** - AWS環境

**推奨: Google Cloud Run**（以下、Cloud Run での手順を説明）

### 3.2 本番環境変数の準備

```bash
cd backend

# .env.production ファイルを作成
cp .env.example .env.production
```

`.env.production` を編集：

```env
# アプリ設定
APP_NAME=imane API
DEBUG=False
TESTING=False

# Firebase設定
FIREBASE_PROJECT_ID=imane-production
FIREBASE_CREDENTIALS_PATH=/app/serviceAccountKey-prod.json

# セキュリティ
SECRET_KEY=YOUR_SUPER_SECRET_KEY_HERE_AT_LEAST_32_CHARACTERS
ENCRYPTION_KEY=YOUR_ENCRYPTION_KEY_HERE_AT_LEAST_32_CHARACTERS

# CORS設定
ALLOWED_ORIGINS=["https://your-production-domain.com"]

# JWT設定
ACCESS_TOKEN_EXPIRE_MINUTES=30

# 位置情報設定
GEOFENCE_RADIUS_METERS=50
LOCATION_UPDATE_INTERVAL_MINUTES=10
DATA_RETENTION_HOURS=24

# 通知設定
NOTIFICATION_STAY_DURATION_MINUTES=60
```

**重要**: `SECRET_KEY` と `ENCRYPTION_KEY` は強力なランダム文字列に変更してください。

```bash
# ランダム文字列の生成
python -c "import secrets; print(secrets.token_urlsafe(32))"
```

### 3.3 Dockerfile の作成

```bash
cd backend
```

`Dockerfile` を作成：

```dockerfile
FROM python:3.11-slim

WORKDIR /app

# uvをインストール
RUN pip install --no-cache-dir uv

# 依存関係をコピー
COPY pyproject.toml uv.lock ./

# 依存関係をインストール
RUN uv sync --frozen

# アプリケーションコードをコピー
COPY app/ ./app/
COPY serviceAccountKey-prod.json ./

# ポート設定
ENV PORT=8080
EXPOSE 8080

# uvicornでアプリを起動
CMD ["uv", "run", "uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8080"]
```

### 3.4 Google Cloud Run にデプロイ

```bash
# Google Cloud プロジェクトを設定
gcloud config set project imane-production

# Cloud Run API を有効化
gcloud services enable run.googleapis.com

# Artifact Registry を有効化
gcloud services enable artifactregistry.googleapis.com

# Artifact Registry リポジトリを作成（初回のみ）
gcloud artifacts repositories create imane-backend \
  --repository-format=docker \
  --location=asia-northeast1 \
  --description="imane backend API"

# Docker イメージをビルド
cd backend
docker build -t asia-northeast1-docker.pkg.dev/imane-production/imane-backend/api:latest .

# Docker イメージをプッシュ
docker push asia-northeast1-docker.pkg.dev/imane-production/imane-backend/api:latest

# Cloud Run にデプロイ
gcloud run deploy imane-api \
  --image asia-northeast1-docker.pkg.dev/imane-production/imane-backend/api:latest \
  --platform managed \
  --region asia-northeast1 \
  --allow-unauthenticated \
  --set-env-vars "FIREBASE_PROJECT_ID=imane-production" \
  --set-env-vars "DEBUG=False" \
  --set-env-vars "SECRET_KEY=$(python -c 'import secrets; print(secrets.token_urlsafe(32))')" \
  --set-env-vars "ENCRYPTION_KEY=$(python -c 'import secrets; print(secrets.token_urlsafe(32))')" \
  --memory 512Mi \
  --cpu 1 \
  --max-instances 10
```

**デプロイ完了後、URLを確認**:

```bash
# Cloud Run サービスURLを取得
gcloud run services describe imane-api --region asia-northeast1 --format 'value(status.url)'
```

例: `https://imane-api-xxxxxxxxxx-an.a.run.app`

### 3.5 環境変数の設定（Secret Manager を使用）

より安全に環境変数を管理するために、Secret Manager を使用します。

```bash
# Secret Manager API を有効化
gcloud services enable secretmanager.googleapis.com

# SECRET_KEY を Secret Manager に保存
echo -n "YOUR_SECRET_KEY" | gcloud secrets create imane-secret-key --data-file=-

# ENCRYPTION_KEY を Secret Manager に保存
echo -n "YOUR_ENCRYPTION_KEY" | gcloud secrets create imane-encryption-key --data-file=-

# Cloud Run サービスにSecret Managerへのアクセス権を付与
gcloud secrets add-iam-policy-binding imane-secret-key \
  --member="serviceAccount:$(gcloud run services describe imane-api --region asia-northeast1 --format 'value(spec.template.spec.serviceAccountName)')" \
  --role="roles/secretmanager.secretAccessor"

# Cloud Run サービスを再デプロイ（シークレットを使用）
gcloud run deploy imane-api \
  --image asia-northeast1-docker.pkg.dev/imane-production/imane-backend/api:latest \
  --platform managed \
  --region asia-northeast1 \
  --set-secrets "SECRET_KEY=imane-secret-key:latest,ENCRYPTION_KEY=imane-encryption-key:latest"
```

---

## 4. Firebase サービスのデプロイ

### 4.1 Firestore Rules のデプロイ

```bash
# 本番環境に切り替え
firebase use production

# Firestore Rules をデプロイ
firebase deploy --only firestore:rules

# デプロイ確認
firebase firestore:rules get
```

### 4.2 Firestore Indexes のデプロイ

```bash
# Firestore Indexes をデプロイ
firebase deploy --only firestore:indexes

# デプロイ確認
# Firebase Console > Firestore Database > Indexes
```

### 4.3 Storage Rules のデプロイ

```bash
# Storage Rules をデプロイ
firebase deploy --only storage

# デプロイ確認
firebase storage:rules get
```

### 4.4 Cloud Functions のデプロイ

```bash
# Cloud Functions をデプロイ
firebase deploy --only functions

# デプロイ確認
firebase functions:list

# ログ確認
firebase functions:log --only cleanupExpiredData
```

**環境変数の設定**:

```bash
# BATCH_TOKEN を設定
firebase functions:config:set batch.token="YOUR_BATCH_TOKEN_HERE"

# 設定確認
firebase functions:config:get
```

---

## 5. iOS アプリのデプロイ

### 5.1 本番用 Firebase 設定の切り替え

```bash
cd mobile

# GoogleService-Info-Prod.plist を使用するようにコードを変更（必要に応じて）
# または、Xcode で Build Configuration を使い分ける
```

### 5.2 Xcode プロジェクトの設定

1. **Xcode を開く**
   ```bash
   open mobile/ios/Runner.xcworkspace
   ```

2. **Signing & Capabilities を設定**
   - Runner > Signing & Capabilities
   - Team: あなたのApple Developer Team
   - Provisioning Profile: App Store Distribution

3. **Bundle Identifier を確認**
   - 例: `com.yourcompany.imane`
   - Firebase Console の Bundle ID と一致

4. **Version と Build Number を設定**
   - Version: `1.0.0`
   - Build: `1`

### 5.3 Release ビルドの作成

```bash
cd mobile

# クリーンビルド
flutter clean
flutter pub get

# iOS Release ビルド
flutter build ios --release
```

### 5.4 Xcode でアーカイブ作成

1. **Xcode を開く**
   ```bash
   open mobile/ios/Runner.xcworkspace
   ```

2. **デバイスを選択**
   - Product > Destination > Any iOS Device (arm64)

3. **アーカイブ**
   - Product > Archive
   - アーカイブ完了まで待機（5〜10分）

4. **アーカイブの検証**
   - Window > Organizer > Archives
   - アーカイブを選択 > 「Validate App」
   - エラーがないことを確認

5. **App Store Connect にアップロード**
   - 「Distribute App」をクリック
   - 「App Store Connect」を選択
   - 「Upload」をクリック
   - アップロード完了まで待機（5〜10分）

### 5.5 App Store Connect で申請

1. **App Store Connect にアクセス**
   - https://appstoreconnect.apple.com/
   - My Apps > imane

2. **ビルドを選択**
   - Version 1.0.0 > Build
   - アップロードしたビルドを選択

3. **メタデータを入力**
   - スクリーンショット
   - 説明文
   - キーワード
   - プライバシーポリシーURL: `https://hoshido-k.github.io/imane/privacy-policy.html`

4. **審査に提出**
   - 「Submit for Review」をクリック
   - 審査完了まで待機（1〜3日）

---

## 6. デプロイ後の確認

### 6.1 API の動作確認

```bash
# Cloud Run サービスURL を取得
API_URL=$(gcloud run services describe imane-api --region asia-northeast1 --format 'value(status.url)')

# ヘルスチェック
curl $API_URL/health

# 期待される出力: {"status":"healthy"}
```

### 6.2 Firestore Rules の確認

1. **Firebase Console にアクセス**
   - https://console.firebase.google.com/
   - プロジェクト: imane-production

2. **Firestore Database > Rules**
   - ルールが正しくデプロイされていることを確認

3. **Rules Simulator でテスト**
   - Firestore Console > Rules > Simulate
   - 認証なしアクセスがブロックされることを確認

### 6.3 Cloud Functions の確認

```bash
# Cloud Functions のログを確認
firebase functions:log --only cleanupExpiredData

# 手動実行でテスト
curl -X POST \
  -H "Authorization: Bearer YOUR_BATCH_TOKEN" \
  https://asia-northeast1-imane-production.cloudfunctions.net/manualCleanup
```

### 6.4 iOS アプリの動作確認

- [ ] **TestFlight でベータテスト**
  - TestFlight からアプリをインストール
  - 全機能が正常に動作することを確認

- [ ] **本番環境との接続確認**
  - Firebase Authentication でログイン
  - Firestore にデータが保存される
  - Cloud Functions が正常に実行される
  - プッシュ通知が届く

---

## 7. トラブルシューティング

### 7.1 Cloud Run デプロイエラー

**エラー**: `Permission denied`

**解決策**:
```bash
# サービスアカウントに適切な権限を付与
gcloud projects add-iam-policy-binding imane-production \
  --member="serviceAccount:YOUR_SERVICE_ACCOUNT@imane-production.iam.gserviceaccount.com" \
  --role="roles/run.admin"
```

### 7.2 Firestore Rules デプロイエラー

**エラー**: `Invalid argument: Rules compilation failed`

**解決策**:
```bash
# ルールファイルの構文を確認
firebase firestore:rules validate

# ローカルエミュレーターでテスト
firebase emulators:start --only firestore
```

### 7.3 Cloud Functions デプロイエラー

**エラー**: `Node.js 18 is decommissioned`

**解決策**:
```bash
# package.json の engines.node を変更
# "node": "20"

# 再デプロイ
firebase deploy --only functions
```

### 7.4 iOS アプリのアーカイブエラー

**エラー**: `Signing for "Runner" requires a development team`

**解決策**:
- Xcode > Runner > Signing & Capabilities
- Team を選択
- Provisioning Profile を再生成

### 7.5 App Store Connect アップロードエラー

**エラー**: `Invalid Bundle. The bundle ... doesn't contain a correctly named Info.plist file`

**解決策**:
```bash
# Podfile を確認
cd mobile/ios
pod install

# クリーンビルド
flutter clean
flutter pub get
flutter build ios --release
```

---

## 8. 更新・アップデート手順

### 8.1 バックエンド API の更新

```bash
# コードを修正
# ...

# Docker イメージを再ビルド
cd backend
docker build -t asia-northeast1-docker.pkg.dev/imane-production/imane-backend/api:v1.1.0 .
docker push asia-northeast1-docker.pkg.dev/imane-production/imane-backend/api:v1.1.0

# Cloud Run を更新
gcloud run deploy imane-api \
  --image asia-northeast1-docker.pkg.dev/imane-production/imane-backend/api:v1.1.0 \
  --platform managed \
  --region asia-northeast1
```

### 8.2 Firestore Rules/Indexes の更新

```bash
# Firestore Rules を更新
firebase deploy --only firestore:rules

# Firestore Indexes を更新
firebase deploy --only firestore:indexes
```

### 8.3 Cloud Functions の更新

```bash
# 関数コードを修正
# ...

# Cloud Functions を更新
firebase deploy --only functions

# 特定の関数のみ更新
firebase deploy --only functions:cleanupExpiredData
```

### 8.4 iOS アプリの更新

```bash
# バージョンを更新
# pubspec.yaml: version: 1.0.1+2

# クリーンビルド
flutter clean
flutter pub get
flutter build ios --release

# Xcode でアーカイブ
# Product > Archive

# App Store Connect にアップロード
# Distribute App > App Store Connect

# App Store Connect でバージョン情報を更新
# 「What's New」に更新内容を記載

# 審査に提出
# Submit for Review
```

---

## 9. 監視・メンテナンス

### 9.1 Cloud Logging

```bash
# Cloud Run のログを確認
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=imane-api" --limit 50

# Cloud Functions のログを確認
firebase functions:log
```

### 9.2 Cloud Monitoring

1. **Google Cloud Console にアクセス**
   - https://console.cloud.google.com/
   - プロジェクト: imane-production

2. **Monitoring > Dashboards**
   - Cloud Run のメトリクスを確認
   - リクエスト数、レイテンシ、エラー率

3. **アラートの設定**
   - Monitoring > Alerting
   - エラー率が5%を超えたらメール通知

### 9.3 Firebase Analytics

1. **Firebase Console にアクセス**
   - https://console.firebase.google.com/
   - プロジェクト: imane-production

2. **Analytics > Events**
   - ユーザーの行動を分析
   - 人気機能を把握

3. **Crashlytics > Dashboard**
   - クラッシュレポートを確認
   - 優先度の高いクラッシュから修正

---

## 10. コスト最適化

### 10.1 Cloud Run のコスト削減

```bash
# 最小インスタンス数を0に設定（コールドスタート許容）
gcloud run services update imane-api \
  --region asia-northeast1 \
  --min-instances 0

# メモリを削減（必要に応じて）
gcloud run services update imane-api \
  --region asia-northeast1 \
  --memory 256Mi
```

### 10.2 Firebase コスト削減

- **Firestore**: 読み書き回数を最小化（キャッシュ活用）
- **Cloud Functions**: 実行時間を短縮、メモリを最小化
- **Storage**: 不要なファイルを定期削除

### 10.3 無料枠の確認

- **Cloud Run**: 月間200万リクエストまで無料
- **Firestore**: 読み取り5万回、書き込み2万回まで無料
- **Cloud Functions**: 月間200万回実行まで無料

---

## 11. セキュリティ

### 11.1 定期的なセキュリティチェック

```bash
# 依存関係の脆弱性チェック
cd backend
pip-audit

cd mobile
flutter pub outdated

cd backend/functions
npm audit
```

### 11.2 アクセスログの監視

```bash
# 不審なアクセスをチェック
gcloud logging read "resource.type=cloud_run_revision AND httpRequest.status>=400" --limit 100
```

---

## 12. まとめ

このガイドに従って、以下をデプロイできました：

- ✅ バックエンドAPI（Google Cloud Run）
- ✅ Firestore Rules/Indexes
- ✅ Cloud Functions（TTL自動削除）
- ✅ iOS アプリ（App Store Connect）

デプロイ後も、定期的に監視・メンテナンスを行い、ユーザーに安全で快適なサービスを提供してください。

---

**参考リンク**:

- Google Cloud Run: https://cloud.google.com/run/docs
- Firebase Documentation: https://firebase.google.com/docs
- App Store Connect Help: https://help.apple.com/app-store-connect/
