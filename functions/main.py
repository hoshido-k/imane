"""
Cloud Functions for Firebase - ポップ自動削除機能

スケジュール実行により期限切れのポップを自動的に削除します。
"""

import logging
from datetime import datetime, timedelta, timezone

import firebase_admin
from firebase_admin import credentials, firestore
from firebase_functions import scheduler_fn

# 日本標準時（JST = UTC+9）
JST = timezone(timedelta(hours=9), "JST")

# Firebase初期化
if not firebase_admin._apps:
    firebase_admin.initialize_app()

# ロガー設定
logger = logging.getLogger(__name__)


@scheduler_fn.on_schedule(schedule="every 5 minutes")
def delete_expired_pops(event: scheduler_fn.ScheduledEvent) -> None:
    """
    期限切れポップの自動削除関数

    5分ごとに実行され、expires_at が現在時刻を過ぎているポップを
    論理削除（is_active=False）に設定します。

    Args:
        event: スケジュールイベント
    """
    try:
        db = firestore.client()
        now = datetime.now(JST)

        logger.info(f"Starting expired pops deletion at {now.isoformat()}")

        # 期限切れかつアクティブなポップを検索
        pops_ref = db.collection("pops")
        query = (
            pops_ref.where("is_active", "==", True)
            .where("expires_at", "<=", now)
        )

        expired_pops = query.stream()
        deleted_count = 0

        # バッチ処理で効率的に更新
        batch = db.batch()
        batch_count = 0

        for pop_doc in expired_pops:
            pop_ref = pops_ref.document(pop_doc.id)
            batch.update(
                pop_ref,
                {
                    "is_active": False,
                    "deleted_at": now,
                    "auto_deleted": True,  # 自動削除フラグ
                },
            )
            deleted_count += 1
            batch_count += 1

            # Firestoreのバッチ制限は500件
            if batch_count >= 500:
                batch.commit()
                batch = db.batch()
                batch_count = 0

        # 残りのバッチをコミット
        if batch_count > 0:
            batch.commit()

        logger.info(f"Successfully deleted {deleted_count} expired pops")

    except Exception as e:
        logger.error(f"Error deleting expired pops: {str(e)}", exc_info=True)
        raise


@scheduler_fn.on_schedule(schedule="every 1 hours")
def cleanup_old_deleted_pops(event: scheduler_fn.ScheduledEvent) -> None:
    """
    古い削除済みポップの物理削除関数

    1時間ごとに実行され、削除されてから24時間以上経過した
    ポップをFirestoreから完全に削除します（ストレージ容量削減のため）。

    Args:
        event: スケジュールイベント
    """
    try:
        db = firestore.client()
        now = datetime.now(JST)

        # 24時間前の時刻を計算
        cutoff_time = now - timedelta(hours=24)

        logger.info(
            f"Starting cleanup of old deleted pops (before {cutoff_time.isoformat()})"
        )

        # 24時間以上前に削除されたポップを検索
        pops_ref = db.collection("pops")
        query = (
            pops_ref.where("is_active", "==", False)
            .where("deleted_at", "<=", cutoff_time)
        )

        old_pops = query.stream()
        deleted_count = 0

        # バッチ処理で効率的に削除
        batch = db.batch()
        batch_count = 0

        for pop_doc in old_pops:
            pop_ref = pops_ref.document(pop_doc.id)
            batch.delete(pop_ref)
            deleted_count += 1
            batch_count += 1

            # Firestoreのバッチ制限は500件
            if batch_count >= 500:
                batch.commit()
                batch = db.batch()
                batch_count = 0

        # 残りのバッチをコミット
        if batch_count > 0:
            batch.commit()

        logger.info(f"Successfully cleaned up {deleted_count} old deleted pops")

    except Exception as e:
        logger.error(f"Error cleaning up old deleted pops: {str(e)}", exc_info=True)
        raise
