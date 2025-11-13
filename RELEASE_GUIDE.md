# imane リリースガイド

**最終更新日**: 2025-11-13
**対象**: 本番環境への初回リリース

---

## 📋 目次

1. [リリース前の準備](#1-リリース前の準備)
2. [本番Firebase環境の構築](#2-本番firebase環境の構築)
3. [バックエンドAPIのデプロイ](#3-バックエンドapiのデプロイ)
4. [iOSアプリのApp Store申請](#4-iOsアプリのapp-store申請)
5. [リリース後の運用](#5-リリース後の運用)

---

## 概要

imaneアプリを本番環境にリリースするための手順書です。以下の順序で作業を進めてください：

```
1. セキュリティチェック
   ↓
2. 本番Firebase環境の構築
   ↓
3. バックエンドAPI・Cloud Functionsのデプロイ
   ↓
4. iOSアプリのApp Store申請
   ↓
5. リリース・運用開始
```

**所要時間**: 約2〜3日（審査期間を除く）

---

## 1. リリース前の準備

### 1.1 セキュリティチェック ✅

リリース前に必ず[SECURITY_CHECKLIST.md](./SECURITY_CHECKLIST.md)の全項目を確認してください。

**特に重要な項目**:

- [ ] `.env.production` の `SECRET_KEY` と `ENCRYPTION_KEY` が強力なランダム文字列
- [ ] `DEBUG=False` に設定
- [ ] Firestore・Storage Security Rulesがデプロイ済み
- [ ] APIキーが適切に制限されている
- [ ] `.gitignore` に機密情報ファイルが含まれている

```bash
# ランダムキーの生成
python -c "import secrets; print(secrets.token_urlsafe(32))"
```

### 1.2 プライバシーポリシー・利用規約の公開

- [ ] **プライバシーポリシーを公開**
  - ファイル: [PRIVACY_POLICY.md](./PRIVACY_POLICY.md)
  - 公開先: GitHub Pages (`https://hoshido-k.github.io/imane/privacy-policy.html`)
  - 設定手順: [GITHUB_PAGES_SETUP.md](./GITHUB_PAGES_SETUP.md)

- [ ] **利用規約を公開**
  - ファイル: [TERMS_OF_SERVICE.md](./TERMS_OF_SERVICE.md)
  - 公開先: GitHub Pages (`https://hoshido-k.github.io/imane/terms-of-service.html`)

### 1.3 環境変数ファイルの準備

```bash
cd backend

# 本番用環境変数ファイルを作成
cp .env.example .env.production

# 必須項目を編集
nano .env.production
```

**必須設定項目**:
```env
ENV=production
DEBUG=False
FIREBASE_PROJECT_ID=imane-production
SECRET_KEY=<強力なランダム文字列>
ENCRYPTION_KEY=<強力なランダム文字列>
BATCH_TOKEN=<強力なランダム文字列>
ALLOWED_ORIGINS=["https://your-production-domain.com"]
```

---

## 2. 本番Firebase環境の構築

### 2.1 Firebaseプロジェクトの作成

1. **Firebase Console** (https://console.firebase.google.com/) にアクセス
2. 「プロジェクトを追加」→ プロジェクト名: `imane-production`
3. ロケーション: `asia-northeast1` (東京)

### 2.2 Firebase設定

詳細は [PRODUCTION_FIREBASE_SETUP.md](./PRODUCTION_FIREBASE_SETUP.md) を参照してください。

**主要な設定項目**:

- [ ] Firebase Authentication（メール/パスワード）を有効化
- [ ] Cloud Firestore データベースを作成（本番モード）
- [ ] Firebase Storage を有効化
- [ ] Cloud Messaging（FCM）の設定
- [ ] APNs認証キー（.p8）をアップロード
- [ ] iOSアプリを追加（Bundle ID: `com.yourcompany.imane`）
- [ ] `GoogleService-Info-Prod.plist` をダウンロード

### 2.3 Firestore Rules・Indexesのデプロイ

```bash
cd backend

# 本番プロジェクトに切り替え
firebase use production

# Rules・Indexesをデプロイ
firebase deploy --only firestore:rules,firestore:indexes

# Storageルールをデプロイ
firebase deploy --only storage
```

### 2.4 Google Maps API の設定

1. **Google Cloud Console** > APIs & Services > Credentials
2. APIキーを作成: `imane-maps-api-key-prod`
3. **アプリケーション制限**: iOSアプリ（Bundle ID: `com.yourcompany.imane`）
4. **API制限**: Maps SDK for iOS, Geocoding API, Places API
5. **クォータ設定**: 日次上限を設定（予算保護）

---

## 3. バックエンドAPIのデプロイ

詳細は [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md) を参照してください。

### 3.1 Google Cloud Runへのデプロイ（推奨）

```bash
# Google Cloudプロジェクトを設定
gcloud config set project imane-production

# Cloud Run APIを有効化
gcloud services enable run.googleapis.com

# Dockerイメージをビルド・プッシュ
cd backend
docker build -t asia-northeast1-docker.pkg.dev/imane-production/imane-backend/api:v1.0.0 .
docker push asia-northeast1-docker.pkg.dev/imane-production/imane-backend/api:v1.0.0

# Cloud Runにデプロイ
gcloud run deploy imane-api \
  --image asia-northeast1-docker.pkg.dev/imane-production/imane-backend/api:v1.0.0 \
  --platform managed \
  --region asia-northeast1 \
  --allow-unauthenticated \
  --memory 512Mi \
  --cpu 1

# デプロイ後のURLを確認
gcloud run services describe imane-api --region asia-northeast1 --format 'value(status.url)'
```

**出力例**: `https://imane-api-xxxxxxxxxx-an.a.run.app`

### 3.2 Cloud Functionsのデプロイ（データ自動削除）

```bash
# Cloud Functionsをデプロイ
firebase deploy --only functions

# ログ確認
firebase functions:log --only cleanupExpiredData
```

### 3.3 動作確認

```bash
# APIのヘルスチェック
API_URL=$(gcloud run services describe imane-api --region asia-northeast1 --format 'value(status.url)')
curl $API_URL/health

# 期待される出力: {"status":"healthy"}
```

---

## 4. iOSアプリのApp Store申請

詳細は [APP_STORE_SUBMISSION_CHECKLIST.md](./APP_STORE_SUBMISSION_CHECKLIST.md) を参照してください。

### 4.1 Apple Developer Program登録

- [ ] **Apple Developer Programに登録** (年間 $99)
- [ ] **App Store Connectにアクセス可能** (https://appstoreconnect.apple.com/)

### 4.2 Xcodeプロジェクト設定

```bash
cd mobile
open ios/Runner.xcworkspace
```

**設定項目**:
- [ ] Bundle Identifier: `com.yourcompany.imane`（本番用）
- [ ] Team: Apple Developer Teamを選択
- [ ] Version: `1.0.0`
- [ ] Build: `1`
- [ ] Provisioning Profile: App Store Distribution
- [ ] GoogleService-Info-Prod.plist を配置

### 4.3 リリースビルドの作成

```bash
cd mobile

# クリーンビルド
flutter clean
flutter pub get

# iOS リリースビルド
flutter build ios --release
```

**Xcodeでアーカイブ**:
1. Product > Destination > Any iOS Device (arm64)
2. Product > Archive
3. Validate App（エラーがないことを確認）
4. Distribute App > App Store Connect > Upload

### 4.4 App Store Connectでの設定

1. **アプリを作成**
   - プラットフォーム: iOS
   - 名前: `imane`
   - Bundle ID: `com.yourcompany.imane`
   - SKU: `imane-ios`

2. **メタデータを入力**
   - サブタイトル: `今ね、ここにいるよ - 位置情報通知`
   - カテゴリ: Social Networking / Utilities
   - 説明文、キーワード、スクリーンショット
   - プライバシーポリシーURL: `https://hoshido-k.github.io/imane/privacy-policy.html`
   - サポートURL: `https://github.com/hoshido-k/imane`

3. **App Privacyを設定**
   - 収集するデータ: 位置情報、メールアドレス、ユーザーID
   - トラッキング: なし

4. **審査に提出**
   - デモアカウントを登録（審査用）
   - 「Submit for Review」をクリック
   - 審査完了まで待機（1〜3日）

---

## 5. リリース後の運用

### 5.1 モニタリング

- [ ] **Firebase Analytics**
  - ユーザー数、イベントトラッキング
  - Firebase Console > Analytics

- [ ] **Firebase Crashlytics**
  - クラッシュレポートの監視
  - Firebase Console > Crashlytics

- [ ] **Cloud Logging**
  - バックエンドAPIのログ確認
  - Google Cloud Console > Logging

### 5.2 定期メンテナンス

**日次**:
- [ ] エラーログの確認
- [ ] Crashlyticsでクラッシュレポート確認
- [ ] Firebase使用量の確認（予算内か）

**週次**:
- [ ] APIパフォーマンスの確認
- [ ] ユーザーフィードバックの確認
- [ ] App Storeレビューへの返信

**月次**:
- [ ] Firestore Security Rulesのレビュー
- [ ] 依存関係の脆弱性チェック（`pip-audit`, `npm audit`, `flutter pub outdated`）
- [ ] コスト分析と最適化

### 5.3 アップデート手順

**バックエンドAPI**:
```bash
# コード修正後
docker build -t asia-northeast1-docker.pkg.dev/imane-production/imane-backend/api:v1.1.0 .
docker push asia-northeast1-docker.pkg.dev/imane-production/imane-backend/api:v1.1.0

gcloud run deploy imane-api \
  --image asia-northeast1-docker.pkg.dev/imane-production/imane-backend/api:v1.1.0 \
  --region asia-northeast1
```

**iOSアプリ**:
```bash
# pubspec.yaml でバージョンを更新: version: 1.0.1+2

flutter clean
flutter pub get
flutter build ios --release

# Xcode でアーカイブ > App Store Connect にアップロード
# App Store Connect で「What's New」を記載 > Submit for Review
```

---

## トラブルシューティング

### Cloud Run デプロイエラー

**エラー**: `Permission denied`

**解決策**:
```bash
gcloud projects add-iam-policy-binding imane-production \
  --member="serviceAccount:YOUR_SERVICE_ACCOUNT@imane-production.iam.gserviceaccount.com" \
  --role="roles/run.admin"
```

### Firestore Rules デプロイエラー

**エラー**: `Invalid argument: Rules compilation failed`

**解決策**:
```bash
# ルールファイルの構文を確認
firebase firestore:rules validate
```

### App Store アップロードエラー

**エラー**: `Signing for "Runner" requires a development team`

**解決策**:
- Xcode > Runner > Signing & Capabilities
- Team を選択
- Provisioning Profile を再生成

---

## チェックリスト（リリース前の最終確認）

- [ ] セキュリティチェックリスト完了（[SECURITY_CHECKLIST.md](./SECURITY_CHECKLIST.md)）
- [ ] 本番Firebase設定完了（[PRODUCTION_FIREBASE_SETUP.md](./PRODUCTION_FIREBASE_SETUP.md)）
- [ ] バックエンドAPIデプロイ完了
- [ ] Cloud Functionsデプロイ完了
- [ ] プライバシーポリシー・利用規約公開済み
- [ ] App Store Connect メタデータ入力完了
- [ ] TestFlightでベータテスト実施済み
- [ ] App Store審査に提出

---

## 関連ドキュメント

- [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md) - デプロイ手順の詳細
- [APP_STORE_SUBMISSION_CHECKLIST.md](./APP_STORE_SUBMISSION_CHECKLIST.md) - App Store申請の詳細
- [SECURITY_CHECKLIST.md](./SECURITY_CHECKLIST.md) - セキュリティチェック項目
- [PRODUCTION_FIREBASE_SETUP.md](./PRODUCTION_FIREBASE_SETUP.md) - Firebase設定の詳細
- [PRIVACY_POLICY.md](./PRIVACY_POLICY.md) - プライバシーポリシー
- [TERMS_OF_SERVICE.md](./TERMS_OF_SERVICE.md) - 利用規約
- [README.md](./README.md) - プロジェクト概要
- [CLAUDE.md](./CLAUDE.md) - 開発ガイドライン

---

**リリース成功をお祈りしています！🚀**
