"""
リアクション管理APIエンドポイント
"""

from fastapi import APIRouter, Depends, HTTPException, Path, Query, status

from app.api.dependencies import get_current_user
from app.schemas.reaction import (
    ReactionCreate,
    ReactionListResponse,
    ReactionResponse,
    ReactionStatus,
)
from app.schemas.user import UserInDB
from app.services.reactions import ReactionService

router = APIRouter()


@router.post("", response_model=ReactionResponse, status_code=status.HTTP_201_CREATED)
async def send_reaction(
    reaction_data: ReactionCreate,
    current_user: UserInDB = Depends(get_current_user),
    reaction_service: ReactionService = Depends(lambda: ReactionService()),
):
    """
    リアクションを送信

    ポップに「興味あり」のリアクションを送信します。
    任意でメッセージを添付できます。

    Args:
        reaction_data: リアクションデータ（ポップID、メッセージ）
        current_user: 現在のユーザー
        reaction_service: リアクションサービス

    Returns:
        送信されたリアクション情報

    Raises:
        HTTPException: ポップが見つからない、自分のポップへのリアクション、重複リアクション
    """
    try:
        reaction = await reaction_service.create_reaction(current_user.uid, reaction_data)
        return reaction
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.get("/received", response_model=ReactionListResponse)
async def get_received_reactions(
    status_filter: ReactionStatus = Query(None, description="ステータスフィルター"),
    current_user: UserInDB = Depends(get_current_user),
    reaction_service: ReactionService = Depends(lambda: ReactionService()),
):
    """
    受信したリアクション一覧を取得

    自分のポップに送られてきたリアクションの一覧を取得します。

    Args:
        status_filter: ステータスフィルター（pending, accepted, rejected, cancelled）
        current_user: 現在のユーザー
        reaction_service: リアクションサービス

    Returns:
        受信したリアクション一覧
    """
    reactions = await reaction_service.get_received_reactions(current_user.uid, status_filter)
    unread_count = await reaction_service.get_unread_count(current_user.uid)

    return ReactionListResponse(
        reactions=reactions, total=len(reactions), unread_count=unread_count
    )


@router.get("/sent", response_model=ReactionListResponse)
async def get_sent_reactions(
    status_filter: ReactionStatus = Query(None, description="ステータスフィルター"),
    current_user: UserInDB = Depends(get_current_user),
    reaction_service: ReactionService = Depends(lambda: ReactionService()),
):
    """
    送信したリアクション一覧を取得

    自分が送信したリアクションの一覧を取得します。

    Args:
        status_filter: ステータスフィルター（pending, accepted, rejected, cancelled）
        current_user: 現在のユーザー
        reaction_service: リアクションサービス

    Returns:
        送信したリアクション一覧
    """
    reactions = await reaction_service.get_sent_reactions(current_user.uid, status_filter)

    return ReactionListResponse(reactions=reactions, total=len(reactions), unread_count=0)


@router.get("/pops/{pop_id}", response_model=ReactionListResponse)
async def get_pop_reactions(
    pop_id: str = Path(..., description="ポップID"),
    current_user: UserInDB = Depends(get_current_user),
    reaction_service: ReactionService = Depends(lambda: ReactionService()),
):
    """
    特定のポップへのリアクション一覧を取得

    指定したポップに送られたリアクションの一覧を取得します。
    ポップの投稿者のみが閲覧可能です。

    Args:
        pop_id: ポップID
        current_user: 現在のユーザー
        reaction_service: リアクションサービス

    Returns:
        リアクション一覧

    Raises:
        HTTPException: 権限がない場合
    """
    reactions = await reaction_service.get_pop_reactions(pop_id)

    # ポップの投稿者かチェック（簡易実装）
    # より厳密にはPopServiceでポップの所有者を確認
    if reactions and reactions[0].to_user_id != current_user.uid:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="このポップのリアクションを閲覧する権限がありません",
        )

    return ReactionListResponse(reactions=reactions, total=len(reactions), unread_count=0)


