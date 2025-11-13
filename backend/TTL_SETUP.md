# imane TTL（自動削除）設定ガイド

**Version:** 1.0.0
**最終更新:** 2025-11-13

Firestoreのデータを24時間後に自動削除するための設定手順。

---

## 📋 概要

imaneでは、プライバシー保護のため以下のデータを自動削除します:

- **location_history**: 24時間後に削除
- **notification_history**: 24時間後に削除
- **schedules**: `status=expired` かつ終了時刻から24時間後に削除

FirestoreにはネイティブなTTL機能がないため、**Cloud Functions + Cloud Scheduler** で実装します。

---

## 方法1: Cloud Functions for Firebase（推奨）

### メリット
- ✅ Firebase CLI で簡単にデプロイ
- ✅ TypeScript/JavaScript で実装
- ✅ ローカルテスト可能
- ✅ Firebase Emulator でテスト可能

### デメリット
- ❌ Node.js のランタイム必要
- ❌ Cold start がある（初回実行が遅い）

---

## 方法2: Python Cloud Functions（バックエンドと統一）

### メリット
- ✅ バックエンドと同じPythonで実装
- ✅ 既存のFirebase Admin SDKコードを再利用可能
- ✅ 型ヒントでコードが読みやすい

### デメリット
- ❌ Firebase CLI ではなく gcloud CLI でデプロイ
- ❌ セットアップが少し複雑

---

## 推奨: 方法1（Cloud Functions for Firebase）

Node.js/TypeScriptで実装する方が、Firebaseとの統合が簡単です。

---

## 🚀 セットアップ手順（Cloud Functions for Firebase）

### ステップ1: Firebase Functions の初期化

```bash
cd backend

# Firebase Functions をセットアップ
firebase init functions
```

**選択肢**:
- Language: **TypeScript** (推奨)
- ESLint: Yes
- Install dependencies: Yes

これで以下のディレクトリ構成が作成されます:

```
backend/
├── functions/
│   ├── src/
│   │   └── index.ts        # Cloud Functions のエントリーポイント
│   ├── package.json
│   ├── tsconfig.json
│   └── .eslintrc.js
├── firebase.json
└── .firebaserc
```

---

### ステップ2: TTL削除関数の実装

`functions/src/index.ts` を以下のように編集:

