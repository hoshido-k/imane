"""
通知APIエンドポイント
"""


from fastapi import APIRouter, Depends, HTTPException, Path, Query, status

from app.api.dependencies import get_current_user
from app.schemas.notification import (
    FCMTokenRegisterRequest,
    FCMTokenRemoveRequest,
    NotificationListResponse,
    NotificationMarkReadRequest,
    NotificationResponse,
    PushNotificationRequest,
)
from app.schemas.user import UserInDB
from app.services.notifications import NotificationService

router = APIRouter()


@router.post("/fcm-token", status_code=status.HTTP_201_CREATED)
async def register_fcm_token(
    token_data: FCMTokenRegisterRequest,
    current_user: UserInDB = Depends(get_current_user),
    notification_service: NotificationService = Depends(lambda: NotificationService()),
):
    """
    FCMトークンを登録

    モバイルアプリからプッシュ通知を受け取るためのFCMトークンを登録します。
    複数のデバイスで同じアカウントを使用している場合、複数のトークンが登録されます。

    Args:
        token_data: FCMトークン
        current_user: 現在のユーザー
        notification_service: 通知サービス

    Returns:
        登録成功メッセージ
    """
    try:
        await notification_service.register_fcm_token(current_user.uid, token_data.fcm_token)
        return {"message": "FCMトークンを登録しました"}
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.delete("/fcm-token", status_code=status.HTTP_200_OK)
async def remove_fcm_token(
    token_data: FCMTokenRemoveRequest,
    current_user: UserInDB = Depends(get_current_user),
    notification_service: NotificationService = Depends(lambda: NotificationService()),
):
    """
    FCMトークンを削除

    ログアウト時やデバイスを変更した際にFCMトークンを削除します。

    Args:
        token_data: 削除するFCMトークン
        current_user: 現在のユーザー
        notification_service: 通知サービス

    Returns:
        削除成功メッセージ
    """
    try:
        await notification_service.remove_fcm_token(current_user.uid, token_data.fcm_token)
        return {"message": "FCMトークンを削除しました"}
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.get("", response_model=NotificationListResponse)
async def get_notifications(
    limit: int = Query(50, ge=1, le=100, description="取得件数"),
    unread_only: bool = Query(False, description="未読のみ取得するか"),
    current_user: UserInDB = Depends(get_current_user),
    notification_service: NotificationService = Depends(lambda: NotificationService()),
):
    """
    通知一覧を取得

    自分宛の通知一覧を取得します。
    新しい順に並びます。

    Args:
        limit: 取得件数（1-100、デフォルト50）
        unread_only: 未読のみ取得するか（デフォルトfalse）
        current_user: 現在のユーザー
        notification_service: 通知サービス

    Returns:
        通知一覧
    """
    notifications = await notification_service.get_user_notifications(
        current_user.uid, limit=limit, unread_only=unread_only
    )

    unread_count = await notification_service.get_unread_count(current_user.uid)

    return NotificationListResponse(
        notifications=notifications, total=len(notifications), unread_count=unread_count
    )


@router.get("/history", response_model=NotificationListResponse)
async def get_notification_history(
    limit: int = Query(50, ge=1, le=100, description="取得件数"),
    current_user: UserInDB = Depends(get_current_user),
    notification_service: NotificationService = Depends(lambda: NotificationService()),
):
    """
    通知履歴を取得（24時間以内）

    自分宛の通知履歴を取得します。
    新しい順に並びます。

    Args:
        limit: 取得件数（1-100、デフォルト50）
        current_user: 現在のユーザー
        notification_service: 通知サービス

    Returns:
        通知履歴一覧
    """
    notifications = await notification_service.get_user_notifications(
        current_user.uid, limit=limit, unread_only=False
    )

    unread_count = await notification_service.get_unread_count(current_user.uid)

    return NotificationListResponse(
        notifications=notifications, total=len(notifications), unread_count=unread_count
    )


@router.get("/unread-count", response_model=dict)
async def get_unread_count(
    current_user: UserInDB = Depends(get_current_user),
    notification_service: NotificationService = Depends(lambda: NotificationService()),
):
    """
    未読通知数を取得

    Args:
        current_user: 現在のユーザー
        notification_service: 通知サービス

    Returns:
        未読通知数
    """
    unread_count = await notification_service.get_unread_count(current_user.uid)
    return {"unread_count": unread_count}


@router.post("/read", response_model=dict)
async def mark_notifications_as_read(
    read_data: NotificationMarkReadRequest,
    current_user: UserInDB = Depends(get_current_user),
    notification_service: NotificationService = Depends(lambda: NotificationService()),
):
    """
    通知を既読にする

    指定した通知を既読にします。

    Args:
        read_data: 既読にする通知IDのリスト
        current_user: 現在のユーザー
        notification_service: 通知サービス

    Returns:
        更新された通知数

    Raises:
        HTTPException: 権限がない場合
    """
    try:
        updated_count = await notification_service.mark_notifications_as_read(
            current_user.uid, read_data.notification_ids
        )
        return {"message": f"{updated_count}件の通知を既読にしました", "count": updated_count}
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(e))


@router.delete("/{notification_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_notification(
    notification_id: str = Path(..., description="削除する通知ID"),
    current_user: UserInDB = Depends(get_current_user),
    notification_service: NotificationService = Depends(lambda: NotificationService()),
):
    """
    通知を削除

    指定した通知を削除します。

    Args:
        notification_id: 削除する通知ID
        current_user: 現在のユーザー
        notification_service: 通知サービス

    Raises:
        HTTPException: 通知が見つからない、権限がない場合
    """
    try:
        await notification_service.delete_notification(current_user.uid, notification_id)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.post("/send-test", response_model=NotificationResponse, status_code=status.HTTP_201_CREATED)
async def send_test_notification(
    notification_data: PushNotificationRequest,
    current_user: UserInDB = Depends(get_current_user),
    notification_service: NotificationService = Depends(lambda: NotificationService()),
):
    """
    テスト通知を送信（開発・デバッグ用）

    指定したユーザーにテスト用のプッシュ通知を送信します。
    本番環境では無効化することを推奨します。

    Args:
        notification_data: 通知データ
        current_user: 現在のユーザー
        notification_service: 通知サービス

    Returns:
        送信された通知データ

    Raises:
        HTTPException: ユーザーが見つからない場合
    """
    try:
        from app.schemas.notification import NotificationType

        notification = await notification_service.send_push_notification(
            user_id=notification_data.user_id,
            title=notification_data.title,
            body=notification_data.body,
            notification_type=NotificationType.MESSAGE,  # テスト用にMESSAGEタイプを使用
            data=notification_data.data,
            save_to_db=True,
        )

        return notification
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
