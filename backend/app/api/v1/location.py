"""
位置情報トラッキングAPIエンドポイント
"""

from fastapi import APIRouter, Depends, status

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
    # 位置情報を記録
    location_history = await location_service.record_location(current_user.uid, location_data)

    # TODO: Week 3-4で実装予定
    # - ジオフェンスチェック（到着・退出判定）
    # - 自動通知トリガー
    # - スケジュールステータス更新

    # 現時点では位置情報の記録のみ行う
    return LocationUpdateResponse(
        message="位置情報を記録しました",
        location_recorded=True,
        triggered_notifications=[],  # Week 3-4で実装
        schedule_updates=[],  # Week 3-4で実装
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
