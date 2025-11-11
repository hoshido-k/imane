"""
お気に入り場所関連のPydanticスキーマ定義

Firestoreのfavorites コレクション構造:
{
    "id": "auto-generated",
    "user_id": "firebase_auth_uid",
    "name": "よく行くカフェ",
    "address": "東京都渋谷区道玄坂1-1-1",
    "coords": {
        "lat": 35.6580,
        "lng": 139.7016
    },
    "created_at": "2025-01-15T10:00:00Z"
}
"""

from datetime import datetime
from typing import List

from pydantic import BaseModel, ConfigDict, Field

from app.utils.timezone import now_jst


class Coordinates(BaseModel):
    """座標情報"""

    lat: float = Field(..., ge=-90, le=90, description="緯度")
    lng: float = Field(..., ge=-180, le=180, description="経度")


class FavoriteLocationBase(BaseModel):
    """お気に入り場所の基本情報"""

    name: str = Field(..., min_length=1, max_length=100, description="場所の名前")
    address: str = Field(..., min_length=1, max_length=200, description="住所")
    coords: Coordinates = Field(..., description="座標")


class FavoriteLocationCreate(FavoriteLocationBase):
    """お気に入り場所作成リクエスト"""

    pass


class FavoriteLocationInDB(FavoriteLocationBase):
    """データベース内のお気に入り場所"""

    id: str = Field(..., description="お気に入りID")
    user_id: str = Field(..., description="ユーザID")
    created_at: datetime = Field(default_factory=now_jst)

    model_config = ConfigDict(from_attributes=True)


class FavoriteLocationResponse(BaseModel):
    """お気に入り場所のレスポンス"""

    id: str
    user_id: str
    name: str
    address: str
    coords: Coordinates
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class FavoriteLocationListResponse(BaseModel):
    """お気に入り場所一覧のレスポンス"""

    favorites: List[FavoriteLocationResponse]
    total: int = Field(..., description="総件数")
