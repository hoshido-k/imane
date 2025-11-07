"""
フレンド関連のPydanticスキーマ定義

Firestoreのコレクション構造:

friendships コレクション:
{
    "friendship_id": "auto-generated",
    "user_id": "uid1",  # フレンド関係の一方のユーザー
    "friend_id": "uid2",  # フレンド関係のもう一方のユーザー
    "can_see_friend_location": false,  # uid1がuid2の位置を見られるか
    "nickname": "親友の太郎",  # オプション：ニックネーム
    "created_at": "2024-01-01T00:00:00Z",
    "updated_at": "2024-01-01T00:00:00Z",
    "status": "active"  # active, blocked
}

friend_requests コレクション:
{
    "request_id": "auto-generated",
    "from_user_id": "uid1",  # リクエスト送信者
    "to_user_id": "uid2",  # リクエスト受信者
    "message": "よろしくお願いします",  # オプション
    "status": "pending",  # pending, accepted, rejected
    "created_at": "2024-01-01T00:00:00Z",
    "responded_at": "2024-01-01T00:00:00Z"  # 承認/拒否された日時
}

location_share_requests コレクション:
{
    "request_id": "auto-generated",
    "requester_id": "uid1",  # 「相手の位置を見たい」人
    "target_id": "uid2",     # 「位置を見られる」人
    "status": "pending",  # pending, accepted, rejected
    "created_at": "2024-01-01T00:00:00Z",
    "responded_at": null
}

フレンド機能の仕様:
- フレンド承認時点でチャット機能が使える
- 位置情報共有は別途の許可制（一方的な共有も可能）
- Aが「Bの位置を見たい」→ リクエスト → Bが許可 → AはBの位置を見られる
"""

from datetime import datetime
from enum import Enum
from typing import Optional

from pydantic import BaseModel, ConfigDict, Field


class FriendRequestStatus(str, Enum):
    """フレンドリクエストのステータス"""

    PENDING = "pending"
    ACCEPTED = "accepted"
    REJECTED = "rejected"


class FriendshipStatus(str, Enum):
    """フレンド関係のステータス"""

    ACTIVE = "active"
    BLOCKED = "blocked"


class TrustLevel(int, Enum):
    """
    信頼レベル (1-5) - 後方互換性のため残すが、新仕様では使用しない
    新仕様では位置情報共有は別途の許可制
    """

    ACQUAINTANCE = 1  # 知り合い
    FRIEND = 2  # 友達
    GOOD_FRIEND = 3  # 仲良し
    CLOSE_FRIEND = 4  # 親しい友達
    BEST_FRIEND = 5  # 最も親しい友達


class FriendRequestCreate(BaseModel):
    """フレンドリクエスト送信"""

    to_user_id: str = Field(..., description="リクエスト送信先のユーザID")
    message: Optional[str] = Field(None, max_length=200, description="メッセージ")


class FriendRequestResponse(BaseModel):
    """フレンドリクエストのレスポンス"""

    request_id: str
    from_user_id: str
    to_user_id: str
    message: Optional[str] = None
    status: FriendRequestStatus
    created_at: datetime
    responded_at: Optional[datetime] = None

    # リクエスト送信者の情報（JOIN用）
    from_user_display_name: Optional[str] = None
    from_user_username: Optional[str] = None
    from_user_profile_image_url: Optional[str] = None

    # リクエスト送信先の情報（JOIN用）
    to_user_display_name: Optional[str] = None
    to_user_username: Optional[str] = None
    to_user_profile_image_url: Optional[str] = None

    model_config = ConfigDict(from_attributes=True)


class FriendRequestAcceptReject(BaseModel):
    """フレンドリクエスト承認/拒否"""

    request_id: str = Field(..., description="リクエストID")


class FriendshipBase(BaseModel):
    """フレンド関係の基本情報"""

    user_id: str
    friend_id: str
    can_see_friend_location: bool = Field(
        default=False, description="このユーザーがフレンドの位置を見られるか"
    )
    nickname: Optional[str] = Field(None, max_length=50, description="フレンドに付けるニックネーム")
    # 後方互換性のため残すが、新仕様では使用しない
    trust_level: Optional[TrustLevel] = Field(
        default=TrustLevel.FRIEND, ge=1, le=5, description="旧仕様の信頼レベル（非推奨）"
    )


class FriendshipInDB(FriendshipBase):
    """データベース内のフレンド関係"""

    friendship_id: str
    status: FriendshipStatus = FriendshipStatus.ACTIVE
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)

    model_config = ConfigDict(from_attributes=True)


class FriendshipResponse(BaseModel):
    """フレンド情報のレスポンス"""

    friendship_id: str
    friend_id: str
    can_see_friend_location: bool = Field(
        default=False, description="このユーザーがフレンドの位置を見られるか"
    )
    nickname: Optional[str] = None
    status: FriendshipStatus
    created_at: datetime
    # 後方互換性のため残す
    trust_level: Optional[TrustLevel] = None

    # フレンドのユーザー情報（JOIN用）
    friend_display_name: Optional[str] = None
    friend_email: Optional[str] = None
    friend_profile_image_url: Optional[str] = None

    model_config = ConfigDict(from_attributes=True)


class FriendshipUpdate(BaseModel):
    """フレンド関係の更新"""

    can_see_friend_location: Optional[bool] = Field(
        None, description="このユーザーがフレンドの位置を見られるか"
    )
    nickname: Optional[str] = Field(None, max_length=50, description="ニックネーム")
    # 後方互換性のため残す（非推奨）
    trust_level: Optional[TrustLevel] = Field(
        None, ge=1, le=5, description="旧仕様の信頼レベル（非推奨）"
    )


class FriendListResponse(BaseModel):
    """フレンド一覧のレスポンス"""

    friends: list[FriendshipResponse]
    total: int


class FriendRequestListResponse(BaseModel):
    """フレンドリクエスト一覧のレスポンス"""

    requests: list[FriendRequestResponse]
    total: int


class LocationShareRequestCreate(BaseModel):
    """位置情報共有リクエスト送信"""

    target_user_id: str = Field(..., description="位置を見たい相手のユーザID")


class LocationShareRequestResponse(BaseModel):
    """位置情報共有リクエストのレスポンス"""

    request_id: str
    requester_id: str = Field(..., description="位置を見たい人")
    target_id: str = Field(..., description="位置を見られる人")
    status: FriendRequestStatus  # pending, accepted, rejected を再利用
    created_at: datetime
    responded_at: Optional[datetime] = None

    # リクエスト送信者の情報（JOIN用）
    requester_display_name: Optional[str] = None
    requester_profile_image_url: Optional[str] = None

    model_config = ConfigDict(from_attributes=True)


class LocationShareRequestListResponse(BaseModel):
    """位置情報共有リクエスト一覧のレスポンス"""

    requests: list[LocationShareRequestResponse]
    total: int


class LocationShareRequestAcceptReject(BaseModel):
    """位置情報共有リクエスト承認/拒否"""

    request_id: str = Field(..., description="リクエストID")
