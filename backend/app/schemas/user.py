"""
ユーザー関連のPydanticスキーマ定義

Firestoreのusersコレクション構造:
{
    "uid": "firebase_auth_uid",  # Firebase AuthのUID（ドキュメントID）
    "email": "user@example.com",
    "display_name": "ユーザー名",
    "profile_image_url": "https://...",  # オプション
    "home_address": {
        "latitude": 35.6812,
        "longitude": 139.7671,
        "registered_at": "2024-01-01T00:00:00Z",
        "last_changed_at": "2024-01-01T00:00:00Z"
    },
    "work_address": {  # オプション
        "latitude": 35.6812,
        "longitude": 139.7671,
        "registered_at": "2024-01-01T00:00:00Z",
        "last_changed_at": "2024-01-01T00:00:00Z"
    },
    "custom_locations": [  # ジム、カフェなど
        {
            "name": "よく行くカフェ",
            "latitude": 35.6812,
            "longitude": 139.7671,
            "radius_meters": 100,
            "color": "#9C27B0"  # 紫色
        }
    ],
    "fcm_tokens": ["token1", "token2"],  # プッシュ通知用
    "created_at": "2024-01-01T00:00:00Z",
    "updated_at": "2024-01-01T00:00:00Z"
}
"""

from pydantic import BaseModel, EmailStr, Field, ConfigDict
from typing import Optional, List
from datetime import datetime


class AddressBase(BaseModel):
    """住所の基本情報"""
    latitude: float = Field(..., ge=-90, le=90, description="緯度")
    longitude: float = Field(..., ge=-180, le=180, description="経度")


class Address(AddressBase):
    """登録済み住所（自宅・職場）"""
    registered_at: datetime = Field(default_factory=datetime.utcnow)
    last_changed_at: datetime = Field(default_factory=datetime.utcnow)


class CustomLocation(AddressBase):
    """カスタム場所（ジム、カフェなど）"""
    name: str = Field(..., min_length=1, max_length=50)
    radius_meters: int = Field(default=100, ge=10, le=1000)
    color: str = Field(default="#9C27B0", description="表示色（HEX）")


class UserBase(BaseModel):
    """ユーザーの基本情報"""
    email: EmailStr
    display_name: str = Field(..., min_length=1, max_length=50)


class UserCreate(UserBase):
    """ユーザー作成時のリクエスト"""
    password: str = Field(..., min_length=8, max_length=128)
    home_address: Optional[Address] = None


class UserUpdate(BaseModel):
    """ユーザー情報更新"""
    display_name: Optional[str] = Field(None, min_length=1, max_length=50)
    profile_image_url: Optional[str] = None


class UserInDB(UserBase):
    """データベース内のユーザー情報"""
    uid: str = Field(..., description="Firebase AuthのUID")
    profile_image_url: Optional[str] = None
    home_address: Optional[Address] = None
    work_address: Optional[Address] = None
    custom_locations: List[CustomLocation] = Field(default_factory=list)
    fcm_tokens: List[str] = Field(default_factory=list)
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)

    model_config = ConfigDict(from_attributes=True)


class UserResponse(BaseModel):
    """ユーザー情報のレスポンス（公開情報のみ）"""
    uid: str
    email: EmailStr
    display_name: str
    profile_image_url: Optional[str] = None
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class UserDetailResponse(UserResponse):
    """ユーザー詳細情報のレスポンス（本人のみ）"""
    home_address: Optional[Address] = None
    work_address: Optional[Address] = None
    custom_locations: List[CustomLocation] = Field(default_factory=list)
    updated_at: datetime
