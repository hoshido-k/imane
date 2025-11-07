"""
フレンド管理APIエンドポイント
"""

from fastapi import APIRouter, Depends, HTTPException, Path, status

from app.api.dependencies import get_current_user
from app.schemas.friend import (
    FriendListResponse,
    FriendRequestCreate,
    FriendRequestListResponse,
    FriendshipResponse,
    FriendshipUpdate,
    LocationShareRequestCreate,
    LocationShareRequestListResponse,
)
from app.schemas.user import UserInDB
from app.services.friends import FriendService

router = APIRouter()


@router.post("/requests", response_model=dict, status_code=status.HTTP_201_CREATED)
async def send_friend_request(
    request_data: FriendRequestCreate,
    current_user: UserInDB = Depends(get_current_user),
    friend_service: FriendService = Depends(lambda: FriendService()),
):
    """
    フレンドリクエストを送信

    指定したユーザーにフレンドリクエストを送信します。

    Args:
        request_data: リクエストデータ（送信先UID、メッセージ）
        current_user: 現在のユーザー
        friend_service: フレンドサービス

    Returns:
        作成されたリクエスト情報

    Raises:
        HTTPException: 自分自身へのリクエスト、既存のリクエスト、既にフレンドの場合
    """
    try:
        request = await friend_service.send_friend_request(current_user.uid, request_data)
        return {
            "message": "フレンドリクエストを送信しました",
            "request_id": request.request_id,
            "status": request.status.value,
        }
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.get("/requests/received", response_model=FriendRequestListResponse)
async def get_received_requests(
    current_user: UserInDB = Depends(get_current_user),
    friend_service: FriendService = Depends(lambda: FriendService()),
):
    """
    受信したフレンドリクエスト一覧を取得

    自分宛てに送られてきたフレンドリクエストの一覧を取得します。

    Args:
        current_user: 現在のユーザー
        friend_service: フレンドサービス

    Returns:
        受信したリクエスト一覧
    """
    requests = await friend_service.get_received_requests(current_user.uid)
    return FriendRequestListResponse(requests=requests, total=len(requests))


@router.get("/requests/sent", response_model=FriendRequestListResponse)
async def get_sent_requests(
    current_user: UserInDB = Depends(get_current_user),
    friend_service: FriendService = Depends(lambda: FriendService()),
):
    """
    送信したフレンドリクエスト一覧を取得

    自分が送信したフレンドリクエストの一覧を取得します。

    Args:
        current_user: 現在のユーザー
        friend_service: フレンドサービス

    Returns:
        送信したリクエスト一覧
    """
    requests = await friend_service.get_sent_requests(current_user.uid)
    return FriendRequestListResponse(requests=requests, total=len(requests))


@router.post("/requests/{request_id}/accept", response_model=dict)
async def accept_friend_request(
    request_id: str = Path(..., description="リクエストID"),
    current_user: UserInDB = Depends(get_current_user),
    friend_service: FriendService = Depends(lambda: FriendService()),
):
    """
    フレンドリクエストを承認

    受信したフレンドリクエストを承認してフレンド関係を確立します。

    Args:
        request_id: リクエストID
        current_user: 現在のユーザー
        friend_service: フレンドサービス

    Returns:
        承認結果

    Raises:
        HTTPException: リクエストが見つからない、権限がない場合
    """
    try:
        friendship = await friend_service.accept_friend_request(current_user.uid, request_id)
        return {
            "message": "フレンドリクエストを承認しました",
            "friendship_id": friendship.friendship_id,
            "friend_id": friendship.friend_id,
        }
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.post("/requests/{request_id}/reject", response_model=dict)
async def reject_friend_request(
    request_id: str = Path(..., description="リクエストID"),
    current_user: UserInDB = Depends(get_current_user),
    friend_service: FriendService = Depends(lambda: FriendService()),
):
    """
    フレンドリクエストを拒否

    受信したフレンドリクエストを拒否します。

    Args:
        request_id: リクエストID
        current_user: 現在のユーザー
        friend_service: フレンドサービス

    Returns:
        拒否結果

    Raises:
        HTTPException: リクエストが見つからない、権限がない場合
    """
    try:
        await friend_service.reject_friend_request(current_user.uid, request_id)
        return {"message": "フレンドリクエストを拒否しました"}
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.get("", response_model=FriendListResponse)
async def get_friends(
    current_user: UserInDB = Depends(get_current_user),
    friend_service: FriendService = Depends(lambda: FriendService()),
):
    """
    フレンド一覧を取得

    自分のフレンド一覧を取得します。

    Args:
        current_user: 現在のユーザー
        friend_service: フレンドサービス

    Returns:
        フレンド一覧
    """
    friends = await friend_service.get_friends(current_user.uid)
    return FriendListResponse(friends=friends, total=len(friends))


