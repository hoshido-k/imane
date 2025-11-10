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
    import logging

    from app.services.auto_notification import AutoNotificationService
    from app.services.geofencing import GeofencingService

    logger = logging.getLogger(__name__)

    logger.info(
        f"[位置情報更新] ユーザー: {current_user.uid}, "
        f"座標: ({location_data.coords.lat}, {location_data.coords.lng}), "
        f"精度: {location_data.accuracy}m"
    )

    # 位置情報を記録
    await location_service.record_location(current_user.uid, location_data)

    # 前回の位置情報を取得（インデックスエラーが出る場合はスキップ）
    previous_coords = None
    try:
        location_histories = await location_service.get_location_history(current_user.uid, limit=2)
        if len(location_histories) >= 2:
            previous_coords = location_histories[1].coords
            logger.info(
                f"[位置情報更新] 前回の位置: ({previous_coords.lat}, {previous_coords.lng})"
            )
        else:
            logger.info(f"[位置情報更新] 初回の位置情報記録（履歴件数: {len(location_histories)}）")
    except Exception as e:
        logger.warning(
            f"[位置情報更新] 位置情報履歴の取得に失敗（インデックス未作成の可能性）: {e}. "
            f"前回位置情報なしで処理を継続します"
        )

    # ジオフェンスチェック
    geofencing_service = GeofencingService()
    geofence_events = await geofencing_service.process_location_update(
        user_id=current_user.uid,
        current_coords=location_data.coords,
        previous_coords=previous_coords,
    )

    logger.info(
        f"[位置情報更新] ジオフェンスイベント: {len(geofence_events)}件検出"
    )

    # 自動通知の送信
    auto_notification_service = AutoNotificationService()
    triggered_notifications = []
    schedule_updates = []

    for event in geofence_events:
        logger.info(
            f"[ジオフェンスイベント] タイプ: {event.event_type}, "
            f"スケジュール: {event.schedule.id}, "
            f"目的地: {event.schedule.destination_name}, "
            f"距離: {event.distance_to_destination:.1f}m, "
            f"通知先: {len(event.schedule.notify_to_user_ids)}人"
        )

        schedule_update = {
            "schedule_id": event.schedule.id,
            "destination_name": event.schedule.destination_name,
            "event_type": event.event_type,
            "distance": event.distance_to_destination,
        }

        if event.event_type == "entry":
            # 到着通知を送信
            logger.info(f"[到着通知] スケジュール {event.schedule.id} の到着通知を送信開始")
            notification_ids = await auto_notification_service.send_arrival_notification(
                schedule=event.schedule, current_coords=location_data.coords
            )
            logger.info(f"[到着通知] {len(notification_ids)}件の通知を送信しました")
            schedule_update["status"] = "arrived"
            schedule_update["notification_ids"] = notification_ids
            triggered_notifications.extend(
                [{"type": "arrival", "schedule_id": event.schedule.id}] * len(notification_ids)
            )

        elif event.event_type == "exit":
            # 退出通知を送信
            logger.info(f"[退出通知] スケジュール {event.schedule.id} の退出通知を送信開始")
            notification_ids = await auto_notification_service.send_departure_notification(
                schedule=event.schedule, current_coords=location_data.coords
            )
            logger.info(f"[退出通知] {len(notification_ids)}件の通知を送信しました")
            schedule_update["status"] = "completed"
            schedule_update["notification_ids"] = notification_ids
            triggered_notifications.extend(
                [{"type": "departure", "schedule_id": event.schedule.id}] * len(notification_ids)
            )

        schedule_updates.append(schedule_update)

    # 到着済みスケジュールの滞在通知をチェック
    from app.schemas.schedule import ScheduleStatus
    from app.services.schedules import ScheduleService

    schedule_service = ScheduleService()
    arrived_schedules = await schedule_service.get_schedules_by_user(
        current_user.uid, ScheduleStatus.ARRIVED
    )

    logger.info(f"[滞在通知チェック] 到着済みスケジュール: {len(arrived_schedules)}件")

    for schedule in arrived_schedules:
        try:
            # 滞在通知を送信（条件を満たす場合のみ送信される）
            notification_ids = await auto_notification_service.send_stay_notification(
                schedule=schedule, current_coords=location_data.coords
            )

            if notification_ids:
                logger.info(
                    f"[滞在通知] スケジュール {schedule.id}: {len(notification_ids)}件の通知を送信しました"
                )
                schedule_updates.append(
                    {
                        "schedule_id": schedule.id,
                        "destination_name": schedule.destination_name,
                        "event_type": "stay",
                        "notification_ids": notification_ids,
                    }
                )
                triggered_notifications.extend(
                    [{"type": "stay", "schedule_id": schedule.id}] * len(notification_ids)
                )
        except Exception as e:
            logger.error(f"[滞在通知エラー] スケジュール {schedule.id}: {e}", exc_info=True)

    message = f"位置情報を記録しました。{len(geofence_events)}件のジオフェンスイベントを処理しました。"
    logger.info(f"[位置情報更新完了] {message}")

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