@router.get("/unread-count", response_model=dict)
async def get_unread_count(
    current_user: UserInDB = Depends(get_current_user),
    reaction_service: ReactionService = Depends(lambda: ReactionService()),
):
    """
    未読リアクション数を取得

    自分のポップに送られてきた未読（pending）リアクションの数を取得します。

    Args:
        current_user: 現在のユーザー
        reaction_service: リアクションサービス

    Returns:
        未読リアクション数
    """
    unread_count = await reaction_service.get_unread_count(current_user.uid)
    return {"unread_count": unread_count}


@router.get("/{reaction_id}", response_model=ReactionResponse)
async def get_reaction(
    reaction_id: str = Path(..., description="リアクションID"),
    current_user: UserInDB = Depends(get_current_user),
    reaction_service: ReactionService = Depends(lambda: ReactionService()),
):
    """
    リアクションの詳細情報を取得

    指定したIDのリアクションの詳細情報を取得します。

    Args:
        reaction_id: リアクションID
        current_user: 現在のユーザー
        reaction_service: リアクションサービス

    Returns:
        リアクションの詳細情報

    Raises:
        HTTPException: リアクションが見つからない場合
    """
    reaction = await reaction_service.get_reaction_by_id(reaction_id)
    if not reaction:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="リアクションが見つかりません"
        )

    # 送信者または受信者のみ閲覧可能
    if reaction.from_user_id != current_user.uid and reaction.to_user_id != current_user.uid:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="このリアクションを閲覧する権限がありません",
        )

    return reaction


@router.post("/{reaction_id}/accept", response_model=dict)
async def accept_reaction(
    reaction_id: str = Path(..., description="リアクションID"),
    current_user: UserInDB = Depends(get_current_user),
    reaction_service: ReactionService = Depends(lambda: ReactionService()),
):
    """
    リアクションを承認（マッチング成立）

    受信したリアクションを承認します。
    承認するとマッチングが成立し、チャットが開始できます。

    Args:
        reaction_id: リアクションID
        current_user: 現在のユーザー
        reaction_service: リアクションサービス

    Returns:
        承認結果

    Raises:
        HTTPException: リアクションが見つからない、権限がない場合
    """
    try:
        await reaction_service.accept_reaction(reaction_id, current_user.uid)
        return {"message": "リアクションを承認しました", "reaction_id": reaction_id}
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.post("/{reaction_id}/reject", response_model=dict)
async def reject_reaction(
    reaction_id: str = Path(..., description="リアクションID"),
    current_user: UserInDB = Depends(get_current_user),
    reaction_service: ReactionService = Depends(lambda: ReactionService()),
):
    """
    リアクションを拒否

    受信したリアクションを拒否します。

    Args:
        reaction_id: リアクションID
        current_user: 現在のユーザー
        reaction_service: リアクションサービス

    Returns:
        拒否結果

    Raises:
        HTTPException: リアクションが見つからない、権限がない場合
    """
    try:
        await reaction_service.reject_reaction(reaction_id, current_user.uid)
        return {"message": "リアクションを拒否しました", "reaction_id": reaction_id}
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.delete("/{reaction_id}", status_code=status.HTTP_204_NO_CONTENT)
async def cancel_reaction(
    reaction_id: str = Path(..., description="リアクションID"),
    current_user: UserInDB = Depends(get_current_user),
    reaction_service: ReactionService = Depends(lambda: ReactionService()),
):
    """
    リアクションをキャンセル

    送信したリアクションをキャンセルします。
    送信者のみがキャンセル可能です。

    Args:
        reaction_id: リアクションID
        current_user: 現在のユーザー
        reaction_service: リアクションサービス

    Raises:
        HTTPException: リアクションが見つからない、権限がない場合
    """
    try:
        await reaction_service.cancel_reaction(reaction_id, current_user.uid)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