@router.get("/{friend_id}", response_model=FriendshipResponse)
async def get_friend(
    friend_id: str = Path(..., description="フレンドのUID"),
    current_user: UserInDB = Depends(get_current_user),
    friend_service: FriendService = Depends(lambda: FriendService()),
):
    """
    特定のフレンド情報を取得

    Args:
        friend_id: フレンドのUID
        current_user: 現在のユーザー
        friend_service: フレンドサービス

    Returns:
        フレンド情報

    Raises:
        HTTPException: フレンドが見つからない場合
    """
    friendship = await friend_service.get_friendship(current_user.uid, friend_id)
    if not friendship:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="フレンドが見つかりません"
        )

    # フレンドのユーザー情報を取得して返す
    friends = await friend_service.get_friends(current_user.uid)
    friend_info = next((f for f in friends if f.friend_id == friend_id), None)

    if not friend_info:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="フレンド情報の取得に失敗しました"
        )

    return friend_info


@router.patch("/{friend_id}", response_model=FriendshipResponse)
async def update_friendship(
    friend_id: str = Path(..., description="フレンドのUID"),
    update_data: FriendshipUpdate = ...,
    current_user: UserInDB = Depends(get_current_user),
    friend_service: FriendService = Depends(lambda: FriendService()),
):
    """
    フレンド関係を更新

    信頼レベルやニックネームを更新します。

    Args:
        friend_id: フレンドのUID
        update_data: 更新データ
        current_user: 現在のユーザー
        friend_service: フレンドサービス

    Returns:
        更新後のフレンド情報

    Raises:
        HTTPException: フレンドが見つからない場合
    """
    try:
        await friend_service.update_friendship(current_user.uid, friend_id, update_data)

        # 更新後の情報をFriendshipResponseとして返す
        friends = await friend_service.get_friends(current_user.uid)
        friend_info = next((f for f in friends if f.friend_id == friend_id), None)

        if not friend_info:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND, detail="フレンド情報の取得に失敗しました"
            )

        return friend_info
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.delete("/{friend_id}", status_code=status.HTTP_204_NO_CONTENT)
async def remove_friend(
    friend_id: str = Path(..., description="フレンドのUID"),
    current_user: UserInDB = Depends(get_current_user),
    friend_service: FriendService = Depends(lambda: FriendService()),
):
    """
    フレンド関係を削除

    指定したフレンドとの関係を削除します。

    Args:
        friend_id: フレンドのUID
        current_user: 現在のユーザー
        friend_service: フレンドサービス

    Raises:
        HTTPException: フレンドが見つからない場合
    """
    try:
        await friend_service.remove_friend(current_user.uid, friend_id)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.post("/{friend_id}/block", response_model=dict)
async def block_user(
    friend_id: str = Path(..., description="ブロックするユーザーのUID"),
    current_user: UserInDB = Depends(get_current_user),
    friend_service: FriendService = Depends(lambda: FriendService()),
):
    """
    ユーザーをブロック

    指定したユーザーをブロックします。
    ブロックされたユーザーは自分の位置情報を見ることができなくなります。

    Args:
        friend_id: ブロックするユーザーのUID
        current_user: 現在のユーザー
        friend_service: フレンドサービス

    Returns:
        ブロック結果
    """
    await friend_service.block_user(current_user.uid, friend_id)
    return {"message": "ユーザーをブロックしました"}


# ==================== 位置情報共有リクエスト ====================


