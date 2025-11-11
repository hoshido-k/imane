"""
ポップ（Pop）関連のPydanticスキーマ定義

Firestoreのpopsコレクション構造:
{
    "pop_id": "auto_generated",
    "user_id": "firebase_auth_uid",
    "content": "渋谷でランチしませんか？",
    "category": "food",
    "location": {
        "latitude": 35.6812,
        "longitude": 139.7671,
        "geohash": "xn774c"
    },
    "created_at": "2024-01-01T00:00:00Z",
    "expires_at": "2024-01-01T01:00:00Z",
    "duration_minutes": 60,
    "reaction_count": 5,
    "is_premium": false,
    "status": "active",
    "visibility": "public"
}
"""

from datetime import datetime, timedelta
from enum import Enum
from typing import Optional

from pydantic import BaseModel, ConfigDict, Field

from app.utils.timezone import now_jst, JST


class PopCategory(str, Enum):
    """ポップのカテゴリ"""

    FOOD = "food"  # 食事・カフェ
    HOBBY = "hobby"  # 趣味
    SPORTS = "sports"  # スポーツ
    STUDY = "study"  # 作業・勉強
    EVENT = "event"  # イベント
    BUSINESS = "business"  # ビジネス
    GAME = "game"  # ゲーム
    OTHER = "other"  # その他


class PopStatus(str, Enum):
    """ポップのステータス"""

    ACTIVE = "active"  # 有効
    EXPIRED = "expired"  # 期限切れ
    DELETED = "deleted"  # 削除済み


class PopVisibility(str, Enum):
    """ポップの公開範囲"""

    PUBLIC = "public"  # 全体公開
    FRIENDS_ONLY = "friends_only"  # フレンド限定


class Location(BaseModel):
    """位置情報"""

    latitude: float = Field(..., ge=-90, le=90, description="緯度")
    longitude: float = Field(..., ge=-180, le=180, description="経度")
    geohash: Optional[str] = Field(None, description="Geohash（自動生成）")


class PopBase(BaseModel):
    """ポップの基本情報"""

    content: str = Field(..., min_length=1, max_length=500, description="投稿内容")
    category: PopCategory = Field(..., description="カテゴリ")
    location: Location = Field(..., description="位置情報")


class PopCreate(PopBase):
    """ポップ作成時のリクエスト"""

    duration_minutes: int = Field(
        default=30, ge=15, le=60, description="有効期間（分）15, 30, 45, 60のいずれか"
    )
    visibility: PopVisibility = Field(default=PopVisibility.PUBLIC, description="公開範囲")
    is_premium: bool = Field(default=False, description="有料ポップかどうか")

    def validate_duration(self) -> bool:
        """有効期間が15分刻みかチェック"""
        return self.duration_minutes in [15, 30, 45, 60]


class PopUpdate(BaseModel):
    """ポップ更新時のリクエスト"""

    content: Optional[str] = Field(None, min_length=1, max_length=500)
    category: Optional[PopCategory] = None


class PopInDB(PopBase):
    """データベース内のポップ情報"""

    pop_id: str = Field(..., description="ポップID")
    user_id: str = Field(..., description="投稿者のUID")
    created_at: datetime = Field(default_factory=now_jst)
    expires_at: datetime = Field(..., description="有効期限")
    duration_minutes: int = Field(..., description="有効期間（分）")
    reaction_count: int = Field(default=0, description="リアクション数")
    is_premium: bool = Field(default=False, description="有料ポップ")
    status: PopStatus = Field(default=PopStatus.ACTIVE, description="ステータス")
    visibility: PopVisibility = Field(default=PopVisibility.PUBLIC, description="公開範囲")

    model_config = ConfigDict(from_attributes=True)

    def is_active(self) -> bool:
        """ポップが有効かチェック"""
        now = datetime.now(JST)
        return self.status == PopStatus.ACTIVE and self.expires_at > now

    def remaining_minutes(self) -> int:
        """残り時間（分）を計算"""
        if not self.is_active():
            return 0
        now = datetime.now(JST)
        delta = self.expires_at - now
        return max(0, int(delta.total_seconds() / 60))

    def shrink_ratio(self) -> float:
        """Time-Dimming Pop機能：残り時間に応じた縮小率を計算

        Returns:
            float: 表示サイズの比率（1.0 = 100%, 0.4 = 40%）
        """
        remaining = self.remaining_minutes()
        total = self.duration_minutes

        if remaining >= total * 0.5:  # 残り50%以上
            return 1.0
        elif remaining >= total * 0.33:  # 残り33-50%
            return 0.8
        elif remaining >= total * 0.17:  # 残り17-33%
            return 0.6
        else:  # 残り17%未満
            return 0.4


class PopResponse(PopBase):
    """ポップ情報のレスポンス"""

    pop_id: str
    user_id: str
    created_at: datetime
    expires_at: datetime
    duration_minutes: int
    reaction_count: int
    is_premium: bool
    status: PopStatus
    visibility: PopVisibility
    remaining_minutes: Optional[int] = Field(None, description="残り時間（分）")
    shrink_ratio: Optional[float] = Field(None, description="縮小率（Time-Dimming）")

    model_config = ConfigDict(from_attributes=True)


class PopListResponse(BaseModel):
    """ポップ一覧のレスポンス"""

    pops: list[PopResponse]
    total: int
    has_more: bool = False


class PopSearchRequest(BaseModel):
    """ポップ検索リクエスト"""

    latitude: float = Field(..., ge=-90, le=90, description="検索中心の緯度")
    longitude: float = Field(..., ge=-180, le=180, description="検索中心の経度")
    radius_km: float = Field(default=5.0, ge=0.1, le=50.0, description="検索半径（km）")
    categories: Optional[list[PopCategory]] = Field(None, description="フィルターするカテゴリ")
    limit: int = Field(default=50, ge=1, le=100, description="取得件数")
    only_active: bool = Field(default=True, description="有効なポップのみ取得")


class CategoryInfo(BaseModel):
    """カテゴリ情報"""

    id: str
    name: str
    icon: str
    color: str


class CategoryListResponse(BaseModel):
    """カテゴリ一覧のレスポンス"""

    categories: list[CategoryInfo]


# カテゴリマスターデータ
CATEGORIES = [
    CategoryInfo(id="food", name="食事・カフェ", icon="🍽️", color="#FF6B6B"),
    CategoryInfo(id="hobby", name="趣味", icon="🎮", color="#4ECDC4"),
    CategoryInfo(id="sports", name="スポーツ", icon="💪", color="#45B7D1"),
    CategoryInfo(id="study", name="作業・勉強", icon="📚", color="#96CEB4"),
    CategoryInfo(id="event", name="イベント", icon="🎉", color="#FFEAA7"),
    CategoryInfo(id="business", name="ビジネス", icon="💼", color="#DFE6E9"),
]
