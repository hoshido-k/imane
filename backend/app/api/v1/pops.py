"""
ポップ管理APIエンドポイント
"""

from fastapi import APIRouter, Depends, HTTPException, Path, Query, status

from app.api.dependencies import get_current_user
from app.schemas.pop import (
    CATEGORIES,
    CategoryListResponse,
    PopCreate,
    PopListResponse,
    PopResponse,
    PopSearchRequest,
    PopUpdate,
)
from app.schemas.user import UserInDB
from app.services.pops import PopService

router = APIRouter()


@router.post("", response_model=PopResponse, status_code=status.HTTP_201_CREATED)
async def create_pop(
    pop_data: PopCreate,
    current_user: UserInDB = Depends(get_current_user),
    pop_service: PopService = Depends(lambda: PopService()),
):
    """
    ポップを投稿

    地図上に表示されるポップ（募集）を投稿します。
    投稿されたポップは指定した有効期間（15〜60分）で自動的に消滅します。

    Args:
        pop_data: ポップデータ（内容、カテゴリ、位置情報、有効期間）
        current_user: 現在のユーザー
        pop_service: ポップサービス

    Returns:
        作成されたポップ情報

    Raises:
        HTTPException: バリデーションエラー
    """
    try:
        pop = await pop_service.create_pop(current_user.uid, pop_data)
        return pop
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.post("/search", response_model=PopListResponse)
async def search_nearby_pops(
    search_request: PopSearchRequest,
    current_user: UserInDB = Depends(get_current_user),
    pop_service: PopService = Depends(lambda: PopService()),
):
    """
    周辺のポップを検索

    指定した位置情報を中心に、一定範囲内のポップを検索します。
    カテゴリフィルター、範囲指定が可能です。

    Args:
        search_request: 検索条件（中心座標、範囲、カテゴリ）
        current_user: 現在のユーザー
        pop_service: ポップサービス

    Returns:
        検索結果のポップ一覧
    """
    pops = await pop_service.search_nearby_pops(search_request)
    return PopListResponse(
        pops=pops, total=len(pops), has_more=len(pops) >= search_request.limit
    )


@router.get("/my", response_model=PopListResponse)
async def get_my_pops(
    include_expired: bool = Query(False, description="期限切れポップも含めるか"),
    current_user: UserInDB = Depends(get_current_user),
    pop_service: PopService = Depends(lambda: PopService()),
):
    """
    自分が投稿したポップ一覧を取得

    自分が投稿した全てのポップを取得します。
    デフォルトでは有効なポップのみ、include_expired=trueで期限切れも含めます。

    Args:
        include_expired: 期限切れポップも含めるか
        current_user: 現在のユーザー
        pop_service: ポップサービス

    Returns:
        ポップ一覧
    """
    pops = await pop_service.get_user_pops(current_user.uid, include_expired)
    return PopListResponse(pops=pops, total=len(pops), has_more=False)


@router.get("/categories", response_model=CategoryListResponse)
async def get_categories():
    """
    カテゴリ一覧を取得

    ポップ投稿時に使用できるカテゴリの一覧を取得します。
    各カテゴリには名前、アイコン、表示色が含まれます。

    Returns:
        カテゴリ一覧
    """
    return CategoryListResponse(categories=CATEGORIES)


@router.get("/{pop_id}", response_model=PopResponse)
async def get_pop(
    pop_id: str = Path(..., description="ポップID"),
    current_user: UserInDB = Depends(get_current_user),
    pop_service: PopService = Depends(lambda: PopService()),
):
    """
    ポップの詳細情報を取得

    指定したIDのポップの詳細情報を取得します。

    Args:
        pop_id: ポップID
        current_user: 現在のユーザー
        pop_service: ポップサービス

    Returns:
        ポップの詳細情報

    Raises:
        HTTPException: ポップが見つからない場合
    """
    pop = await pop_service.get_pop_by_id(pop_id)
    if not pop:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="ポップが見つかりません"
        )
    return pop


@router.patch("/{pop_id}", response_model=PopResponse)
async def update_pop(
    pop_id: str = Path(..., description="ポップID"),
    update_data: PopUpdate = ...,
    current_user: UserInDB = Depends(get_current_user),
    pop_service: PopService = Depends(lambda: PopService()),
):
    """
    ポップを更新

    自分が投稿したポップの内容やカテゴリを更新します。
    投稿者のみが更新可能です。

    Args:
        pop_id: ポップID
        update_data: 更新データ
        current_user: 現在のユーザー
        pop_service: ポップサービス

    Returns:
        更新後のポップ情報

    Raises:
        HTTPException: ポップが見つからない、権限がない場合
    """
    try:
        await pop_service.update_pop(pop_id, current_user.uid, update_data)
        updated_pop = await pop_service.get_pop_by_id(pop_id)
        return updated_pop
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.delete("/{pop_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_pop(
    pop_id: str = Path(..., description="ポップID"),
    current_user: UserInDB = Depends(get_current_user),
    pop_service: PopService = Depends(lambda: PopService()),
):
    """
    ポップを削除

    自分が投稿したポップを削除します。
    論理削除されるため、データベースから完全には削除されません。
    投稿者のみが削除可能です。

    Args:
        pop_id: ポップID
        current_user: 現在のユーザー
        pop_service: ポップサービス

    Raises:
        HTTPException: ポップが見つからない、権限がない場合
    """
    try:
        await pop_service.delete_pop(pop_id, current_user.uid)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
