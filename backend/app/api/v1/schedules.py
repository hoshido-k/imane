"""
位置情報スケジュール管理APIエンドポイント
"""

from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Path, Query, status

from app.api.dependencies import get_current_user
from app.schemas.schedule import (
    CreatorUser,
    LocationScheduleCreate,
    LocationScheduleListResponse,
    LocationScheduleResponse,
    LocationScheduleUpdate,
    NotifyToUser,
    ScheduleStatus,
)
from app.schemas.user import UserInDB
from app.services.schedules import ScheduleService
from app.services.users import UserService

router = APIRouter()


async def _enrich_schedule_with_user_info(
    schedule: LocationScheduleResponse,
    user_service: UserService,
    include_creator: bool = False,
) -> LocationScheduleResponse:
    """
    スケジュールに通知先ユーザー情報を追加

    Args:
        schedule: スケジュールレスポンス
        user_service: ユーザーサービス
        include_creator: 作成者情報も追加するか

    Returns:
        ユーザー情報を追加したスケジュールレスポンス
    """
    notify_to_users = []
    for user_id in schedule.notify_to_user_ids:
        user = await user_service.get_user_by_uid(user_id)
        if user:
            notify_to_users.append(
                NotifyToUser(
                    user_id=user.uid,
                    display_name=user.display_name,
                    profile_image_url=user.profile_image_url,
                )
            )

    schedule.notify_to_users = notify_to_users

    # 作成者情報も追加する場合
    if include_creator:
        creator = await user_service.get_user_by_uid(schedule.user_id)
        if creator:
            schedule.creator = CreatorUser(
                user_id=creator.uid,
                display_name=creator.display_name,
                profile_image_url=creator.profile_image_url,
            )

    return schedule


@router.post("", response_model=LocationScheduleResponse, status_code=status.HTTP_201_CREATED)
async def create_schedule(
    schedule_data: LocationScheduleCreate,
    current_user: UserInDB = Depends(get_current_user),
    schedule_service: ScheduleService = Depends(lambda: ScheduleService()),
    user_service: UserService = Depends(lambda: UserService()),
):
    """
    位置情報スケジュールを作成

    目的地、時間範囲、通知先フレンドを指定してスケジュールを作成します。

    Args:
        schedule_data: スケジュール作成データ
        current_user: 現在のユーザー
        schedule_service: スケジュールサービス
        user_service: ユーザーサービス

    Returns:
        作成されたスケジュール情報

    Raises:
        HTTPException: バリデーションエラー
    """
    try:
        import logging
        logger = logging.getLogger(__name__)
        logger.info(f"[DEBUG API] クライアントから受信した start_time: {schedule_data.start_time}")

        schedule = await schedule_service.create_schedule(current_user.uid, schedule_data)
        schedule_response = LocationScheduleResponse(**schedule.model_dump())

        logger.info(f"[DEBUG API] レスポンス前の start_time: {schedule_response.start_time}")
        result = await _enrich_schedule_with_user_info(schedule_response, user_service)
        logger.info(f"[DEBUG API] レスポンス直前の start_time: {result.start_time}")
        return result
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.get("", response_model=LocationScheduleListResponse)
async def get_schedules(
    status_filter: Optional[ScheduleStatus] = Query(
        None, description="ステータスでフィルタリング"
    ),
    current_user: UserInDB = Depends(get_current_user),
    schedule_service: ScheduleService = Depends(lambda: ScheduleService()),
    user_service: UserService = Depends(lambda: UserService()),
):
    """
    スケジュール一覧を取得

    自分が作成したスケジュールの一覧を取得します。
    オプションでステータスによるフィルタリングが可能です。

    Args:
        status_filter: ステータスフィルター（active/arrived/completed/expired）
        current_user: 現在のユーザー
        schedule_service: スケジュールサービス
        user_service: ユーザーサービス

    Returns:
        スケジュール一覧
    """
    schedules = await schedule_service.get_schedules_by_user(current_user.uid, status_filter)

    # LocationScheduleInDB -> LocationScheduleResponse に変換し、ユーザー情報を追加
    schedule_responses = []
    for s in schedules:
        schedule_response = LocationScheduleResponse(**s.model_dump())
        enriched_schedule = await _enrich_schedule_with_user_info(schedule_response, user_service)
        schedule_responses.append(enriched_schedule)

    return LocationScheduleListResponse(schedules=schedule_responses, total=len(schedule_responses))


@router.get("/active", response_model=LocationScheduleListResponse)
async def get_active_schedules(
    current_user: UserInDB = Depends(get_current_user),
    schedule_service: ScheduleService = Depends(lambda: ScheduleService()),
    user_service: UserService = Depends(lambda: UserService()),
):
    """
    アクティブなスケジュール一覧を取得

    現在アクティブな（開始済みで完了していない）スケジュールの一覧を取得します。

    Args:
        current_user: 現在のユーザー
        schedule_service: スケジュールサービス
        user_service: ユーザーサービス

    Returns:
        アクティブなスケジュール一覧
    """
    schedules = await schedule_service.get_active_schedules(current_user.uid)

    # LocationScheduleInDB -> LocationScheduleResponse に変換し、ユーザー情報を追加
    schedule_responses = []
    for s in schedules:
        schedule_response = LocationScheduleResponse(**s.model_dump())
        enriched_schedule = await _enrich_schedule_with_user_info(schedule_response, user_service)
        schedule_responses.append(enriched_schedule)

    return LocationScheduleListResponse(schedules=schedule_responses, total=len(schedule_responses))


