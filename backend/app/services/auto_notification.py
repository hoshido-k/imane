"""
自動通知サービス

ジオフェンスイベントに基づいて、自動的に通知を送信します。
「今ね、」形式のメッセージで、到着・滞在・退出通知を行います。
"""

import logging
import uuid
from datetime import datetime, timedelta
from typing import List

from app.config import settings
from app.core.firebase import get_firestore_client
from app.schemas.common import Coordinates
from app.schemas.notification import NotificationHistoryInDB, NotificationType
from app.schemas.schedule import LocationScheduleInDB
from app.services.notifications import NotificationService
from app.services.users import UserService
from app.utils.timezone import JST, now_jst

logger = logging.getLogger(__name__)


class AutoNotificationService:
    """自動通知サービスクラス"""

    def __init__(self):
        self.db = get_firestore_client()
        self.notification_service = NotificationService()
        self.user_service = UserService()
        self.notification_history_collection = "notification_history"

    def _generate_map_link(self, coords: Coordinates) -> str:
        """
        Google Mapsのリンクを生成

        Args:
            coords: 座標

        Returns:
            Google Mapsのリンク
        """
        return f"https://www.google.com/maps?q={coords.lat},{coords.lng}"

    def _shorten_location_name(self, location_name: str, max_length: int = 15) -> str:
        """
        場所名を短縮（通知タイトル用）

        Args:
            location_name: 元の場所名
            max_length: 最大文字数（デフォルト15文字）

        Returns:
            短縮された場所名
        """
        if len(location_name) <= max_length:
            return location_name
        return location_name[:max_length] + "..."

    def _format_arrival_message(self, user_name: str) -> str:
        """
        到着通知メッセージをフォーマット

        Args:
            user_name: ユーザー名

        Returns:
            フォーマットされたメッセージ
        """
        return f"今ね、{user_name}さんが到着したよ"

    def _format_stay_message(
        self, user_name: str, stay_duration_minutes: int
    ) -> str:
        """
        滞在通知メッセージをフォーマット

        Args:
            user_name: ユーザー名
            stay_duration_minutes: 滞在時間（分）

        Returns:
            フォーマットされたメッセージ
        """
        hours = stay_duration_minutes // 60
        minutes = stay_duration_minutes % 60

        if hours > 0 and minutes > 0:
            duration_str = f"{hours}時間{minutes}分"
        elif hours > 0:
            duration_str = f"{hours}時間"
        else:
            duration_str = f"{minutes}分"

        return f"今ね、{user_name}さんが{duration_str}滞在中だよ"

    def _format_departure_message(self, user_name: str) -> str:
        """
        退出通知メッセージをフォーマット

        Args:
            user_name: ユーザー名

        Returns:
            フォーマットされたメッセージ
        """
        return f"今ね、{user_name}さんが出発したよ"

    async def _save_notification_history(
        self,
        from_user_id: str,
        to_user_id: str,
        schedule_id: str,
        notification_type: str,
        message: str,
        map_link: str,
    ) -> NotificationHistoryInDB:
        """
        通知履歴を保存（24時間TTL）

        Args:
            from_user_id: 送信元ユーザID
            to_user_id: 送信先ユーザID
            schedule_id: スケジュールID
            notification_type: 通知タイプ（arrival/stay/departure）
            message: メッセージ
            map_link: 地図リンク

        Returns:
            保存された通知履歴
        """
        history_id = str(uuid.uuid4())
        now = now_jst()
        auto_delete_at = now + timedelta(hours=settings.DATA_RETENTION_HOURS)

        history_dict = {
            "id": history_id,
            "from_user_id": from_user_id,
            "to_user_id": to_user_id,
            "schedule_id": schedule_id,
            "type": notification_type,
            "message": message,
            "map_link": map_link,
            "sent_at": now,
            "auto_delete_at": auto_delete_at,
        }

        logger.info(
            f"[通知履歴] notification_historyコレクションに保存中: "
            f"history_id={history_id}, type={notification_type}, "
            f"from={from_user_id} -> to={to_user_id}"
        )

        history_ref = self.db.collection(self.notification_history_collection).document(history_id)
        history_ref.set(history_dict)

        logger.info(f"[通知履歴] 保存完了: history_id={history_id}")

        return NotificationHistoryInDB(**history_dict)

    async def send_arrival_notification(
        self, schedule: LocationScheduleInDB, current_coords: Coordinates
    ) -> List[str]:
        """
        到着通知を送信

        Args:
            schedule: スケジュール情報
            current_coords: 現在の座標

        Returns:
            送信した通知のIDリスト
        """
        logger.info(
            f"[到着通知] スケジュール {schedule.id} の処理開始: "
            f"通知先={len(schedule.notify_to_user_ids)}人, "
            f"到着通知有効={schedule.notify_on_arrival}"
        )

        # 到着通知が無効の場合はスキップ
        if not schedule.notify_on_arrival:
            logger.warning(f"[到着通知] スケジュール {schedule.id}: 到着通知は無効です")
            return []

        # 通知先が空の場合は警告
        if not schedule.notify_to_user_ids:
            logger.warning(
                f"[到着通知] スケジュール {schedule.id}: "
                f"通知先ユーザーIDが空です。通知先を設定してください。"
            )
            return []

        # ユーザー情報を取得
        user = await self.user_service.get_user_by_uid(schedule.user_id)
        if not user:
            logger.error(f"[到着通知] ユーザーが見つかりません: {schedule.user_id}")
            return []

        user_name = user.display_name or user.username
        logger.info(f"[到着通知] 送信者: {user_name} ({schedule.user_id})")

        # メッセージと地図リンクを生成
        message = self._format_arrival_message(user_name)
        map_link = self._generate_map_link(current_coords)
        short_location = self._shorten_location_name(schedule.destination_name)

        notification_ids = []

        # 通知先ユーザーに送信
        for to_user_id in schedule.notify_to_user_ids:
            try:
                # ユーザーの通知設定をチェック
                should_send = await self.notification_service.should_send_notification(
                    to_user_id, NotificationType.ARRIVAL
                )
                if not should_send:
                    logger.info(
                        f"[到着通知] ユーザー {to_user_id} は到着通知をOFFにしているためスキップ"
                    )
                    continue

                logger.info(f"[到着通知] 通知送信中: {schedule.user_id} -> {to_user_id}")

                # プッシュ通知を送信（save_to_db=Trueで明示的に指定）
                await self.notification_service.send_push_notification(
                    user_id=to_user_id,
                    title=f"📍 {short_location}に到着",
                    body=message + f"\nここにいるよ → {map_link}",
                    notification_type=NotificationType.ARRIVAL,
                    data={
                        "schedule_id": schedule.id,
                        "from_user_id": schedule.user_id,
                        "destination_name": schedule.destination_name,
                        "map_link": map_link,
                        "coords": {"lat": current_coords.lat, "lng": current_coords.lng},
                    },
                    save_to_db=True,  # 明示的にDB保存を指定
                )

                # 通知履歴を保存（24時間TTL）
                history = await self._save_notification_history(
                    from_user_id=schedule.user_id,
                    to_user_id=to_user_id,
                    schedule_id=schedule.id,
                    notification_type="arrival",
                    message=message,
                    map_link=map_link,
                )
                notification_ids.append(history.id)

                logger.info(
                    f"[到着通知] 送信成功: {schedule.user_id} -> {to_user_id}, "
                    f"履歴ID: {history.id}"
                )

            except Exception as e:
                logger.error(
                    f"[到着通知] 送信失敗: {schedule.user_id} -> {to_user_id}, "
                    f"エラー: {type(e).__name__}: {str(e)}",
                    exc_info=True,
                )

        logger.info(f"[到着通知] 完了: {len(notification_ids)}件の通知を送信しました")
        return notification_ids

    async def send_stay_notification(
        self, schedule: LocationScheduleInDB, current_coords: Coordinates
    ) -> List[str]:
        """
        滞在通知を送信

        Args:
            schedule: スケジュール情報
            current_coords: 現在の座標

        Returns:
            送信した通知のIDリスト
        """
        logger.info(
            f"[滞在通知チェック] スケジュール {schedule.id}: "
            f"到着時刻={schedule.arrived_at}, 通知閾値={schedule.notify_after_minutes}分"
        )

        # 到着していない場合はスキップ
        if not schedule.arrived_at:
            logger.warning(f"[滞在通知] スケジュール {schedule.id}: 到着時刻が記録されていません")
            return []

        # 滞在時間を計算
        now = now_jst()
        stay_duration = now - schedule.arrived_at
        stay_minutes = int(stay_duration.total_seconds() / 60)

        logger.info(
            f"[滞在通知] スケジュール {schedule.id}: 滞在時間={stay_minutes}分"
        )

        # 指定された滞在時間に達していない場合はスキップ
        if stay_minutes < schedule.notify_after_minutes:
            logger.info(
                f"[滞在通知] スケジュール {schedule.id}: 滞在時間が不足 "
                f"({stay_minutes}分 < {schedule.notify_after_minutes}分)"
            )
            return []

        # 既に滞在通知を送信済みかチェック（重複送信防止）
        logger.info(f"[滞在通知] スケジュール {schedule.id}: 既存通知をチェック中...")
        notification_history_query = (
            self.db.collection(self.notification_history_collection)
            .where("schedule_id", "==", schedule.id)
            .where("type", "==", "stay")
        )
        existing_notifications = list(notification_history_query.stream())

        if existing_notifications:
            logger.info(
                f"[滞在通知] スケジュール {schedule.id}: "
                f"既に滞在通知が送信済みです（{len(existing_notifications)}件）。スキップします。"
            )
            return []

        logger.info(f"[滞在通知] スケジュール {schedule.id}: 滞在通知を送信します")

        # ユーザー情報を取得
        user = await self.user_service.get_user_by_uid(schedule.user_id)
        if not user:
            logger.error(f"[滞在通知] ユーザーが見つかりません: {schedule.user_id}")
            return []

        user_name = user.display_name or user.username
        logger.info(f"[滞在通知] 送信者: {user_name} ({schedule.user_id})")

        # メッセージと地図リンクを生成
        message = self._format_stay_message(user_name, stay_minutes)
        map_link = self._generate_map_link(current_coords)
        short_location = self._shorten_location_name(schedule.destination_name)

        notification_ids = []

        # 通知先ユーザーに送信
        for to_user_id in schedule.notify_to_user_ids:
            try:
                # ユーザーの通知設定をチェック
                should_send = await self.notification_service.should_send_notification(
                    to_user_id, NotificationType.STAY
                )
                if not should_send:
                    logger.info(
                        f"[滞在通知] ユーザー {to_user_id} は滞在通知をOFFにしているためスキップ"
                    )
                    continue

                logger.info(f"[滞在通知] 通知送信中: {schedule.user_id} -> {to_user_id}")

                # プッシュ通知を送信（save_to_db=Trueで明示的に指定）
                await self.notification_service.send_push_notification(
                    user_id=to_user_id,
                    title=f"📍 {short_location}で滞在中",
                    body=message + f"\nここにいるよ → {map_link}",
                    notification_type=NotificationType.STAY,
                    data={
                        "schedule_id": schedule.id,
                        "from_user_id": schedule.user_id,
                        "destination_name": schedule.destination_name,
                        "map_link": map_link,
                        "coords": {"lat": current_coords.lat, "lng": current_coords.lng},
                        "stay_duration_minutes": stay_minutes,
                    },
                    save_to_db=True,  # 明示的にDB保存を指定
                )

                # 通知履歴を保存（24時間TTL）
                history = await self._save_notification_history(
                    from_user_id=schedule.user_id,
                    to_user_id=to_user_id,
                    schedule_id=schedule.id,
                    notification_type="stay",
                    message=message,
                    map_link=map_link,
                )
                notification_ids.append(history.id)

                logger.info(
                    f"[滞在通知] 送信成功: {schedule.user_id} -> {to_user_id}, "
                    f"履歴ID: {history.id}"
                )

            except Exception as e:
                logger.error(
                    f"[滞在通知] 送信失敗: {schedule.user_id} -> {to_user_id}, "
                    f"エラー: {type(e).__name__}: {str(e)}",
                    exc_info=True,
                )

        logger.info(f"[滞在通知] 完了: {len(notification_ids)}件の通知を送信しました")
        return notification_ids

    async def send_departure_notification(
        self, schedule: LocationScheduleInDB, current_coords: Coordinates
    ) -> List[str]:
        """
        退出通知を送信

        Args:
            schedule: スケジュール情報
            current_coords: 現在の座標

        Returns:
            送信した通知のIDリスト
        """
        logger.info(
            f"[退出通知] スケジュール {schedule.id} の処理開始: "
            f"通知先={len(schedule.notify_to_user_ids)}人, "
            f"退出通知有効={schedule.notify_on_departure}"
        )

        # 退出通知が無効の場合はスキップ
        if not schedule.notify_on_departure:
            logger.warning(f"[退出通知] スケジュール {schedule.id}: 退出通知は無効です")
            return []

        # 通知先が空の場合は警告
        if not schedule.notify_to_user_ids:
            logger.warning(
                f"[退出通知] スケジュール {schedule.id}: "
                f"通知先ユーザーIDが空です。通知先を設定してください。"
            )
            return []

        # ユーザー情報を取得
        user = await self.user_service.get_user_by_uid(schedule.user_id)
        if not user:
            logger.error(f"[退出通知] ユーザーが見つかりません: {schedule.user_id}")
            return []

        user_name = user.display_name or user.username
        logger.info(f"[退出通知] 送信者: {user_name} ({schedule.user_id})")

        # メッセージを生成（退出通知では現在地リンクは不要）
        message = self._format_departure_message(user_name)
        map_link = self._generate_map_link(schedule.destination_coords)
        short_location = self._shorten_location_name(schedule.destination_name)

        notification_ids = []

        # 通知先ユーザーに送信
        for to_user_id in schedule.notify_to_user_ids:
            try:
                # ユーザーの通知設定をチェック
                should_send = await self.notification_service.should_send_notification(
                    to_user_id, NotificationType.DEPARTURE
                )
                if not should_send:
                    logger.info(
                        f"[退出通知] ユーザー {to_user_id} は退出通知をOFFにしているためスキップ"
                    )
                    continue

                logger.info(f"[退出通知] 通知送信中: {schedule.user_id} -> {to_user_id}")

                # プッシュ通知を送信（save_to_db=Trueで明示的に指定）
                await self.notification_service.send_push_notification(
                    user_id=to_user_id,
                    title=f"📍 {short_location}から出発",
                    body=message,
                    notification_type=NotificationType.DEPARTURE,
                    data={
                        "schedule_id": schedule.id,
                        "from_user_id": schedule.user_id,
                        "destination_name": schedule.destination_name,
                        "map_link": map_link,
                    },
                    save_to_db=True,  # 明示的にDB保存を指定
                )

                # 通知履歴を保存（24時間TTL）
                history = await self._save_notification_history(
                    from_user_id=schedule.user_id,
                    to_user_id=to_user_id,
                    schedule_id=schedule.id,
                    notification_type="departure",
                    message=message,
                    map_link=map_link,
                )
                notification_ids.append(history.id)

                logger.info(
                    f"[退出通知] 送信成功: {schedule.user_id} -> {to_user_id}, "
                    f"履歴ID: {history.id}"
                )

            except Exception as e:
                logger.error(
                    f"[退出通知] 送信失敗: {schedule.user_id} -> {to_user_id}, "
                    f"エラー: {type(e).__name__}: {str(e)}",
                    exc_info=True,
                )

        logger.info(f"[退出通知] 完了: {len(notification_ids)}件の通知を送信しました")
        return notification_ids

    async def check_and_send_stay_notifications(self) -> int:
        """
        滞在通知が必要なスケジュールをチェックして通知を送信
        （定期的なバッチ処理で呼び出される想定）

        Returns:
            送信した通知数
        """
        from app.services.location import LocationService

        location_service = LocationService()

        # arrived状態のスケジュールを全て取得
        # 全ユーザーのarrivedスケジュールを取得する必要があるため、Firestoreクエリを使用
        query = self.db.collection("schedules").where("status", "==", "arrived")

        arrived_schedules = []
        for doc in query.stream():
            schedule_data = doc.to_dict()
            arrived_schedules.append(LocationScheduleInDB(**schedule_data))

        now = now_jst()
        total_sent = 0

        for schedule in arrived_schedules:
            try:
                # 到着時刻がない場合はスキップ
                if not schedule.arrived_at:
                    continue

                # 滞在時間を計算
                stay_duration = now - schedule.arrived_at
                stay_minutes = int(stay_duration.total_seconds() / 60)

                # 指定された滞在時間に達していない場合はスキップ
                if stay_minutes < schedule.notify_after_minutes:
                    continue

                # 時間枠はあくまで目安なので、end_timeを過ぎていても通知を送る
                # （end_timeのチェックは行わない）

                # 既に滞在通知を送信済みかチェック（通知履歴を確認）
                notification_history_query = (
                    self.db.collection(self.notification_history_collection)
                    .where("schedule_id", "==", schedule.id)
                    .where("type", "==", "stay")
                )

                existing_notifications = list(notification_history_query.stream())
                if existing_notifications:
                    # 既に送信済み
                    continue

                # 最新の位置情報を取得
                latest_location = await location_service.get_latest_location(schedule.user_id)
                if not latest_location:
                    logger.warning(
                        f"スケジュール {schedule.id}: 位置情報が見つかりません"
                    )
                    continue

                # 滞在通知を送信
                notification_ids = await self.send_stay_notification(
                    schedule, latest_location.coords
                )
                total_sent += len(notification_ids)

                logger.info(
                    f"バッチ処理: スケジュール {schedule.id} の滞在通知を送信 "
                    f"({len(notification_ids)}件)"
                )

            except Exception as e:
                logger.error(f"バッチ処理エラー (schedule_id: {schedule.id}): {e}")
                continue

        if total_sent > 0:
            logger.info(f"バッチ処理完了: {total_sent}件の滞在通知を送信しました")

        return total_sent

    async def cleanup_old_notification_history(self) -> int:
        """
        24時間以上経過した通知履歴を削除

        Returns:
            削除した件数
        """
        now = now_jst()

        query = self.db.collection(self.notification_history_collection).where(
            "auto_delete_at", "<=", now
        )

        deleted_count = 0
        for doc in query.stream():
            doc.reference.delete()
            deleted_count += 1

        if deleted_count > 0:
            logger.info(f"古い通知履歴を削除しました: {deleted_count}件")

        return deleted_count
