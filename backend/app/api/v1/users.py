"""
ユーザー管理APIエンドポイント
"""

from typing import List

from fastapi import APIRouter, Depends, HTTPException, Path, Query, status

from app.api.dependencies import get_current_user
from app.schemas.user import UserDetailResponse, UserInDB, UserResponse, UserUpdate
from app.services.users import UserService

router = APIRouter()


@router.get("/{uid}", response_model=UserResponse)
async def get_user(
    uid: str = Path(..., description="ユーザーID"),
    current_user: UserInDB = Depends(get_current_user),
    user_service: UserService = Depends(lambda: UserService()),
):
    """
    ユーザー情報を取得（公開情報のみ）

    他のユーザーのプロフィールを取得する際に使用します。

    Args:
        uid: 取得するユーザーのID
        current_user: 現在のユーザー（認証必須）
        user_service: ユーザーサービス

    Returns:
        ユーザーの公開情報
    """
    user = await user_service.get_user_by_uid(uid)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="ユーザーが見つかりません"
        )

    return UserResponse(
        uid=user.uid,
        email=user.email,
        display_name=user.display_name,
        profile_image_url=user.profile_image_url,
        created_at=user.created_at,
    )


@router.patch("/me", response_model=UserDetailResponse)
async def update_my_profile(
    update_data: UserUpdate,
    current_user: UserInDB = Depends(get_current_user),
    user_service: UserService = Depends(lambda: UserService()),
):
    """
    自分のプロフィールを更新

    表示名やプロフィール画像URLを更新できます。

    Args:
        update_data: 更新データ
        current_user: 現在のユーザー
        user_service: ユーザーサービス

    Returns:
        更新後のユーザー詳細情報
    """
    try:
        updated_user = await user_service.update_profile(current_user.uid, update_data)
        return UserDetailResponse(**updated_user.model_dump())
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.get("/search", response_model=List[UserResponse])
async def search_users(
    q: str = Query(..., min_length=1, description="検索クエリ（名前またはメールアドレス）"),
    limit: int = Query(20, ge=1, le=50, description="取得件数の上限"),
    current_user: UserInDB = Depends(get_current_user),
    user_service: UserService = Depends(lambda: UserService()),
):
    """
    ユーザーを検索

    表示名またはメールアドレスでユーザーを検索します。
    自分自身は検索結果から除外されます。

    Args:
        q: 検索クエリ
        limit: 取得件数の上限（デフォルト: 20、最大: 50）
        current_user: 現在のユーザー
        user_service: ユーザーサービス

    Returns:
        検索結果のユーザーリスト
    """
    users = await user_service.search_users(q, current_user.uid, limit)

    return [
        UserResponse(
            uid=user.uid,
            email=user.email,
            display_name=user.display_name,
            profile_image_url=user.profile_image_url,
            created_at=user.created_at,
        )
        for user in users
    ]