@router.post("/location-share/requests", response_model=dict, status_code=status.HTTP_201_CREATED)
async def send_location_share_request(
    request_data: LocationShareRequestCreate,
    current_user: UserInDB = Depends(get_current_user),
    friend_service: FriendService = Depends(lambda: FriendService()),
):
    """
    位置情報共有リクエストを送信

    フレンドに対して位置情報を見たい旨のリクエストを送信します。
    承認されると、あなたは相手の位置ステータスを見ることができます。

    Args:
        request_data: リクエストデータ（対象ユーザID）
        current_user: 現在のユーザー
        friend_service: フレンドサービス

    Returns:
        リクエスト送信結果

    Raises:
        HTTPException: フレンドでない、既にリクエスト送信済み、既に位置情報を見られる場合
    """
    try:
        request = await friend_service.send_location_share_request(current_user.uid, request_data)
        return {
            "message": "位置情報共有リクエストを送信しました",
            "request_id": request.request_id,
            "status": request.status.value,
        }
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.get("/location-share/requests/received", response_model=LocationShareRequestListResponse)
async def get_received_location_share_requests(
    current_user: UserInDB = Depends(get_current_user),
    friend_service: FriendService = Depends(lambda: FriendService()),
):
    """
    受信した位置情報共有リクエスト一覧を取得

    自分宛てに送られてきた位置情報共有リクエストの一覧を取得します。

    Args:
        current_user: 現在のユーザー
        friend_service: フレンドサービス

    Returns:
        受信したリクエスト一覧
    """
    requests = await friend_service.get_received_location_share_requests(current_user.uid)
    return LocationShareRequestListResponse(requests=requests, total=len(requests))


@router.get("/location-share/requests/sent", response_model=LocationShareRequestListResponse)
async def get_sent_location_share_requests(
    current_user: UserInDB = Depends(get_current_user),
    friend_service: FriendService = Depends(lambda: FriendService()),
):
    """
    送信した位置情報共有リクエスト一覧を取得

    自分が送信した位置情報共有リクエストの一覧を取得します。

    Args:
        current_user: 現在のユーザー
        friend_service: フレンドサービス

    Returns:
        送信したリクエスト一覧
    """
    requests = await friend_service.get_sent_location_share_requests(current_user.uid)
    return LocationShareRequestListResponse(requests=requests, total=len(requests))


@router.post("/location-share/requests/{request_id}/accept", response_model=dict)
async def accept_location_share_request(
    request_id: str = Path(..., description="リクエストID"),
    current_user: UserInDB = Depends(get_current_user),
    friend_service: FriendService = Depends(lambda: FriendService()),
):
    """
    位置情報共有リクエストを承認

    受信した位置情報共有リクエストを承認します。
    承認すると、リクエスト送信者があなたの位置ステータスを見られるようになります。

    Args:
        request_id: リクエストID
        current_user: 現在のユーザー
        friend_service: フレンドサービス

    Returns:
        承認結果

    Raises:
        HTTPException: リクエストが見つからない、権限がない場合
    """
    try:
        friendship = await friend_service.accept_location_share_request(
            current_user.uid, request_id
        )
        return {
            "message": "位置情報共有リクエストを承認しました",
            "friendship_id": friendship.friendship_id,
        }
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.post("/location-share/requests/{request_id}/reject", response_model=dict)
async def reject_location_share_request(
    request_id: str = Path(..., description="リクエストID"),
    current_user: UserInDB = Depends(get_current_user),
    friend_service: FriendService = Depends(lambda: FriendService()),
):
    """
    位置情報共有リクエストを拒否

    受信した位置情報共有リクエストを拒否します。

    Args:
        request_id: リクエストID
        current_user: 現在のユーザー
        friend_service: フレンドサービス

    Returns:
        拒否結果

    Raises:
        HTTPException: リクエストが見つからない、権限がない場合
    """
    try:
        await friend_service.reject_location_share_request(current_user.uid, request_id)
        return {"message": "位置情報共有リクエストを拒否しました"}
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.post("/{friend_id}/location-share/revoke", response_model=dict)
async def revoke_location_share(
    friend_id: str = Path(..., description="共有を停止する相手のUID"),
    current_user: UserInDB = Depends(get_current_user),
    friend_service: FriendService = Depends(lambda: FriendService()),
):
    """
    位置情報共有を停止

    承認済みの位置情報共有を停止します。
    相手はあなたの位置ステータスを見られなくなります。

    Args:
        friend_id: 共有を停止する相手のUID（位置を見ている人）
        current_user: 現在のユーザー
        friend_service: フレンドサービス

    Returns:
        停止結果

    Raises:
        HTTPException: フレンド関係が見つからない、既に共有していない場合
    """
    try:
        await friend_service.revoke_location_share(current_user.uid, friend_id)
        return {"message": "位置情報共有を停止しました"}
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
