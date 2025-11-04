"""
認証関連のAPIエンドポイント
"""

from fastapi import APIRouter, Depends, HTTPException, status

from app.api.dependencies import get_current_user
from app.schemas.auth import FirebaseTokenRequest, SignupRequest, TokenResponse
from app.schemas.user import UserDetailResponse, UserInDB
from app.services.auth import AuthService

router = APIRouter()


@router.post("/signup", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
async def signup(
    request: SignupRequest,
    auth_service: AuthService = Depends(lambda: AuthService())
):
    """
    新規ユーザー登録

    Firebase Authenticationでユーザーを作成し、
    Firestoreにユーザー情報を保存します。

    Args:
        request: 登録リクエスト（メール、パスワード、表示名）
        auth_service: 認証サービス

    Returns:
        アクセストークンとユーザー情報

    Raises:
        HTTPException: 登録失敗時（メールアドレス重複など）
    """
    try:
        token_response = await auth_service.signup(request)
        return token_response
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )


@router.post("/login", response_model=TokenResponse)
async def login(
    request: FirebaseTokenRequest,
    auth_service: AuthService = Depends(lambda: AuthService())
):
    """
    ログイン（Firebase IDトークンで認証）

    モバイルアプリでFirebase Authenticationで取得したIDトークンを使って
    バックエンドのJWTトークンを発行します。

    Args:
        request: Firebase IDトークン
        auth_service: 認証サービス

    Returns:
        アクセストークン

    Raises:
        HTTPException: 認証失敗時
    """
    try:
        token_response = await auth_service.login_with_firebase_token(request.id_token)
        return token_response
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=str(e),
            headers={"WWW-Authenticate": "Bearer"},
        )


@router.get("/me", response_model=UserDetailResponse)
async def get_current_user_info(
    current_user: UserInDB = Depends(get_current_user)
):
    """
    現在のユーザー情報を取得

    認証トークンから現在ログイン中のユーザーの詳細情報を取得します。

    Args:
        current_user: 現在のユーザー（依存性注入）

    Returns:
        ユーザー詳細情報（住所含む）
    """
    return UserDetailResponse(
        uid=current_user.uid,
        email=current_user.email,
        display_name=current_user.display_name,
        profile_image_url=current_user.profile_image_url,
        home_address=current_user.home_address,
        work_address=current_user.work_address,
        custom_locations=current_user.custom_locations,
        created_at=current_user.created_at,
        updated_at=current_user.updated_at
    )


@router.delete("/me", status_code=status.HTTP_204_NO_CONTENT)
async def delete_account(
    current_user: UserInDB = Depends(get_current_user),
    auth_service: AuthService = Depends(lambda: AuthService())
):
    """
    アカウントを削除

    現在ログイン中のユーザーのアカウントを完全に削除します。
    Firebase AuthenticationとFirestoreの両方から削除されます。

    Args:
        current_user: 現在のユーザー（依存性注入）
        auth_service: 認証サービス

    Raises:
        HTTPException: 削除失敗時
    """
    success = await auth_service.delete_user(current_user.uid)
    if not success:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="アカウントの削除に失敗しました"
        )


@router.post("/fcm-token")
async def register_fcm_token(
    fcm_token: str,
    current_user: UserInDB = Depends(get_current_user),
    auth_service: AuthService = Depends(lambda: AuthService())
):
    """
    FCMトークンを登録

    プッシュ通知用のFCMトークンをユーザーに紐づけます。

    Args:
        fcm_token: FCMトークン
        current_user: 現在のユーザー（依存性注入）
        auth_service: 認証サービス

    Returns:
        成功メッセージ

    Raises:
        HTTPException: 登録失敗時
    """
    success = await auth_service.update_fcm_token(current_user.uid, fcm_token)
    if not success:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="FCMトークンの登録に失敗しました"
        )

    return {"message": "FCMトークンを登録しました"}


@router.delete("/fcm-token")
async def unregister_fcm_token(
    fcm_token: str,
    current_user: UserInDB = Depends(get_current_user),
    auth_service: AuthService = Depends(lambda: AuthService())
):
    """
    FCMトークンを削除

    ログアウト時やデバイス変更時にFCMトークンを削除します。

    Args:
        fcm_token: FCMトークン
        current_user: 現在のユーザー（依存性注入）
        auth_service: 認証サービス

    Returns:
        成功メッセージ

    Raises:
        HTTPException: 削除失敗時
    """
    success = await auth_service.remove_fcm_token(current_user.uid, fcm_token)
    if not success:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="FCMトークンの削除に失敗しました"
        )

    return {"message": "FCMトークンを削除しました"}