@router.get("/friend-schedules", response_model=LocationScheduleListResponse)
async def get_friend_schedules(
    status_filter: Optional[ScheduleStatus] = Query(
        None, description="ステータスでフィルタリング"
    ),
    current_user: UserInDB = Depends(get_current_user),
    schedule_service: ScheduleService = Depends(lambda: ScheduleService()),
    user_service: UserService = Depends(lambda: UserService()),
):
    """
    フレンドが作成したスケジュール一覧を取得

    自分が通知先として指定されているフレンドのスケジュールの一覧を取得します。
    オプションでステータスによるフィルタリングが可能です。

    Args:
        status_filter: ステータスフィルター（active/arrived/completed/expired）
        current_user: 現在のユーザー
        schedule_service: スケジュールサービス
        user_service: ユーザーサービス

    Returns:
        フレンドのスケジュール一覧
    """
    schedules = await schedule_service.get_schedules_by_recipient(current_user.uid, status_filter)

    # LocationScheduleInDB -> LocationScheduleResponse に変換し、ユーザー情報と作成者情報を追加
    schedule_responses = []
    for s in schedules:
        schedule_response = LocationScheduleResponse(**s.model_dump())
        enriched_schedule = await _enrich_schedule_with_user_info(
            schedule_response, user_service, include_creator=True
        )
        schedule_responses.append(enriched_schedule)

    return LocationScheduleListResponse(schedules=schedule_responses, total=len(schedule_responses))


@router.get("/{schedule_id}", response_model=LocationScheduleResponse)
async def get_schedule(
    schedule_id: str = Path(..., description="スケジュールID"),
    current_user: UserInDB = Depends(get_current_user),
    schedule_service: ScheduleService = Depends(lambda: ScheduleService()),
    user_service: UserService = Depends(lambda: UserService()),
):
    """
    スケジュール詳細を取得

    指定したスケジュールの詳細情報を取得します。

    Args:
        schedule_id: スケジュールID
        current_user: 現在のユーザー
        schedule_service: スケジュールサービス
        user_service: ユーザーサービス

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

        schedule_response = LocationScheduleResponse(**schedule.model_dump())
        return await _enrich_schedule_with_user_info(schedule_response, user_service)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(e))


@router.put("/{schedule_id}", response_model=LocationScheduleResponse)
async def update_schedule(
    schedule_id: str = Path(..., description="スケジュールID"),
    update_data: LocationScheduleUpdate = ...,
    current_user: UserInDB = Depends(get_current_user),
    schedule_service: ScheduleService = Depends(lambda: ScheduleService()),
    user_service: UserService = Depends(lambda: UserService()),
):
    """
    スケジュール情報を更新

    既存のスケジュールの情報を更新します。

    Args:
        schedule_id: スケジュールID
        update_data: 更新データ
        current_user: 現在のユーザー
        schedule_service: スケジュールサービス
        user_service: ユーザーサービス

    Returns:
        更新後のスケジュール情報

    Raises:
        HTTPException: スケジュールが見つからない、または権限がない場合
    """
    try:
        schedule = await schedule_service.update_schedule(
            schedule_id, current_user.uid, update_data
        )

        schedule_response = LocationScheduleResponse(**schedule.model_dump())
        return await _enrich_schedule_with_user_info(schedule_response, user_service)
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


@router.post("/{schedule_id}/test-arrival", status_code=status.HTTP_200_OK)
async def test_arrival_notification(
    schedule_id: str = Path(..., description="スケジュールID"),
    current_user: UserInDB = Depends(get_current_user),
    schedule_service: ScheduleService = Depends(lambda: ScheduleService()),
):
    """
    到着通知をテスト送信（開発・デバッグ用）

    指定したスケジュールに対して、到着通知を手動で送信します。
    実際の位置情報を送らなくても通知をテストできます。

    注意: このエンドポイントは、スケジュールの作成者のみが使用できます。
    本番環境では無効化することを推奨します。

    Args:
        schedule_id: スケジュールID
        current_user: 現在のユーザー
        schedule_service: スケジュールサービス

    Returns:
        送信した通知の情報

    Raises:
        HTTPException: スケジュールが見つからない、または権限がない場合
    """
    try:
        from app.services.auto_notification import AutoNotificationService

        # スケジュールを取得
        schedule = await schedule_service.get_schedule_by_id(schedule_id, current_user.uid)

        if not schedule:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND, detail="スケジュールが見つかりません"
            )

        # スケジュールの作成者のみがテスト通知を送信できる
        if schedule.user_id != current_user.uid:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="このスケジュールのテスト通知を送信する権限がありません",
            )

        # 到着通知を送信
        auto_notification_service = AutoNotificationService()
        notification_ids = await auto_notification_service.send_arrival_notification(
            schedule=schedule,
            current_coords=schedule.destination_coords,  # 目的地の座標を使用
        )

        return {
            "message": "到着通知をテスト送信しました",
            "schedule_id": schedule_id,
            "destination_name": schedule.destination_name,
            "notify_to_user_ids": schedule.notify_to_user_ids,
            "notification_ids": notification_ids,
            "count": len(notification_ids),
        }

    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(e))
