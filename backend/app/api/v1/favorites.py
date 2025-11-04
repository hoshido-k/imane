"""
お気に入り場所管理APIエンドポイント
"""

from fastapi import APIRouter, Depends, HTTPException, Path, status

from app.api.dependencies import get_current_user
from app.schemas.favorite import (
    FavoriteLocationCreate,
    FavoriteLocationListResponse,
    FavoriteLocationResponse,
)
from app.schemas.user import UserInDB
from app.services.favorites import FavoriteService

router = APIRouter()


@router.post("", response_model=FavoriteLocationResponse, status_code=status.HTTP_201_CREATED)
async def create_favorite(
    favorite_data: FavoriteLocationCreate,
    current_user: UserInDB = Depends(get_current_user),
    favorite_service: FavoriteService = Depends(lambda: FavoriteService()),
):
    """
    お気に入り場所を作成

    よく行く場所をお気に入りとして登録します。
    スケジュール作成時に選択できるようになります。

    Args:
        favorite_data: お気に入り場所作成データ
        current_user: 現在のユーザー
        favorite_service: お気に入りサービス

    Returns:
        作成されたお気に入り場所情報
    """
    favorite = await favorite_service.create_favorite(current_user.uid, favorite_data)
    return FavoriteLocationResponse(**favorite.model_dump())


@router.get("", response_model=FavoriteLocationListResponse)
async def get_favorites(
    current_user: UserInDB = Depends(get_current_user),
    favorite_service: FavoriteService = Depends(lambda: FavoriteService()),
):
    """
    お気に入り場所一覧を取得

    自分が登録したお気に入り場所の一覧を取得します。

    Args:
        current_user: 現在のユーザー
        favorite_service: お気に入りサービス

    Returns:
        お気に入り場所一覧
    """
    favorites = await favorite_service.get_favorites_by_user(current_user.uid)

    # FavoriteLocationInDB -> FavoriteLocationResponse に変換
    favorite_responses = [FavoriteLocationResponse(**f.model_dump()) for f in favorites]

    return FavoriteLocationListResponse(favorites=favorite_responses, total=len(favorite_responses))


@router.get("/{favorite_id}", response_model=FavoriteLocationResponse)
async def get_favorite(
    favorite_id: str = Path(..., description="お気に入りID"),
    current_user: UserInDB = Depends(get_current_user),
    favorite_service: FavoriteService = Depends(lambda: FavoriteService()),
):
    """
    お気に入り場所詳細を取得

    指定したお気に入り場所の詳細情報を取得します。

    Args:
        favorite_id: お気に入りID
        current_user: 現在のユーザー
        favorite_service: お気に入りサービス

    Returns:
        お気に入り場所詳細情報

    Raises:
        HTTPException: お気に入りが見つからない、または権限がない場合
    """
    try:
        favorite = await favorite_service.get_favorite_by_id(favorite_id, current_user.uid)

        if not favorite:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND, detail="お気に入り場所が見つかりません"
            )

        return FavoriteLocationResponse(**favorite.model_dump())
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(e))


@router.delete("/{favorite_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_favorite(
    favorite_id: str = Path(..., description="お気に入りID"),
    current_user: UserInDB = Depends(get_current_user),
    favorite_service: FavoriteService = Depends(lambda: FavoriteService()),
):
    """
    お気に入り場所を削除

    指定したお気に入り場所を削除します。

    Args:
        favorite_id: お気に入りID
        current_user: 現在のユーザー
        favorite_service: お気に入りサービス

    Raises:
        HTTPException: お気に入りが見つからない、または権限がない場合
    """
    try:
        await favorite_service.delete_favorite(favorite_id, current_user.uid)
    except ValueError as e:
        # お気に入りが見つからない場合は404、権限がない場合は403
        if "見つかりません" in str(e):
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))
        else:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(e))
