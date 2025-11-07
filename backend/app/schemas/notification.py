"""
通知関連のPydanticスキーマ定義

Firestoreのコレクション構造:

notifications コレクション:
{
    "notification_id": "auto-generated",
    "user_id": "uid1",
    "type": "message",  # message, location_change, near_miss, friend_request
    "title": "新しいメッセージ",
    "body": "田中さんからメッセージが届きました",
    "data": {
        "sender_id": "uid2",
        "message_id": "msg_id",
        ...
    },
    "is_read": false,
    "created_at": "2024-01-01T00:00:00Z",
    "read_at": null
}

通知タイプ:
- message: 新しいメッセージ受信
- location_change: フレンドの位置情報ステータス変更
- near_miss: ニアミス検出（翌朝通知）
- friend_request: フレンドリクエスト受信
- friend_accepted: フレンドリクエスト承認
- trust_level_up: 信頼レベルアップ
"""

from datetime import datetime
from enum import Enum
from typing import Any, Optional

from pydantic import BaseModel, ConfigDict, Field


class NotificationType(str, Enum):
    """通知タイプ"""

    MESSAGE = "message"
    LOCATION_CHANGE = "location_change"
    NEAR_MISS = "near_miss"
    FRIEND_REQUEST = "friend_request"
    FRIEND_ACCEPTED = "friend_accepted"
    TRUST_LEVEL_UP = "trust_level_up"
    # imane固有の通知タイプ
    ARRIVAL = "arrival"  # 目的地到着通知
    STAY = "stay"  # 滞在通知
    DEPARTURE = "departure"  # 退出通知


class NotificationInDB(BaseModel):
    """データベース内の通知"""

    notification_id: str
    user_id: str = Field(..., description="通知を受け取るユーザID")
    type: NotificationType = Field(..., description="通知タイプ")
    title: str = Field(..., max_length=100, description="通知タイトル")
    body: str = Field(..., max_length=500, description="通知本文")
    data: dict[str, Any] = Field(default_factory=dict, description="追加データ")
    is_read: bool = Field(default=False, description="既読フラグ")
    created_at: datetime = Field(default_factory=datetime.utcnow)
    read_at: Optional[datetime] = Field(None, description="既読日時")

    model_config = ConfigDict(from_attributes=True)


class NotificationResponse(BaseModel):
    """通知のレスポンス"""

    notification_id: str
    user_id: str
    type: NotificationType
    title: str
    body: str
    data: dict[str, Any] = Field(default_factory=dict)
    is_read: bool
    created_at: datetime
    read_at: Optional[datetime] = None

    model_config = ConfigDict(from_attributes=True)


class NotificationListResponse(BaseModel):
    """通知一覧のレスポンス"""

    notifications: list[NotificationResponse]
    total: int
    unread_count: int = Field(default=0, description="未読通知数")


class NotificationMarkReadRequest(BaseModel):
    """通知既読リクエスト"""

    notification_ids: list[str] = Field(..., min_length=1, description="既読にする通知IDのリスト")


class FCMTokenRegisterRequest(BaseModel):
    """FCMトークン登録リクエスト"""

    fcm_token: str = Field(..., min_length=1, description="FCMトークン")


class FCMTokenRemoveRequest(BaseModel):
    """FCMトークン削除リクエスト"""

    fcm_token: str = Field(..., min_length=1, description="削除するFCMトークン")


class PushNotificationRequest(BaseModel):
    """プッシュ通知送信リクエスト（開発・テスト用）"""

    user_id: str = Field(..., description="送信先ユーザID")
    title: str = Field(..., max_length=100, description="通知タイトル")
    body: str = Field(..., max_length=500, description="通知本文")
    data: dict[str, Any] = Field(default_factory=dict, description="追加データ")


class NotificationHistoryInDB(BaseModel):
    """通知履歴（imane用 - 24時間TTL）"""

    id: str = Field(..., description="通知履歴ID")
    from_user_id: str = Field(..., description="送信元ユーザID")
    to_user_id: str = Field(..., description="送信先ユーザID")
    schedule_id: str = Field(..., description="関連するスケジュールID")
    type: str = Field(..., description="通知タイプ (arrival/stay/departure)")
    message: str = Field(..., description="通知メッセージ")
    map_link: str = Field(..., description="地図リンク")
    sent_at: datetime = Field(default_factory=datetime.utcnow, description="送信日時")
    auto_delete_at: datetime = Field(..., description="自動削除日時（24時間後）")

    model_config = ConfigDict(from_attributes=True)
