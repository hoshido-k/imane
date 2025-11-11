"""
位置情報スケジュール関連のPydanticスキーマ定義

Firestoreのschedules コレクション構造:
{
    "id": "auto-generated",
    "user_id": "firebase_auth_uid",
    "destination_name": "渋谷駅",
    "destination_address": "東京都渋谷区道玄坂1-1-1",
    "destination_coords": {
        "lat": 35.6580,
        "lng": 139.7016
    },
    "geofence_radius": 50,  # デフォルト50メートル
    "notify_to_user_ids": ["uid1", "uid2"],  # 通知先フレンド
    "start_time": "2025-01-15T14:00:00Z",
    "end_time": "2025-01-15T18:00:00Z",
    "recurrence": null,  # "daily", "weekdays", "weekends"
    "notify_on_arrival": true,
    "notify_after_minutes": 60,  # 滞在通知までの分数
    "notify_on_departure": true,
    "status": "active",  # "active", "arrived", "completed", "expired"
    "arrived_at": null,
    "departed_at": null,
    "favorite": false,
    "created_at": "2025-01-15T10:00:00Z",
    "updated_at": "2025-01-15T10:00:00Z"
}
"""

from datetime import datetime
from enum import Enum
from typing import List, Optional, Any

from pydantic import BaseModel, ConfigDict, Field, field_serializer

from app.schemas.common import Coordinates
from app.utils.timezone import now_jst, to_jst


class NotifyToUser(BaseModel):
    """通知先ユーザー情報"""

    user_id: str = Field(..., description="ユーザID")
    display_name: str = Field(..., description="表示名")
    profile_image_url: Optional[str] = Field(None, description="プロフィール画像URL")


class ScheduleStatus(str, Enum):
    """スケジュールステータス"""

    ACTIVE = "active"  # アクティブ（開始時刻前、または目的地到着前）
    ARRIVED = "arrived"  # 目的地到着済み
    COMPLETED = "completed"  # 完了（退出済み）
    EXPIRED = "expired"  # 期限切れ（終了時刻を過ぎた）


class RecurrenceType(str, Enum):
    """繰り返しタイプ"""

    DAILY = "daily"  # 毎日
    WEEKDAYS = "weekdays"  # 平日のみ
    WEEKENDS = "weekends"  # 週末のみ


class LocationScheduleBase(BaseModel):
    """位置情報スケジュールの基本情報"""

    destination_name: str = Field(..., min_length=1, max_length=100, description="目的地名")
    destination_address: str = Field(..., min_length=1, max_length=200, description="目的地住所")
    destination_coords: Coordinates = Field(..., description="目的地の座標")
    geofence_radius: int = Field(default=50, ge=10, le=500, description="ジオフェンス半径（メートル）")
    notify_to_user_ids: List[str] = Field(..., min_length=1, description="通知先ユーザIDリスト")
    start_time: datetime = Field(..., description="開始時刻")
    end_time: datetime = Field(..., description="終了時刻")
    recurrence: Optional[RecurrenceType] = Field(None, description="繰り返し設定")
    notify_on_arrival: bool = Field(default=True, description="到着時通知の有無")
    notify_after_minutes: int = Field(default=60, ge=1, le=1440, description="滞在通知までの分数")
    notify_on_departure: bool = Field(default=True, description="退出時通知の有無")


class LocationScheduleCreate(LocationScheduleBase):
    """スケジュール作成リクエスト"""

    favorite: bool = Field(default=False, description="お気に入り登録")


class LocationScheduleUpdate(BaseModel):
    """スケジュール更新リクエスト"""

    destination_name: Optional[str] = Field(None, min_length=1, max_length=100)
    destination_address: Optional[str] = Field(None, min_length=1, max_length=200)
    destination_coords: Optional[Coordinates] = None
    geofence_radius: Optional[int] = Field(None, ge=10, le=500)
    notify_to_user_ids: Optional[List[str]] = Field(None, min_length=1)
    start_time: Optional[datetime] = None
    end_time: Optional[datetime] = None
    recurrence: Optional[RecurrenceType] = None
    notify_on_arrival: Optional[bool] = None
    notify_after_minutes: Optional[int] = Field(None, ge=1, le=1440)
    notify_on_departure: Optional[bool] = None


class LocationScheduleInDB(LocationScheduleBase):
    """データベース内のスケジュール"""

    id: str = Field(..., description="スケジュールID")
    user_id: str = Field(..., description="作成者のユーザID")
    status: ScheduleStatus = Field(default=ScheduleStatus.ACTIVE, description="スケジュールステータス")
    arrived_at: Optional[datetime] = Field(None, description="到着日時")
    departed_at: Optional[datetime] = Field(None, description="退出日時")
    favorite: bool = Field(default=False, description="お気に入り")
    created_at: datetime = Field(default_factory=now_jst)
    updated_at: datetime = Field(default_factory=now_jst)

    model_config = ConfigDict(from_attributes=True)


class CreatorUser(BaseModel):
    """作成者ユーザー情報"""

    user_id: str = Field(..., description="ユーザID")
    display_name: str = Field(..., description="表示名")
    profile_image_url: Optional[str] = Field(None, description="プロフィール画像URL")


class LocationScheduleResponse(BaseModel):
    """スケジュールのレスポンス"""

    id: str
    user_id: str
    creator: Optional[CreatorUser] = Field(None, description="作成者情報")
    destination_name: str
    destination_address: str
    destination_coords: Coordinates
    geofence_radius: int
    notify_to_user_ids: List[str]
    notify_to_users: List[NotifyToUser] = Field(default_factory=list, description="通知先ユーザー情報")
    start_time: datetime
    end_time: datetime
    recurrence: Optional[RecurrenceType] = None
    notify_on_arrival: bool
    notify_after_minutes: int
    notify_on_departure: bool
    status: ScheduleStatus
    arrived_at: Optional[datetime] = None
    departed_at: Optional[datetime] = None
    favorite: bool
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)

    @field_serializer('start_time', 'end_time', 'arrived_at', 'departed_at', 'created_at', 'updated_at')
    def serialize_datetime(self, dt: Optional[datetime], _info) -> Optional[str]:
        """datetimeをJSTタイムゾーン付きのISO 8601形式でシリアライズ"""
        if dt is None:
            return None
        # JSTタイムゾーンに変換してISO形式で出力
        jst_dt = to_jst(dt)
        return jst_dt.isoformat()


class LocationScheduleListResponse(BaseModel):
    """スケジュール一覧のレスポンス"""

    schedules: List[LocationScheduleResponse]
    total: int = Field(..., description="総件数")
