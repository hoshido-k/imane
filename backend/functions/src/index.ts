import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

// Firebase Admin SDK 初期化
admin.initializeApp();

const db = admin.firestore();

/**
 * 削除結果の型定義
 */
interface CleanupResult {
  success: boolean;
  deleted: {
    locationHistory: number;
    notificationHistory: number;
    schedules: number;
  };
  timestamp: string;
  errors?: string[];
}

/**
 * 24時間経過したデータを自動削除する定期実行関数
 * 実行間隔: 1時間ごと
 * タイムゾーン: Asia/Tokyo
 */
export const cleanupExpiredData = functions
  .region("asia-northeast1")
  .pubsub
  .schedule("every 1 hours")
  .timeZone("Asia/Tokyo")
  .onRun(async (context) => {
    console.log("Starting scheduled cleanup at:", new Date().toISOString());

    try {
      const result = await performCleanup();
      console.log("Cleanup completed successfully:", result);
      return result;
    } catch (error) {
      console.error("Error during scheduled cleanup:", error);
      throw error;
    }
  });

/**
 * 手動実行用のHTTPエンドポイント（テスト用）
 * BATCH_TOKEN による認証が必要
 */
export const manualCleanup = functions
  .region("asia-northeast1")
  .https
  .onRequest(async (req, res) => {
    console.log("Manual cleanup request received");

    // BATCH_TOKEN による認証
    const authHeader = req.headers.authorization;
    const expectedToken = functions.config().batch?.token ||
                         process.env.BATCH_TOKEN;

    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      console.warn("Missing or invalid authorization header");
      res.status(401).json({error: "Unauthorized: Missing bearer token"});
      return;
    }

    const providedToken = authHeader.substring(7); // "Bearer " を除去

    if (providedToken !== expectedToken) {
      console.warn("Invalid batch token provided");
      res.status(401).json({error: "Unauthorized: Invalid token"});
      return;
    }

    try {
      const result = await performCleanup();
      console.log("Manual cleanup completed:", result);
      res.status(200).json(result);
    } catch (error) {
      console.error("Manual cleanup error:", error);
      res.status(500).json({
        error: "Internal Server Error",
        message: error instanceof Error ? error.message : "Unknown error",
      });
    }
  });

/**
 * クリーンアップロジック（共通化）
 *
 * 削除対象:
 * 1. location_history: auto_delete_at が現在時刻より前
 * 2. notification_history: auto_delete_at が現在時刻より前
 * 3. schedules: status=expired かつ end_time から24時間経過
 */
async function performCleanup(): Promise<CleanupResult> {
  const now = admin.firestore.Timestamp.now();
  const deletedCounts = {
    locationHistory: 0,
    notificationHistory: 0,
    schedules: 0,
  };
  const errors: string[] = [];

  // 1. location_history の削除
  try {
    console.log("Cleaning up location_history...");
    const locationHistoryCount = await cleanupCollection(
      "location_history",
      "auto_delete_at",
      now
    );
    deletedCounts.locationHistory = locationHistoryCount;
    console.log(`Deleted ${locationHistoryCount} location_history records`);
  } catch (error) {
    const errorMsg = `Failed to cleanup location_history: ${error}`;
    console.error(errorMsg);
    errors.push(errorMsg);
  }

  // 2. notification_history の削除
  try {
    console.log("Cleaning up notification_history...");
    const notificationHistoryCount = await cleanupCollection(
      "notification_history",
      "auto_delete_at",
      now
    );
    deletedCounts.notificationHistory = notificationHistoryCount;
    console.log(`Deleted ${notificationHistoryCount} notification_history records`);
  } catch (error) {
    const errorMsg = `Failed to cleanup notification_history: ${error}`;
    console.error(errorMsg);
    errors.push(errorMsg);
  }

  // 3. 期限切れスケジュールの削除
  try {
    console.log("Cleaning up expired schedules...");
    const twentyFourHoursAgo = new Date(
      now.toDate().getTime() - 24 * 60 * 60 * 1000
    );
    const schedulesCount = await cleanupExpiredSchedules(twentyFourHoursAgo);
    deletedCounts.schedules = schedulesCount;
    console.log(`Deleted ${schedulesCount} expired schedules`);
  } catch (error) {
    const errorMsg = `Failed to cleanup schedules: ${error}`;
    console.error(errorMsg);
    errors.push(errorMsg);
  }

  const result: CleanupResult = {
    success: errors.length === 0,
    deleted: deletedCounts,
    timestamp: now.toDate().toISOString(),
  };

  if (errors.length > 0) {
    result.errors = errors;
  }

  return result;
}

/**
 * 指定されたコレクションから期限切れドキュメントを削除
 *
 * @param collectionName - コレクション名
 * @param fieldName - 削除判定に使うフィールド名
 * @param threshold - しきい値（この時刻より前のドキュメントを削除）
 * @returns 削除したドキュメント数
 */
async function cleanupCollection(
  collectionName: string,
  fieldName: string,
  threshold: admin.firestore.Timestamp
): Promise<number> {
  const BATCH_SIZE = 500;
  let totalDeleted = 0;

  // 複数バッチで削除する可能性があるため、ループ処理
  // eslint-disable-next-line no-constant-condition
  while (true) {
    const query = db
      .collection(collectionName)
      .where(fieldName, "<=", threshold)
      .limit(BATCH_SIZE);

    const snapshot = await query.get();

    if (snapshot.empty) {
      break;
    }

    const batch = db.batch();
    snapshot.docs.forEach((doc) => {
      batch.delete(doc.ref);
    });

    await batch.commit();
    totalDeleted += snapshot.size;

    console.log(
      `Deleted ${snapshot.size} documents from ${collectionName} ` +
      `(total: ${totalDeleted})`
    );

    // 一度に500件以上ある場合は次のバッチへ
    if (snapshot.size < BATCH_SIZE) {
      break;
    }
  }

  return totalDeleted;
}

/**
 * 期限切れスケジュールを削除
 *
 * status=expired かつ end_time から24時間経過したスケジュールを削除
 *
 * @param twentyFourHoursAgo - 24時間前の時刻
 * @returns 削除したスケジュール数
 */
async function cleanupExpiredSchedules(
  twentyFourHoursAgo: Date
): Promise<number> {
  const BATCH_SIZE = 500;
  let totalDeleted = 0;

  const threshold = admin.firestore.Timestamp.fromDate(twentyFourHoursAgo);

  // eslint-disable-next-line no-constant-condition
  while (true) {
    const query = db
      .collection("schedules")
      .where("status", "==", "expired")
      .where("end_time", "<=", threshold)
      .limit(BATCH_SIZE);

    const snapshot = await query.get();

    if (snapshot.empty) {
      break;
    }

    const batch = db.batch();
    snapshot.docs.forEach((doc) => {
      batch.delete(doc.ref);
    });

    await batch.commit();
    totalDeleted += snapshot.size;

    console.log(
      `Deleted ${snapshot.size} expired schedules ` +
      `(total: ${totalDeleted})`
    );

    if (snapshot.size < BATCH_SIZE) {
      break;
    }
  }

  return totalDeleted;
}
