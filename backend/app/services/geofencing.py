"""
ジオフェンシングサービス

位置情報の監視とジオフェンス（仮想境界）の出入り判定を行います。
"""

import logging
from datetime import UTC, datetime
from typing import List, Optional, Tuple

from app.config import settings
from app.core.firebase import get_firestore_client
from app.schemas.common import Coordinates
from app.schemas.schedule import LocationScheduleInDB, ScheduleStatus
from app.services.schedules import ScheduleService

logger = logging.getLogger(__name__)


class GeofenceEvent:
    """ジオフェンスイベント情報"""

    def __init__(
        self,
        schedule: LocationScheduleInDB,
        event_type: str,  # "entry" or "exit"
        current_coords: Coordinates,
        distance_to_destination: float,
    ):
        self.schedule = schedule
        self.event_type = event_type
        self.current_coords = current_coords
        self.distance_to_destination = distance_to_destination


class GeofencingService:
    """ジオフェンシングサービスクラス"""

    def __init__(self):
        self.db = get_firestore_client()
        self.schedule_service = ScheduleService()

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

    async def check_geofence_entry(
        self,
        schedule: LocationScheduleInDB,
        current_coords: Coordinates,
        previous_coords: Optional[Coordinates] = None,
    ) -> Tuple[bool, float]:
        """
        ジオフェンスへの侵入（到着）を判定

        Args:
            schedule: スケジュール情報
            current_coords: 現在の座標
            previous_coords: 前回の座標（オプション）

        Returns:
            (侵入したかどうか, 目的地までの距離)
        """
        # 現在の位置から目的地までの距離を計算
        distance = self._calculate_distance(current_coords, schedule.destination_coords)

        # ジオフェンス半径を取得
        geofence_radius = schedule.geofence_radius or settings.GEOFENCE_RADIUS_METERS

        # 現在の位置がジオフェンス内にいるか
        is_inside = distance <= geofence_radius

        # 既に到着済みの場合は侵入イベントとしない
        if schedule.status == ScheduleStatus.ARRIVED:
            return False, distance

        # ジオフェンス内にいる場合は侵入と判定
        # （前回の座標がない場合や、前回がジオフェンス外だった場合も含む）
        if is_inside:
            if previous_coords is None:
                # 前回の位置情報がない場合（初回記録）
                logger.info(
                    f"スケジュール {schedule.id}: ジオフェンス内を検出 (距離: {distance:.1f}m)"
                )
                return True, distance
            else:
                # 前回の位置からの距離を計算
                prev_distance = self._calculate_distance(previous_coords, schedule.destination_coords)
                # 前回はジオフェンス外で、今回は内側の場合のみ侵入イベント
                if prev_distance > geofence_radius:
                    logger.info(
                        f"スケジュール {schedule.id}: ジオフェンスへ侵入 "
                        f"(前回: {prev_distance:.1f}m → 現在: {distance:.1f}m)"
                    )
                    return True, distance

        return False, distance

    async def check_geofence_exit(
        self,
        schedule: LocationScheduleInDB,
        current_coords: Coordinates,
        previous_coords: Optional[Coordinates] = None,
    ) -> Tuple[bool, float]:
        """
        ジオフェンスからの退出を判定

        Args:
            schedule: スケジュール情報
            current_coords: 現在の座標
            previous_coords: 前回の座標（オプション）

        Returns:
            (退出したかどうか, 目的地までの距離)
        """
        # 現在の位置から目的地までの距離を計算
        distance = self._calculate_distance(current_coords, schedule.destination_coords)

        # ジオフェンス半径を取得
        geofence_radius = schedule.geofence_radius or settings.GEOFENCE_RADIUS_METERS

        # 現在の位置がジオフェンス外にいるか
        is_outside = distance > geofence_radius

        # 到着済みステータスでない場合は退出イベントとしない
        if schedule.status != ScheduleStatus.ARRIVED:
            return False, distance

        # ジオフェンス外にいる場合は退出と判定
        if is_outside:
            if previous_coords is None:
                # 前回の位置情報がない場合は退出と判定しない
                # （到着済みなのに前回の位置がないのは異常だが、念のため）
                return False, distance
            else:
                # 前回の位置からの距離を計算
                prev_distance = self._calculate_distance(previous_coords, schedule.destination_coords)
                # 前回はジオフェンス内で、今回は外側の場合のみ退出イベント
                if prev_distance <= geofence_radius:
                    logger.info(
                        f"スケジュール {schedule.id}: ジオフェンスから退出 "
                        f"(前回: {prev_distance:.1f}m → 現在: {distance:.1f}m)"
                    )
                    return True, distance

        return False, distance

    async def process_location_update(
        self, user_id: str, current_coords: Coordinates, previous_coords: Optional[Coordinates] = None
    ) -> List[GeofenceEvent]:
        """
        位置情報更新時のジオフェンス判定処理

        Args:
            user_id: ユーザID
            current_coords: 現在の座標
            previous_coords: 前回の座標（オプション）

        Returns:
            発生したジオフェンスイベントのリスト
        """
        events: List[GeofenceEvent] = []

        # アクティブなスケジュールと到着済みスケジュールを取得
        active_schedules = await self.schedule_service.get_schedules_by_user(
            user_id, ScheduleStatus.ACTIVE
        )
        arrived_schedules = await self.schedule_service.get_schedules_by_user(
            user_id, ScheduleStatus.ARRIVED
        )

        all_schedules = active_schedules + arrived_schedules

        # 現在時刻を取得
        now = datetime.now(UTC)

        # 各スケジュールに対してジオフェンス判定
        for schedule in all_schedules:
            # スケジュールの時間枠内かチェック
            if schedule.start_time > now or schedule.end_time < now:
                # 時間枠外の場合はスキップ
                continue

            # 到着判定
            is_entry, distance = await self.check_geofence_entry(
                schedule, current_coords, previous_coords
            )

            if is_entry:
                # 到着イベントを記録
                event = GeofenceEvent(
                    schedule=schedule,
                    event_type="entry",
                    current_coords=current_coords,
                    distance_to_destination=distance,
                )
                events.append(event)

                # スケジュールステータスを更新
                await self.schedule_service.update_schedule_status(
                    schedule.id, ScheduleStatus.ARRIVED, arrived_at=now
                )
                logger.info(f"スケジュール {schedule.id}: ステータスをARRIVEDに更新")

            # 退出判定（到着済みスケジュールのみ）
            if schedule.status == ScheduleStatus.ARRIVED:
                is_exit, distance = await self.check_geofence_exit(
                    schedule, current_coords, previous_coords
                )

                if is_exit:
                    # 退出イベントを記録
                    event = GeofenceEvent(
                        schedule=schedule,
                        event_type="exit",
                        current_coords=current_coords,
                        distance_to_destination=distance,
                    )
                    events.append(event)

                    # スケジュールステータスを更新
                    await self.schedule_service.update_schedule_status(
                        schedule.id, ScheduleStatus.COMPLETED, departed_at=now
                    )
                    logger.info(f"スケジュール {schedule.id}: ステータスをCOMPLETEDに更新")

        return events

    async def get_nearby_schedules(
        self, user_id: str, current_coords: Coordinates, radius_meters: Optional[int] = None
    ) -> List[Tuple[LocationScheduleInDB, float]]:
        """
        現在地の近くにあるスケジュールを取得

        Args:
            user_id: ユーザID
            current_coords: 現在の座標
            radius_meters: 検索半径（メートル）、Noneの場合はデフォルト値を使用

        Returns:
            (スケジュール, 距離) のタプルのリスト
        """
        if radius_meters is None:
            radius_meters = settings.GEOFENCE_RADIUS_METERS * 5  # デフォルトは5倍

        # アクティブなスケジュールを取得
        schedules = await self.schedule_service.get_schedules_by_user(user_id, ScheduleStatus.ACTIVE)

        nearby_schedules = []
        for schedule in schedules:
            distance = self._calculate_distance(current_coords, schedule.destination_coords)
            if distance <= radius_meters:
                nearby_schedules.append((schedule, distance))

        # 距離順にソート
        nearby_schedules.sort(key=lambda x: x[1])

        return nearby_schedules