```typescript
import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

// Firebase Admin SDK 初期化
admin.initializeApp();

const db = admin.firestore();

/**
 * 24時間経過したデータを自動削除する定期実行関数
 * 実行間隔: 1時間ごと
 */
export const cleanupExpiredData = functions.pubsub
  .schedule("every 1 hours")
  .timeZone("Asia/Tokyo")
  .onRun(async (context) => {
    const now = admin.firestore.Timestamp.now();
    const deletedCounts = {
      locationHistory: 0,
      notificationHistory: 0,
      schedules: 0,
    };

    try {
      // 1. location_history の削除
      const locationHistoryQuery = db
        .collection("location_history")
        .where("auto_delete_at", "<=", now)
        .limit(500); // 一度に500件まで削除

      const locationHistorySnapshot = await locationHistoryQuery.get();

      if (!locationHistorySnapshot.empty) {
        const batch = db.batch();
        locationHistorySnapshot.docs.forEach((doc) => {
          batch.delete(doc.ref);
          deletedCounts.locationHistory++;
        });
        await batch.commit();
        console.log(`Deleted ${deletedCounts.locationHistory} location_history records`);
      }

      // 2. notification_history の削除
      const notificationHistoryQuery = db
        .collection("notification_history")
        .where("auto_delete_at", "<=", now)
        .limit(500);

      const notificationHistorySnapshot = await notificationHistoryQuery.get();

      if (!notificationHistorySnapshot.empty) {
        const batch = db.batch();
        notificationHistorySnapshot.docs.forEach((doc) => {
          batch.delete(doc.ref);
          deletedCounts.notificationHistory++;
        });
        await batch.commit();
        console.log(`Deleted ${deletedCounts.notificationHistory} notification_history records`);
      }

      // 3. 期限切れスケジュールの削除
      // end_time から24時間経過した expired スケジュールを削除
      const twentyFourHoursAgo = new Date(now.toDate().getTime() - 24 * 60 * 60 * 1000);

      const schedulesQuery = db
        .collection("schedules")
        .where("status", "==", "expired")
        .where("end_time", "<=", admin.firestore.Timestamp.fromDate(twentyFourHoursAgo))
        .limit(500);

      const schedulesSnapshot = await schedulesQuery.get();

      if (!schedulesSnapshot.empty) {
        const batch = db.batch();
        schedulesSnapshot.docs.forEach((doc) => {
          batch.delete(doc.ref);
          deletedCounts.schedules++;
        });
        await batch.commit();
        console.log(`Deleted ${deletedCounts.schedules} expired schedules`);
      }

      console.log("Cleanup completed successfully:", deletedCounts);

      return {
        success: true,
        deleted: deletedCounts,
        timestamp: now.toDate().toISOString(),
      };
    } catch (error) {
      console.error("Error during cleanup:", error);
      throw error;
    }
  });

/**
 * 手動実行用のHTTPエンドポイント（テスト用）
 * 認証トークンが必要
 */
export const manualCleanup = functions.https.onRequest(async (req, res) => {
  // BATCH_TOKEN による認証
  const authHeader = req.headers.authorization;
  const expectedToken = functions.config().batch?.token || process.env.BATCH_TOKEN;

  if (!authHeader || authHeader !== `Bearer ${expectedToken}`) {
    res.status(401).send("Unauthorized");
    return;
  }

  try {
    // cleanupExpiredData と同じロジックを実行
    const result = await cleanupExpiredDataLogic();
    res.status(200).json(result);
  } catch (error) {
    console.error("Manual cleanup error:", error);
    res.status(500).send("Internal Server Error");
  }
});

/**
 * クリーンアップロジック（共通化）
 */
async function cleanupExpiredDataLogic() {
  const now = admin.firestore.Timestamp.now();
  const deletedCounts = {
    locationHistory: 0,
    notificationHistory: 0,
    schedules: 0,
  };

  // location_history の削除
  const locationHistoryQuery = db
    .collection("location_history")
    .where("auto_delete_at", "<=", now)
    .limit(500);

  const locationHistorySnapshot = await locationHistoryQuery.get();

  if (!locationHistorySnapshot.empty) {
    const batch = db.batch();
    locationHistorySnapshot.docs.forEach((doc) => {
      batch.delete(doc.ref);
      deletedCounts.locationHistory++;
    });
    await batch.commit();
  }

  // notification_history の削除
  const notificationHistoryQuery = db
    .collection("notification_history")
    .where("auto_delete_at", "<=", now)
    .limit(500);

  const notificationHistorySnapshot = await notificationHistoryQuery.get();

  if (!notificationHistorySnapshot.empty) {
    const batch = db.batch();
    notificationHistorySnapshot.docs.forEach((doc) => {
      batch.delete(doc.ref);
      deletedCounts.notificationHistory++;
    });
    await batch.commit();
  }

  // 期限切れスケジュールの削除
  const twentyFourHoursAgo = new Date(now.toDate().getTime() - 24 * 60 * 60 * 1000);

  const schedulesQuery = db
    .collection("schedules")
    .where("status", "==", "expired")
    .where("end_time", "<=", admin.firestore.Timestamp.fromDate(twentyFourHoursAgo))
    .limit(500);

  const schedulesSnapshot = await schedulesQuery.get();

  if (!schedulesSnapshot.empty) {
    const batch = db.batch();
    schedulesSnapshot.docs.forEach((doc) => {
      batch.delete(doc.ref);
      deletedCounts.schedules++;
    });
    await batch.commit();
  }

  return {
    success: true,
    deleted: deletedCounts,
    timestamp: now.toDate().toISOString(),
  };
}
```

---

### ステップ3: 依存関係の追加

`functions/package.json` に必要な依存関係が含まれているか確認:

```json
{
  "name": "functions",
  "scripts": {
    "build": "tsc",
    "serve": "npm run build && firebase emulators:start --only functions",
    "shell": "npm run build && firebase functions:shell",
    "deploy": "firebase deploy --only functions",
    "logs": "firebase functions:log"
  },
  "engines": {
    "node": "18"
  },
  "main": "lib/index.js",
  "dependencies": {
    "firebase-admin": "^12.0.0",
    "firebase-functions": "^5.0.0"
  },
  "devDependencies": {
    "@typescript-eslint/eslint-plugin": "^5.12.0",
    "@typescript-eslint/parser": "^5.12.0",
    "eslint": "^8.9.0",
    "typescript": "^4.9.0"
  }
}
```

依存関係をインストール:

```bash
cd functions
npm install
```

---

### ステップ4: ローカルテスト（エミュレータ）

```bash
cd backend

# Firebase Emulator を起動
firebase emulators:start

# または Functions のみ起動
firebase emulators:start --only functions
```

エミュレータが起動したら、手動実行エンドポイントをテスト:

```bash
# BATCH_TOKEN を環境変数に設定
export BATCH_TOKEN="your-batch-token-here"

# 手動クリーンアップをテスト
curl -X POST \
  http://localhost:5001/imane-production/us-central1/manualCleanup \
  -H "Authorization: Bearer $BATCH_TOKEN"
```

---

### ステップ5: 環境変数の設定

Cloud Functions に環境変数を設定:

```bash
# BATCH_TOKEN を設定
firebase functions:config:set batch.token="YOUR_STRONG_RANDOM_TOKEN"

# 設定を確認
firebase functions:config:get
```

---

### ステップ6: デプロイ

#### 開発環境にデプロイ

```bash
firebase use dev
firebase deploy --only functions
```

#### 本番環境にデプロイ

```bash
firebase use prod
firebase deploy --only functions
```

デプロイ後、Firebase Console で確認:
- Firebase Console > Functions
- `cleanupExpiredData` が表示されていることを確認

---

### ステップ7: Cloud Scheduler の確認

