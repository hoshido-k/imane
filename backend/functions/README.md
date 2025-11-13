# imane Cloud Functions - TTL自動削除

24時間経過したデータを自動削除するCloud Functions。

## 📋 概要

プライバシー保護のため、以下のデータを定期的に削除します:

- **location_history**: `auto_delete_at` が過去のドキュメント
- **notification_history**: `auto_delete_at` が過去のドキュメント
- **schedules**: `status=expired` かつ `end_time` から24時間経過

## 🚀 デプロイされた関数

### 1. `cleanupExpiredData`

**種類**: スケジュール実行（Pub/Sub）

**実行間隔**: 1時間ごと

**タイムゾーン**: Asia/Tokyo

**リージョン**: asia-northeast1

**説明**: 自動的に期限切れデータを削除

### 2. `manualCleanup`

**種類**: HTTP関数

**リージョン**: asia-northeast1

**認証**: BATCH_TOKEN必須

**説明**: 手動でクリーンアップを実行（テスト用）

## 🛠️ ローカル開発

### 依存関係のインストール

```bash
cd backend/functions
npm install
```

### ビルド

```bash
npm run build
```

### ローカルエミュレータでテスト

```bash
npm run serve
```

Firebase Emulatorが起動します:
- Functions: http://localhost:5001

### 手動クリーンアップのテスト

```bash
# BATCH_TOKEN を設定
export BATCH_TOKEN="test-token"

# 手動クリーンアップを実行
curl -X POST \
  http://localhost:5001/imane-production/asia-northeast1/manualCleanup \
  -H "Authorization: Bearer test-token"
```

## 📦 デプロイ

### 開発環境

```bash
cd backend
firebase use dev
firebase deploy --only functions
```

### 本番環境

```bash
cd backend
firebase use prod
firebase deploy --only functions
```

## 🔧 環境変数の設定

### BATCH_TOKEN の設定

```bash
# 強力なランダムトークンを生成
openssl rand -hex 32

# Firebase Functions に設定
firebase functions:config:set batch.token="YOUR_RANDOM_TOKEN"

# 設定確認
firebase functions:config:get
```

## 📊 モニタリング

### ログの確認

```bash
# 最新のログを表示
firebase functions:log

# 特定の関数のログのみ
firebase functions:log --only cleanupExpiredData

# リアルタイムでログを監視
firebase functions:log --follow
```

### Firebase Console

1. Firebase Console > Functions
2. `cleanupExpiredData` または `manualCleanup` を選択
3. タブ: ログ、使用量、詳細

### Cloud Scheduler

1. Google Cloud Console > Cloud Scheduler
2. ジョブ名: `firebase-schedule-cleanupExpiredData-asia-northeast1`
3. 手動実行も可能

## 🧪 テスト

### 本番環境で手動実行

```bash
# Functions URL を取得
firebase functions:list

# 手動実行（BATCH_TOKEN必要）
curl -X POST \
  https://asia-northeast1-imane-production.cloudfunctions.net/manualCleanup \
  -H "Authorization: Bearer YOUR_BATCH_TOKEN"
```

### レスポンス例

```json
{
  "success": true,
  "deleted": {
    "locationHistory": 42,
    "notificationHistory": 18,
    "schedules": 5
  },
  "timestamp": "2025-11-13T04:00:00.000Z"
}
```

## 📁 ファイル構成

```
functions/
├── src/
│   └── index.ts           # メインのCloudFunction
├── lib/                   # ビルド出力（自動生成）
├── package.json
├── tsconfig.json
├── .eslintrc.js
└── README.md
```

## 💰 コスト

### Cloud Functions

**無料枠** (月間):
- 呼び出し: 200万回
- コンピューティング時間: 40万GB秒
- 送信ネットワーク: 5GB

**想定**:
- 実行頻度: 720回/月（1時間に1回）
- 実行時間: 約5秒/回
- メモリ: 256MB

→ **無料枠内に収まる**

### Cloud Scheduler

- 無料枠: 月3ジョブまで無料
- imaneでは1ジョブのみ

→ **無料**

## 🔍 トラブルシューティング

### デプロイエラー

```bash
# ビルドエラーの確認
npm run build

# lint エラーの確認
npm run lint
```

### Permission denied エラー

Cloud Scheduler のサービスアカウントに権限を付与:

```bash
gcloud projects add-iam-policy-binding imane-production \
  --member=serviceAccount:service-{PROJECT_NUMBER}@gcp-sa-cloudscheduler.iam.gserviceaccount.com \
  --role=roles/cloudscheduler.jobRunner
```

### 削除されない

1. `auto_delete_at` フィールドが正しく設定されているか確認
2. Cloud Scheduler が正常に動作しているか確認
3. ログにエラーがないか確認

## 📚 参考資料

- [Cloud Functions for Firebase](https://firebase.google.com/docs/functions)
- [Cloud Scheduler](https://cloud.google.com/scheduler/docs)
- [Firebase Admin SDK](https://firebase.google.com/docs/reference/admin/node)
