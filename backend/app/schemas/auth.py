"""
認証関連のPydanticスキーマ定義
"""

from pydantic import BaseModel, EmailStr, Field
from typing import Optional


class SignupRequest(BaseModel):
    """ユーザー登録リクエスト"""
    username: str = Field(..., min_length=3, max_length=20, pattern="^[a-zA-Z0-9_]+$", description="一意のユーザID（英数字とアンダースコアのみ）")
    email: EmailStr
    password: str = Field(..., min_length=8, max_length=128)
    display_name: str = Field(..., min_length=1, max_length=50)


class LoginRequest(BaseModel):
    """ログインリクエスト"""
    email: EmailStr
    password: str = Field(..., min_length=1)


class TokenResponse(BaseModel):
    """トークンレスポンス"""
    access_token: str
    token_type: str = "bearer"
    expires_in: int = Field(..., description="有効期限（秒）")
    uid: str = Field(..., description="ユーザID")


class TokenData(BaseModel):
    """トークンから取得したデータ"""
    uid: Optional[str] = None
    email: Optional[str] = None


class FirebaseTokenRequest(BaseModel):
    """Firebase IDトークンを使った認証リクエスト"""
    id_token: str = Field(..., description="Firebase ID Token")


class RefreshTokenRequest(BaseModel):
    """トークンリフレッシュリクエスト"""
    refresh_token: str
