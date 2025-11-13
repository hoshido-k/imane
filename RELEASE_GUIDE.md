# imane 最速リリースガイド

**最終更新日**: 2025-11-13
**目標**: 最短でApp Storeリリース

---

## 🚀 リリースまでの3ステップ（所要時間: 約4〜6時間）

```
1. 本番Firebase環境構築（1〜2時間）
   ↓
2. バックエンドデプロイ（1〜2時間）
   ↓
3. App Store申請（1〜2時間）
   ↓
審査待ち（1〜3日）
```

---

## ステップ1: 本番Firebase環境構築（1〜2時間）

### 1-1. Firebaseプロジェクト作成

1. https://console.firebase.google.com/ にアクセス
2. 「プロジェクトを追加」→ プロジェクト名: `imane-production`
3. Google Analyticsを有効化
4. ロケーション: `asia-northeast1` (東京)

### 1-2. iOSアプリを追加

1. Firebase Console > プロジェクト設定 > アプリを追加 > iOS
2. Bundle ID: `com.yourcompany.imane`（実際の値に変更）
3. `GoogleService-Info.plist` をダウンロード
4. `mobile/ios/Runner/GoogleService-Info-Prod.plist` に保存

### 1-3. サービスアカウントキー取得

1. Firebase Console > プロジェクト設定 > サービスアカウント
2. 「新しい秘密鍵を生成」
3. `backend/serviceAccountKey-prod.json` に保存

### 1-4. Firebase設定（必須のみ）

**Authentication**:
- Firebase Console > Authentication > Sign-in method
- メール/パスワードを有効化

**Firestore**:
- Firebase Console > Firestore Database > データベースを作成
- **本番モード**で開始
- ロケーション: `asia-northeast1`

**Storage**:
- Firebase Console > Storage > 始める
- 本番モード
- ロケーション: `asia-northeast1`

**Cloud Messaging**:
- Firebase Console > プロジェクト設定 > Cloud Messaging
- APNs認証キー（.p8）をアップロード
  - Apple Developer Console > Keys > 新規作成
  - APNsにチェック → ダウンロード
  - Firebase Consoleにアップロード

### 1-5. Firestore Rules・Indexesデプロイ

```bash
cd backend

# 本番プロジェクトに切り替え
firebase use production

# Rulesとインデックスをデプロイ（3分程度）
firebase deploy --only firestore:rules,firestore:indexes,storage

# ✅ 完了確認
firebase firestore:rules get
```

### 1-6. Google Maps API設定

1. Google Cloud Console > APIs & Services > Credentials
2. APIキーを作成: `imane-maps-api-key-prod`
3. **アプリケーション制限**: iOSアプリ
   - Bundle ID: `com.yourcompany.imane`
4. **API制限**: 以下のみ許可
   - Maps SDK for iOS
   - Geocoding API
   - Places API
5. **クォータ設定（リリース後対応）**: 後で設定可能

---

## ステップ2: バックエンドデプロイ（1〜2時間）

### 2-1. 環境変数ファイル作成

```bash
cd backend
cp .env.example .env.production
```

**`.env.production` を編集**:

```env
# 必須設定のみ
ENV=production
DEBUG=False

# Firebase
FIREBASE_PROJECT_ID=imane-production
FIREBASE_CREDENTIALS_PATH=./serviceAccountKey-prod.json

# セキュリティ（必ず変更）
SECRET_KEY=<ランダム文字列>
ENCRYPTION_KEY=<ランダム文字列>
BATCH_TOKEN=<ランダム文字列>

# CORS（リリース後に制限可能）
ALLOWED_ORIGINS=["*"]

# その他はデフォルト値でOK
ACCESS_TOKEN_EXPIRE_MINUTES=30
GEOFENCE_RADIUS_METERS=50
LOCATION_UPDATE_INTERVAL_MINUTES=10
DATA_RETENTION_HOURS=24
NOTIFICATION_STAY_DURATION_MINUTES=60
```

**ランダム文字列の生成**:
```bash
python -c "import secrets; print(secrets.token_urlsafe(32))"
# 3回実行して、それぞれSECRET_KEY、ENCRYPTION_KEY、BATCH_TOKENに設定
```

### 2-2. Google Cloud Runにデプロイ

