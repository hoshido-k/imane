"""
データクリーンアップサービス

24時間TTL付きデータの自動削除と、期限切れスケジュールの管理を行います。
"""

import logging
from datetime import UTC, datetime

from app.core.firebase import get_firestore_client
from app.services.auto_notification import AutoNotificationService
from app.services.location import LocationService

logger = logging.getLogger(__name__)


class CleanupService:
    """データクリーンアップサービスクラス"""

    def __init__(self):
        self.db = get_firestore_client()
        self.location_service = LocationService()
        self.notification_service = AutoNotificationService()

    async def cleanup_expired_data(self) -> dict:
        """
        期限切れデータを一括削除

        Returns:
            削除結果の辞書 {
                "location_history": 削除件数,
                "notification_history": 削除件数,
                "expired_schedules": 削除件数
            }
        """
        results = {}

        # 位置情報履歴のクリーンアップ
        location_count = await self.location_service.cleanup_old_locations()
        results["location_history"] = location_count
        logger.info(f"位置情報履歴を削除: {location_count}件")

        # 通知履歴のクリーンアップ
        notification_count = await self.notification_service.cleanup_old_notification_history()
        results["notification_history"] = notification_count
        logger.info(f"通知履歴を削除: {notification_count}件")

        # 期限切れスケジュールのクリーンアップ
        schedule_count = await self.cleanup_expired_schedules()
        results["expired_schedules"] = schedule_count
        logger.info(f"期限切れスケジュールを削除: {schedule_count}件")

        total = sum(results.values())
        logger.info(f"クリーンアップ完了: 合計 {total}件のデータを削除しました")

        return results

    async def cleanup_expired_schedules(self) -> int:
        """
        終了時刻から24時間経過したスケジュールを削除

        Returns:
            削除した件数
        """
        now = datetime.now(UTC)

        # 終了時刻が現在時刻より24時間以上前のスケジュールを取得
        # ただし、statusがexpiredまたはcompletedのもののみ
        query = self.db.collection("schedules").where("end_time", "<", now)

        deleted_count = 0
        for doc in query.stream():
            schedule_data = doc.to_dict()

            # end_timeから24時間経過しているかチェック
            end_time = schedule_data.get("end_time")
            if not end_time:
                continue

            # 24時間経過しているか判定
            time_since_end = now - end_time
            hours_since_end = time_since_end.total_seconds() / 3600

            if hours_since_end >= 24:
                # 関連する位置情報履歴も削除
                await self._delete_related_location_history(schedule_data.get("id"))

                # 関連する通知履歴も削除
                await self._delete_related_notification_history(schedule_data.get("id"))

                # スケジュールを削除
                doc.reference.delete()
                deleted_count += 1
                logger.info(
                    f"期限切れスケジュールを削除: {schedule_data.get('id')} "
                    f"(終了: {end_time.strftime('%Y-%m-%d %H:%M')})"
                )

        return deleted_count

    async def _delete_related_location_history(self, schedule_id: str) -> int:
        """
        スケジュールに関連する位置情報履歴を削除

        Args:
            schedule_id: スケジュールID

        Returns:
            削除した件数
        """
        if not schedule_id:
            return 0

        query = self.db.collection("location_history").where("schedule_id", "==", schedule_id)

        deleted_count = 0
        for doc in query.stream():
            doc.reference.delete()
            deleted_count += 1

        return deleted_count

    async def _delete_related_notification_history(self, schedule_id: str) -> int:
        """
        スケジュールに関連する通知履歴を削除

        Args:
            schedule_id: スケジュールID

        Returns:
            削除した件数
        """
        if not schedule_id:
            return 0

        query = self.db.collection("notification_history").where("schedule_id", "==", schedule_id)

        deleted_count = 0
        for doc in query.stream():
            doc.reference.delete()
            deleted_count += 1

        return deleted_count

    async def update_expired_schedules_status(self) -> int:
        """
        終了時刻 + 24時間を過ぎたスケジュールのステータスをEXPIREDに更新

        退出通知が送信されないまま24時間経過したスケジュールを無効化します。

        Returns:
            更新した件数
        """
        from datetime import timedelta

        now = datetime.now(UTC)

        # end_time + 24時間前の時刻を計算
        cutoff_time = now - timedelta(hours=24)

        # 終了時刻がcutoff_timeより前で、statusがactiveまたはarrivedのスケジュールを取得
        query_active = (
            self.db.collection("schedules")
            .where("end_time", "<", cutoff_time)
            .where("status", "==", "active")
        )

        query_arrived = (
            self.db.collection("schedules")
            .where("end_time", "<", cutoff_time)
            .where("status", "==", "arrived")
        )

        updated_count = 0

        # activeスケジュールを更新
        for doc in query_active.stream():
            schedule_data = doc.to_dict()
            end_time = schedule_data.get("end_time")
            doc.reference.update({"status": "expired", "updated_at": now})
            updated_count += 1
            logger.info(
                f"[期限切れ] スケジュールステータスをEXPIREDに更新: {doc.id} "
                f"(end_time: {end_time}, 24時間経過)"
            )

        # arrivedスケジュールを更新
        for doc in query_arrived.stream():
            schedule_data = doc.to_dict()
            end_time = schedule_data.get("end_time")
            doc.reference.update({"status": "expired", "updated_at": now})
            updated_count += 1
            logger.info(
                f"[期限切れ] スケジュールステータスをEXPIREDに更新: {doc.id} "
                f"(end_time: {end_time}, 24時間経過、退出通知未送信)"
            )

        if updated_count > 0:
            logger.info(f"[期限切れ] スケジュールのステータス更新完了: {updated_count}件")

        return updated_count

    async def get_cleanup_stats(self) -> dict:
        """
        クリーンアップ対象データの統計情報を取得

        Returns:
            統計情報の辞書
        """
        now = datetime.now(UTC)

        # 削除対象の位置情報履歴数
        location_query = self.db.collection("location_history").where("auto_delete_at", "<=", now)
        location_count = len(list(location_query.stream()))

        # 削除対象の通知履歴数
        notification_query = self.db.collection("notification_history").where(
            "auto_delete_at", "<=", now
        )
        notification_count = len(list(notification_query.stream()))

        # 期限切れスケジュール数
        expired_schedules_query = self.db.collection("schedules").where("end_time", "<", now)
        expired_schedules = []
        for doc in expired_schedules_query.stream():
            schedule_data = doc.to_dict()
            end_time = schedule_data.get("end_time")
            if end_time:
                time_since_end = now - end_time
                hours_since_end = time_since_end.total_seconds() / 3600
                if hours_since_end >= 24:
                    expired_schedules.append(schedule_data)

        return {
            "location_history_count": location_count,
            "notification_history_count": notification_count,
            "expired_schedules_count": len(expired_schedules),
            "total_cleanup_items": location_count + notification_count + len(expired_schedules),
        }
