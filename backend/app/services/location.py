"""
位置情報トラッキングサービス
"""

import uuid
from datetime import UTC, datetime, timedelta
from typing import List, Optional

from app.core.firebase import get_firestore_client
from app.schemas.common import Coordinates
from app.schemas.location import (
    LocationHistoryInDB,
    LocationUpdateRequest,
    ScheduleStatusInfo,
)
from app.schemas.schedule import ScheduleStatus
from app.services.schedules import ScheduleService


class LocationService:
    """位置情報トラッキングサービスクラス"""

    def __init__(self):
        self.db = get_firestore_client()
        self.collection_name = "location_history"
        self.schedule_service = ScheduleService()

    async def record_location(
        self,
        user_id: str,
        location_data: LocationUpdateRequest,
        schedule_id: Optional[str] = None,
    ) -> LocationHistoryInDB:
        """
        位置情報を記録

        Args:
            user_id: ユーザーID
            location_data: 位置情報データ
            schedule_id: 関連するスケジュールID（オプション）

        Returns:
            記録された位置情報
        """
        # 新しい位置情報履歴IDを生成
        history_id = str(uuid.uuid4())
        now = datetime.now(UTC)
        recorded_at = location_data.recorded_at or now
        auto_delete_at = recorded_at + timedelta(hours=24)

        # 位置情報データを作成
        history_dict = {
            "id": history_id,
            "user_id": user_id,
            "schedule_id": schedule_id,
            "coords": location_data.coords.model_dump(),
            "accuracy": location_data.accuracy,
            "recorded_at": recorded_at,
            "auto_delete_at": auto_delete_at,
        }

        # Firestoreに保存
        history_ref = self.db.collection(self.collection_name).document(history_id)
        history_ref.set(history_dict)

        return LocationHistoryInDB(**history_dict)

    async def get_latest_location(self, user_id: str) -> Optional[LocationHistoryInDB]:
        """
        ユーザーの最新の位置情報を取得

        Args:
            user_id: ユーザーID

        Returns:
            最新の位置情報、存在しない場合はNone
        """
        query = (
            self.db.collection(self.collection_name)
            .where("user_id", "==", user_id)
            .order_by("recorded_at", direction="DESCENDING")
            .limit(1)
        )

        docs = list(query.stream())

        if not docs:
            return None

        location_data = docs[0].to_dict()
        return LocationHistoryInDB(**location_data)

    async def get_location_history(
        self, user_id: str, limit: int = 100
    ) -> List[LocationHistoryInDB]:
        """
        ユーザーの位置情報履歴を取得

        Args:
            user_id: ユーザーID
            limit: 取得件数の上限

        Returns:
            位置情報履歴のリスト
        """
        query = (
            self.db.collection(self.collection_name)
            .where("user_id", "==", user_id)
            .order_by("recorded_at", direction="DESCENDING")
            .limit(limit)
        )

        histories = []
        for doc in query.stream():
            history_data = doc.to_dict()
            histories.append(LocationHistoryInDB(**history_data))

        return histories

    async def get_active_schedule_status(self, user_id: str) -> List[ScheduleStatusInfo]:
        """
        アクティブなスケジュールのステータス情報を取得

        Args:
            user_id: ユーザーID

        Returns:
            スケジュールステータス情報のリスト
        """
        # アクティブなスケジュールと到着済みスケジュールを取得
        active_schedules = await self.schedule_service.get_schedules_by_user(
            user_id, ScheduleStatus.ACTIVE
        )
        arrived_schedules = await self.schedule_service.get_schedules_by_user(
            user_id, ScheduleStatus.ARRIVED
        )

        all_schedules = active_schedules + arrived_schedules

        # 最新の位置情報を取得
        latest_location = await self.get_latest_location(user_id)

        schedule_statuses = []
        for schedule in all_schedules:
            status_info = ScheduleStatusInfo(
                schedule_id=schedule.id,
                destination_name=schedule.destination_name,
                destination_coords=schedule.destination_coords,
                status=schedule.status.value,
                arrived_at=schedule.arrived_at,
                departed_at=schedule.departed_at,
            )

            # 現在地からの距離を計算（最新の位置情報がある場合）
            if latest_location:
                distance = self._calculate_distance(
                    latest_location.coords, schedule.destination_coords
                )
                status_info.distance_to_destination = distance

            schedule_statuses.append(status_info)

        return schedule_statuses

    def _calculate_distance(self, coords1: Coordinates, coords2: Coordinates) -> float:
        """
        2点間の距離を計算（Haversine formula）

        Args:
            coords1: 地点1の座標
            coords2: 地点2の座標

        Returns:
            距離（メートル）
        """
        from math import asin, cos, radians, sin, sqrt

        # 地球の半径（メートル）
        EARTH_RADIUS = 6371000

        lat1, lng1 = radians(coords1.lat), radians(coords1.lng)
        lat2, lng2 = radians(coords2.lat), radians(coords2.lng)

        dlat = lat2 - lat1
        dlng = lng2 - lng1

        a = sin(dlat / 2) ** 2 + cos(lat1) * cos(lat2) * sin(dlng / 2) ** 2
        c = 2 * asin(sqrt(a))

        return EARTH_RADIUS * c

    async def cleanup_old_locations(self) -> int:
        """
        24時間以上経過した位置情報履歴を削除

        Returns:
            削除した件数
        """
        now = datetime.now(UTC)

        query = self.db.collection(self.collection_name).where("auto_delete_at", "<=", now)

        deleted_count = 0
        for doc in query.stream():
            doc.reference.delete()
            deleted_count += 1

        return deleted_count