`schedule("every 1 hours")` を使用すると、Cloud Scheduler が自動的に作成されます。

確認方法:
1. Google Cloud Console > Cloud Scheduler
2. `firebase-schedule-cleanupExpiredData-{region}` というジョブが作成されている
3. スケジュール: `every 1 hours`
4. タイムゾーン: `Asia/Tokyo`

手動実行してテスト:
```bash
# Cloud Scheduler から手動実行
gcloud scheduler jobs run firebase-schedule-cleanupExpiredData-us-central1
```

---

## 📊 モニタリング

### ログの確認

```bash
# 最新のログを表示
firebase functions:log

# 特定の関数のログのみ表示
firebase functions:log --only cleanupExpiredData

# リアルタイムでログを監視
firebase functions:log --follow
```

### Firebase Console でのモニタリング

1. Firebase Console > Functions > `cleanupExpiredData`
2. タブ: ログ、使用量、詳細
3. 確認項目:
   - 実行回数
   - エラー率
   - 実行時間
   - メモリ使用量

---

## 💰 コスト見積もり

### Cloud Functions の料金

**無料枠** (月間):
- 呼び出し: 200万回
- コンピューティング時間: 40万GB秒
- 送信ネットワーク: 5GB

**想定コスト**:
- 実行頻度: 1時間に1回 = 720回/月
- 実行時間: 約5秒/回
- メモリ: 256MB

→ **無料枠内に収まる**

### Cloud Scheduler の料金

- 無料枠: 月3ジョブまで無料
- imaneでは1ジョブのみ使用

→ **無料**

---

## 🔧 トラブルシューティング

### エラー: "Permission denied"

**原因**: Cloud Scheduler が Cloud Functions を呼び出す権限がない

**解決策**:
```bash
# Cloud Scheduler サービスアカウントに権限を付与
gcloud projects add-iam-policy-binding imane-production \
  --member=serviceAccount:service-{PROJECT_NUMBER}@gcp-sa-cloudscheduler.iam.gserviceaccount.com \
  --role=roles/cloudscheduler.jobRunner
```

### エラー: "Quota exceeded"

**原因**: 一度に500件以上のドキュメントを削除しようとしている

**解決策**:
- `limit(500)` を調整
- バッチ処理を複数回実行するロジックに変更

### 削除されない

**確認項目**:
1. `auto_delete_at` フィールドが正しく設定されているか
2. Cloud Scheduler が正常に動作しているか
3. Cloud Functions のログにエラーがないか

```bash
# Firestoreで確認
firebase firestore:get location_history/{doc_id}

# ログ確認
firebase functions:log --only cleanupExpiredData
```

---

## 🧪 テスト方法

### 1. ローカルでのテスト

```bash
# エミュレータ起動
firebase emulators:start

# テストデータを作成
# Firestoreに auto_delete_at が過去の日時のドキュメントを追加

# 手動実行
curl -X POST http://localhost:5001/.../manualCleanup \
  -H "Authorization: Bearer test-token"
```

### 2. 本番環境での手動テスト

```bash
# Cloud Functions URL を取得
firebase functions:list

# 手動実行（BATCH_TOKEN必要）
curl -X POST https://us-central1-imane-production.cloudfunctions.net/manualCleanup \
  -H "Authorization: Bearer YOUR_BATCH_TOKEN"
```

---

## 📝 ベストプラクティス

1. **バッチサイズを制限**
   - 一度に削除するドキュメント数を500件以下に制限
   - タイムアウトを防ぐため

2. **ログを残す**
   - 削除件数をログに記録
   - エラー時の調査に役立つ

3. **タイムゾーンを明示**
   - `timeZone("Asia/Tokyo")` で日本時間に統一

4. **冪等性を確保**
   - 同じ関数を複数回実行しても安全
   - `auto_delete_at <= now` の条件で実現

5. **手動実行エンドポイントを用意**
   - テスト用
   - 緊急時の手動クリーンアップ用

---

## 🔄 代替案: Firestore TTL (Experimental)

Google Cloud Firestore には実験的なTTL機能があります（2024年時点）。

```bash
# TTL フィールドを設定（beta機能）
gcloud firestore fields ttls update auto_delete_at \
  --collection-group=location_history \
  --database=(default)
```

**メリット**:
- Cloud Functions 不要
- 自動的に削除される

**デメリット**:
- ❌ Beta機能（本番利用非推奨）
- ❌ 削除タイミングが不定（最大72時間遅れる可能性）
- ❌ 削除ログが残らない

→ 現時点では**Cloud Functions を推奨**

---

## 📚 参考資料

- [Cloud Functions for Firebase](https://firebase.google.com/docs/functions)
- [Cloud Scheduler](https://cloud.google.com/scheduler/docs)
- [Firebase Admin SDK (Node.js)](https://firebase.google.com/docs/reference/admin/node)
- [Firestore Batch Writes](https://firebase.google.com/docs/firestore/manage-data/transactions#batched-writes)

---

**最終更新日**: 2025-11-13
**バージョン**: 1.0.0
