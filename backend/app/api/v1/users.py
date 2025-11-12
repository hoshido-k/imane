"""
ユーザー管理APIエンドポイント
"""

from typing import List

from fastapi import APIRouter, Depends, File, HTTPException, Path, Query, UploadFile, status

from app.api.dependencies import get_current_user
from app.schemas.user import UserDetailResponse, UserInDB, UserResponse, UserUpdate
from app.services.users import UserService

router = APIRouter()


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


@router.get("/check-username")
async def check_username_availability(
    username: str = Query(..., min_length=3, max_length=20, description="チェックするユーザID"),
    user_service: UserService = Depends(lambda: UserService()),
):
    """
    ユーザIDの利用可否をチェック（認証不要）

    サインアップ時にユーザIDが既に使用されているかをチェックします。

    Args:
        username: チェックするユーザID
        user_service: ユーザーサービス

    Returns:
        available: 利用可能かどうか（True=利用可能、False=既に使用されている）
    """
    is_available = await user_service.check_username_availability(username)
    return {"available": is_available}


@router.get("/check-email")
async def check_email_availability(
    email: str = Query(..., description="チェックするメールアドレス"),
    user_service: UserService = Depends(lambda: UserService()),
):
    """
    メールアドレスの利用可否をチェック（認証不要）

    サインアップ時にメールアドレスが既に使用されているかをチェックします。

    Args:
        email: チェックするメールアドレス
        user_service: ユーザーサービス

    Returns:
        available: 利用可能かどうか（True=利用可能、False=既に使用されている）
    """
    is_available = await user_service.check_email_availability(email)
    return {"available": is_available}


@router.get("/search", response_model=List[UserResponse])
async def search_users(
    q: str = Query(..., min_length=1, description="検索クエリ（ユーザID）"),
    limit: int = Query(20, ge=1, le=50, description="取得件数の上限"),
    current_user: UserInDB = Depends(get_current_user),
    user_service: UserService = Depends(lambda: UserService()),
):
    """
    ユーザーをIDで検索

    ユーザID（username）でユーザーを検索します。
    自分自身は検索結果から除外されます。

    Args:
        q: 検索クエリ（username）
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
            username=user.username,
            email=user.email,
            display_name=user.display_name,
            profile_image_url=user.profile_image_url,
            created_at=user.created_at,
        )
        for user in users
    ]


@router.get("/{uid}", response_model=UserResponse)
async def get_user(
    uid: str = Path(..., description="ユーザID"),
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
        username=user.username,
        email=user.email,
        display_name=user.display_name,
        profile_image_url=user.profile_image_url,
        created_at=user.created_at,
    )


@router.delete("/me")
async def delete_my_account(
    current_user: UserInDB = Depends(get_current_user),
    user_service: UserService = Depends(lambda: UserService()),
):
    """
    自分のアカウントを完全に削除

    ユーザーアカウントとすべての関連データ（フレンド、スケジュール、位置情報履歴など）を削除します。
    この操作は取り消せません。

    Args:
        current_user: 現在のユーザー
        user_service: ユーザーサービス

    Returns:
        削除完了メッセージ
    """
    try:
        await user_service.delete_user(current_user.uid)
        return {
            "message": "アカウントを削除しました",
            "deleted_user_id": current_user.uid,
        }
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
    except Exception as e:
        print(f"[delete_my_account] Exception: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"アカウントの削除に失敗しました: {str(e)}",
        )


@router.post("/me/profile-image")
async def upload_profile_image(
    file: UploadFile = File(...),
    current_user: UserInDB = Depends(get_current_user),
    user_service: UserService = Depends(lambda: UserService()),
):
    """
    プロフィール画像をアップロード

    画像ファイルをFirebase Storageにアップロードし、プロフィール画像URLを更新します。

    Args:
        file: アップロードする画像ファイル（JPEG, PNG, GIF）
        current_user: 現在のユーザー
        user_service: ユーザーサービス

    Returns:
        アップロードされた画像のURL
    """
    print(f"[upload_profile_image] User: {current_user.uid}")
    print(f"[upload_profile_image] Filename: {file.filename}")
    print(f"[upload_profile_image] Content-Type: {file.content_type}")

    # Validate file type
    if not file.content_type or not file.content_type.startswith("image/"):
        print(f"[upload_profile_image] Invalid content type: {file.content_type}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="画像ファイルのみアップロード可能です",
        )

    # Validate file size (max 5MB)
    MAX_FILE_SIZE = 5 * 1024 * 1024  # 5MB
    contents = await file.read()
    print(f"[upload_profile_image] File size: {len(contents)} bytes")

    if len(contents) > MAX_FILE_SIZE:
        print(f"[upload_profile_image] File too large: {len(contents)} > {MAX_FILE_SIZE}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="ファイルサイズは5MB以下にしてください",
        )

    try:
        # Upload to Firebase Storage and update user profile
        print("[upload_profile_image] Uploading to Firebase Storage...")
        image_url = await user_service.upload_profile_image(
            current_user.uid, contents, file.content_type
        )
        print(f"[upload_profile_image] Upload successful: {image_url}")

        return {
            "profile_image_url": image_url,
            "message": "プロフィール画像を更新しました",
        }
    except ValueError as e:
        print(f"[upload_profile_image] ValueError: {e}")
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
    except Exception as e:
        print(f"[upload_profile_image] Exception: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"画像のアップロードに失敗しました: {str(e)}",
        )
