"""
位置情報スケジュール管理APIエンドポイント
"""

from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Path, Query, status

from app.api.dependencies import get_current_user
from app.schemas.schedule import (
    LocationScheduleCreate,
    LocationScheduleListResponse,
    LocationScheduleResponse,
    LocationScheduleUpdate,
    ScheduleStatus,
)
from app.schemas.user import UserInDB
from app.services.schedules import ScheduleService

router = APIRouter()


@router.post("", response_model=LocationScheduleResponse, status_code=status.HTTP_201_CREATED)
async def create_schedule(
    schedule_data: LocationScheduleCreate,
    current_user: UserInDB = Depends(get_current_user),
    schedule_service: ScheduleService = Depends(lambda: ScheduleService()),
):
    """
    位置情報スケジュールを作成

    目的地、時間範囲、通知先フレンドを指定してスケジュールを作成します。

    Args:
        schedule_data: スケジュール作成データ
        current_user: 現在のユーザー
        schedule_service: スケジュールサービス

    Returns:
        作成されたスケジュール情報

    Raises:
        HTTPException: バリデーションエラー
    """
    try:
        schedule = await schedule_service.create_schedule(current_user.uid, schedule_data)
        return LocationScheduleResponse(**schedule.model_dump())
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.get("", response_model=LocationScheduleListResponse)
async def get_schedules(
    status_filter: Optional[ScheduleStatus] = Query(
        None, description="ステータスでフィルタリング"
    ),
    current_user: UserInDB = Depends(get_current_user),
    schedule_service: ScheduleService = Depends(lambda: ScheduleService()),
):
    """
    スケジュール一覧を取得

    自分が作成したスケジュールの一覧を取得します。
    オプションでステータスによるフィルタリングが可能です。

    Args:
        status_filter: ステータスフィルター（active/arrived/completed/expired）
        current_user: 現在のユーザー
        schedule_service: スケジュールサービス

    Returns:
        スケジュール一覧
    """
    schedules = await schedule_service.get_schedules_by_user(current_user.uid, status_filter)

    # LocationScheduleInDB -> LocationScheduleResponse に変換
    schedule_responses = [LocationScheduleResponse(**s.model_dump()) for s in schedules]

    return LocationScheduleListResponse(schedules=schedule_responses, total=len(schedule_responses))


@router.get("/active", response_model=LocationScheduleListResponse)
async def get_active_schedules(
    current_user: UserInDB = Depends(get_current_user),
    schedule_service: ScheduleService = Depends(lambda: ScheduleService()),
):
    """
    アクティブなスケジュール一覧を取得

    現在アクティブな（開始済みで完了していない）スケジュールの一覧を取得します。

    Args:
        current_user: 現在のユーザー
        schedule_service: スケジュールサービス

    Returns:
        アクティブなスケジュール一覧
    """
    schedules = await schedule_service.get_active_schedules(current_user.uid)

    # LocationScheduleInDB -> LocationScheduleResponse に変換
    schedule_responses = [LocationScheduleResponse(**s.model_dump()) for s in schedules]

    return LocationScheduleListResponse(schedules=schedule_responses, total=len(schedule_responses))


@router.get("/{schedule_id}", response_model=LocationScheduleResponse)
async def get_schedule(
    schedule_id: str = Path(..., description="スケジュールID"),
    current_user: UserInDB = Depends(get_current_user),
    schedule_service: ScheduleService = Depends(lambda: ScheduleService()),
):
    """
    スケジュール詳細を取得

    指定したスケジュールの詳細情報を取得します。

    Args:
        schedule_id: スケジュールID
        current_user: 現在のユーザー
        schedule_service: スケジュールサービス

    Returns:
        スケジュール詳細情報

    Raises:
        HTTPException: スケジュールが見つからない、または権限がない場合
    """
    try:
        schedule = await schedule_service.get_schedule_by_id(schedule_id, current_user.uid)

        if not schedule:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND, detail="スケジュールが見つかりません"
            )

        return LocationScheduleResponse(**schedule.model_dump())
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(e))


@router.put("/{schedule_id}", response_model=LocationScheduleResponse)
async def update_schedule(
    schedule_id: str = Path(..., description="スケジュールID"),
    update_data: LocationScheduleUpdate = ...,
    current_user: UserInDB = Depends(get_current_user),
    schedule_service: ScheduleService = Depends(lambda: ScheduleService()),
):
    """
    スケジュール情報を更新

    既存のスケジュールの情報を更新します。

    Args:
        schedule_id: スケジュールID
        update_data: 更新データ
        current_user: 現在のユーザー
        schedule_service: スケジュールサービス

    Returns:
        更新後のスケジュール情報

    Raises:
        HTTPException: スケジュールが見つからない、または権限がない場合
    """
    try:
        schedule = await schedule_service.update_schedule(
            schedule_id, current_user.uid, update_data
        )

        return LocationScheduleResponse(**schedule.model_dump())
    except ValueError as e:
        # スケジュールが見つからない場合は404、権限がない場合は403
        if "見つかりません" in str(e):
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))
        else:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(e))


@router.delete("/{schedule_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_schedule(
    schedule_id: str = Path(..., description="スケジュールID"),
    current_user: UserInDB = Depends(get_current_user),
    schedule_service: ScheduleService = Depends(lambda: ScheduleService()),
):
    """
    スケジュールを削除

    指定したスケジュールを削除します。

    Args:
        schedule_id: スケジュールID
        current_user: 現在のユーザー
        schedule_service: スケジュールサービス

    Raises:
        HTTPException: スケジュールが見つからない、または権限がない場合
    """
    try:
        await schedule_service.delete_schedule(schedule_id, current_user.uid)
    except ValueError as e:
        # スケジュールが見つからない場合は404、権限がない場合は403
        if "見つかりません" in str(e):
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))
        else:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(e))