```bash
# Google Cloudプロジェクト設定
gcloud config set project imane-production

# 必要なAPIを有効化
gcloud services enable run.googleapis.com
gcloud services enable artifactregistry.googleapis.com

# Artifact Registryリポジトリ作成
gcloud artifacts repositories create imane-backend \
  --repository-format=docker \
  --location=asia-northeast1

# Dockerイメージをビルド
cd backend
docker build -t asia-northeast1-docker.pkg.dev/imane-production/imane-backend/api:v1.0.0 .

# プッシュ
docker push asia-northeast1-docker.pkg.dev/imane-production/imane-backend/api:v1.0.0

# Cloud Runにデプロイ
gcloud run deploy imane-api \
  --image asia-northeast1-docker.pkg.dev/imane-production/imane-backend/api:v1.0.0 \
  --platform managed \
  --region asia-northeast1 \
  --allow-unauthenticated \
  --memory 512Mi \
  --cpu 1

# URLを確認
gcloud run services describe imane-api --region asia-northeast1 --format 'value(status.url)'
```

**出力例**: `https://imane-api-xxxxxxxxxx-an.a.run.app`

### 2-3. Cloud Functionsデプロイ（24時間削除）

```bash
cd backend

# Cloud Functionsをデプロイ
firebase deploy --only functions

# ✅ 完了確認
firebase functions:list
```

### 2-4. 動作確認

```bash
# ヘルスチェック
API_URL=$(gcloud run services describe imane-api --region asia-northeast1 --format 'value(status.url)')
curl $API_URL/health

# 期待される出力: {"status":"healthy"}
```

---

## ステップ3: App Store申請（1〜2時間）

### 3-1. プライバシーポリシー・利用規約の公開（5分）

**既に公開済み**:
- プライバシーポリシー: `https://hoshido-k.github.io/imane/privacy-policy.html`
- 利用規約: `https://hoshido-k.github.io/imane/terms-of-service.html`

**未公開の場合**: [GITHUB_PAGES_SETUP.md](./GITHUB_PAGES_SETUP.md)を参照

### 3-2. Apple Developer Program登録

- [ ] Apple Developer Program (年間 $99)
- [ ] App Store Connect アクセス可能

### 3-3. Xcodeプロジェクト設定（10分）

```bash
cd mobile
open ios/Runner.xcworkspace
```

**設定項目**:
1. **Bundle Identifier**: `com.yourcompany.imane`（本番用）
2. **Team**: Apple Developer Teamを選択
3. **Version**: `1.0.0`
4. **Build**: `1`
5. **Signing**: Automatically manage signing（推奨）

**GoogleService-Info.plist**:
```bash
# 本番用Firebase設定をコピー
cp ios/Runner/GoogleService-Info-Prod.plist ios/Runner/GoogleService-Info.plist
```

**Info.plist確認**:
- `NSLocationAlwaysAndWhenInUseUsageDescription` があること
- `NSLocationWhenInUseUsageDescription` があること
- 日本語で分かりやすい説明になっていること

### 3-4. リリースビルド作成（20分）

```bash
cd mobile

# クリーンビルド
flutter clean
flutter pub get

# iOS リリースビルド
flutter build ios --release
```

**Xcodeでアーカイブ**:
1. Xcode > Product > Destination > **Any iOS Device (arm64)**
2. Product > Archive（10〜15分）
3. Organizer > Archives > **Validate App**（エラーがないことを確認）
4. **Distribute App** > App Store Connect > Upload

### 3-5. App Store Connect設定（30分）

**アプリ作成**:
1. https://appstoreconnect.apple.com/ > My Apps > 「+」
2. プラットフォーム: iOS
3. 名前: `imane`
4. Bundle ID: `com.yourcompany.imane`
5. SKU: `imane-ios`

**メタデータ入力**:
- **サブタイトル**: `今ね、ここにいるよ - 位置情報通知`
- **カテゴリ**: Social Networking
- **説明文**: （400〜1000文字程度でアプリの説明）
- **キーワード**: `位置情報,通知,家族,友達,見守り,到着,安全,GPS`
- **プライバシーポリシーURL**: `https://hoshido-k.github.io/imane/privacy-policy.html`
- **サポートURL**: `https://github.com/hoshido-k/imane`

**スクリーンショット**:
- 6.5インチ: 3〜10枚（iPhone 14 Pro Max）
- 5.5インチ: 3〜10枚（iPhone 8 Plus、オプション）

