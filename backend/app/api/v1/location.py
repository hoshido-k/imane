"""
位置情報トラッキングAPIエンドポイント
"""

from fastapi import APIRouter, Depends

from app.api.dependencies import get_current_user
from app.schemas.location import (
    LocationStatusResponse,
    LocationUpdateRequest,
    LocationUpdateResponse,
)
from app.schemas.user import UserInDB
from app.services.location import LocationService

router = APIRouter()


@router.post("/update", response_model=LocationUpdateResponse)
async def update_location(
    location_data: LocationUpdateRequest,
    current_user: UserInDB = Depends(get_current_user),
    location_service: LocationService = Depends(lambda: LocationService()),
):
    """
    位置情報を更新

    アプリがバックグラウンドで定期的に（10分間隔）呼び出すエンドポイント。
    位置情報を記録し、アクティブなスケジュールのジオフェンスチェックを行います。

    Args:
        location_data: 位置情報データ
        current_user: 現在のユーザー
        location_service: 位置情報サービス

    Returns:
        更新結果と通知・スケジュール更新の情報
    """
    from app.services.auto_notification import AutoNotificationService
    from app.services.geofencing import GeofencingService

    # 位置情報を記録
    await location_service.record_location(current_user.uid, location_data)

    # 前回の位置情報を取得
    location_histories = await location_service.get_location_history(current_user.uid, limit=2)
    previous_coords = None
    if len(location_histories) >= 2:
        previous_coords = location_histories[1].coords

    # ジオフェンスチェック
    geofencing_service = GeofencingService()
    geofence_events = await geofencing_service.process_location_update(
        user_id=current_user.uid,
        current_coords=location_data.coords,
        previous_coords=previous_coords,
    )

    # 自動通知の送信
    auto_notification_service = AutoNotificationService()
    triggered_notifications = []
    schedule_updates = []

    for event in geofence_events:
        schedule_update = {
            "schedule_id": event.schedule.id,
            "destination_name": event.schedule.destination_name,
            "event_type": event.event_type,
            "distance": event.distance_to_destination,
        }

        if event.event_type == "entry":
            # 到着通知を送信
            notification_ids = await auto_notification_service.send_arrival_notification(
                schedule=event.schedule, current_coords=location_data.coords
            )
            schedule_update["status"] = "arrived"
            schedule_update["notification_ids"] = notification_ids
            triggered_notifications.extend(
                [{"type": "arrival", "schedule_id": event.schedule.id}] * len(notification_ids)
            )

        elif event.event_type == "exit":
            # 退出通知を送信
            notification_ids = await auto_notification_service.send_departure_notification(
                schedule=event.schedule, current_coords=location_data.coords
            )
            schedule_update["status"] = "completed"
            schedule_update["notification_ids"] = notification_ids
            triggered_notifications.extend(
                [{"type": "departure", "schedule_id": event.schedule.id}] * len(notification_ids)
            )

        schedule_updates.append(schedule_update)

    message = f"位置情報を記録しました。{len(geofence_events)}件のジオフェンスイベントを処理しました。"

    return LocationUpdateResponse(
        message=message,
        location_recorded=True,
        triggered_notifications=triggered_notifications,
        schedule_updates=schedule_updates,
    )


@router.get("/status", response_model=LocationStatusResponse)
async def get_location_status(
    current_user: UserInDB = Depends(get_current_user),
    location_service: LocationService = Depends(lambda: LocationService()),
):
    """
    現在の位置情報ステータスを取得

    最新の位置情報と、アクティブなスケジュールのステータスを取得します。

    Args:
        current_user: 現在のユーザー
        location_service: 位置情報サービス

    Returns:
        位置情報ステータス
    """
    # 最新の位置情報を取得
    latest_location = await location_service.get_latest_location(current_user.uid)

    # アクティブなスケジュールのステータスを取得
    schedule_statuses = await location_service.get_active_schedule_status(current_user.uid)

    return LocationStatusResponse(
        current_location=latest_location.coords if latest_location else None,
        last_updated=latest_location.recorded_at if latest_location else None,
        active_schedules=schedule_statuses,
    )
