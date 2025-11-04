"""
FastAPI 依存性注入（Dependency Injection）
"""

from typing import Optional
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from app.utils.jwt import verify_token
from app.services.auth import AuthService
from app.schemas.user import UserInDB

# HTTPベアラー認証
security = HTTPBearer()


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    auth_service: AuthService = Depends(lambda: AuthService())
) -> UserInDB:
    """
    認証トークンから現在のユーザーを取得

    Args:
        credentials: HTTPベアラー認証の認証情報
        auth_service: 認証サービス

    Returns:
        現在のユーザー情報

    Raises:
        HTTPException: 認証失敗時
    """
    token = credentials.credentials

    # トークンを検証
    payload = verify_token(token)
    if payload is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="認証トークンが無効です",
            headers={"WWW-Authenticate": "Bearer"},
        )

    # UIDを取得
    uid: Optional[str] = payload.get("uid")
    if uid is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="トークンにユーザーIDが含まれていません",
            headers={"WWW-Authenticate": "Bearer"},
        )

    # ユーザー情報を取得
    user = await auth_service.get_user_by_uid(uid)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="ユーザーが見つかりません",
            headers={"WWW-Authenticate": "Bearer"},
        )

    return user


async def get_optional_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security),
    auth_service: AuthService = Depends(lambda: AuthService())
) -> Optional[UserInDB]:
    """
    認証トークンから現在のユーザーを取得（オプショナル）

    認証が必須ではないエンドポイントで使用

    Args:
        credentials: HTTPベアラー認証の認証情報
        auth_service: 認証サービス

    Returns:
        ユーザー情報、認証されていない場合はNone
    """
    if credentials is None:
        return None

    try:
        return await get_current_user(credentials, auth_service)
    except HTTPException:
        return None