**App Privacy**:
- 位置情報を収集: はい
- メールアドレスを収集: はい
- トラッキング: なし

**ビルド選択**:
- アップロードしたビルドを選択

**審査用情報**:
- デモアカウント（メール・パスワード）
- メモ: 「位置情報の自動通知をテストするには、フレンドとスケジュールを作成してください」

### 3-6. 審査に提出

1. すべての項目が入力されていることを確認
2. **Submit for Review** をクリック
3. 審査完了を待つ（**1〜3日**）

---

## ✅ 最小限チェックリスト

リリース前に以下を確認してください：

### Firebase
- [ ] 本番Firebaseプロジェクト作成済み
- [ ] iOSアプリ追加済み（Bundle ID一致）
- [ ] Authentication有効化（メール/パスワード）
- [ ] Firestore作成済み（本番モード）
- [ ] Firestore Rules・Indexesデプロイ済み
- [ ] Storage設定済み
- [ ] APNs認証キーアップロード済み

### バックエンド
- [ ] `.env.production` で `SECRET_KEY/ENCRYPTION_KEY/BATCH_TOKEN` を強力なランダム文字列に変更
- [ ] `DEBUG=False` に設定
- [ ] Cloud Runデプロイ済み
- [ ] Cloud Functionsデプロイ済み
- [ ] ヘルスチェックが成功（`{"status":"healthy"}`）

### iOS
- [ ] Bundle Identifier設定済み
- [ ] GoogleService-Info-Prod.plistコピー済み
- [ ] Info.plistに位置情報説明文あり
- [ ] リリースビルド成功
- [ ] App Store Connectにアップロード済み

### App Store Connect
- [ ] アプリ作成済み
- [ ] メタデータ入力完了
- [ ] プライバシーポリシーURL登録済み
- [ ] スクリーンショット追加済み
- [ ] App Privacy設定済み
- [ ] デモアカウント登録済み
- [ ] 審査に提出済み

---

## 🔄 リリース後対応（優先度順）

以下は**リリース後1〜2週間以内**に対応してください：

### 高優先度（1週間以内）
- [ ] **CORS制限**（[SECURITY_CHECKLIST.md](./SECURITY_CHECKLIST.md)参照）
  - `.env.production` の `ALLOWED_ORIGINS` を本番ドメインに制限
  - Cloud Runを再デプロイ

- [ ] **APIキー使用量監視**
  - Google Cloud Console > APIs & Services > ダッシュボード
  - クォータアラートを設定

- [ ] **Cloud Loggingでエラー監視**
  - Google Cloud Console > Logging
  - エラーログを定期確認

### 中優先度（2週間以内）
- [ ] **APIレート制限の実装**（[DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md)参照）
- [ ] **Cloud Monitoringアラート設定**
- [ ] **Firebase Analytics確認**
- [ ] **Crashlyticsクラッシュレポート確認**

### 低優先度（1ヶ月以内）
- [ ] **Firestoreバックアップ設定**
- [ ] **依存関係の脆弱性チェック**（月次）
- [ ] **セキュリティ監査**（[SECURITY_CHECKLIST.md](./SECURITY_CHECKLIST.md)参照）

---

## トラブルシューティング

### デプロイエラー: Permission denied

```bash
gcloud projects add-iam-policy-binding imane-production \
  --member="user:your-email@gmail.com" \
  --role="roles/run.admin"
```

### Firestore Rulesエラー

```bash
# 構文チェック
firebase firestore:rules validate
```

### App Storeアップロードエラー

- Xcode > Runner > Signing & Capabilities
- Teamを選択し直す
- Clean Build Folder（Shift + Cmd + K）
- 再度Archive

---

## 関連ドキュメント（詳細確認用）

- [APP_STORE_SUBMISSION_CHECKLIST.md](./APP_STORE_SUBMISSION_CHECKLIST.md) - App Store申請の詳細
- [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md) - デプロイ詳細手順
- [SECURITY_CHECKLIST.md](./SECURITY_CHECKLIST.md) - セキュリティ全項目
- [PRODUCTION_FIREBASE_SETUP.md](./PRODUCTION_FIREBASE_SETUP.md) - Firebase詳細設定

---

**最速リリース頑張ってください！🚀**

**所要時間**: 4〜6時間（審査期間を除く）
