"""
位置情報トラッキング関連のPydanticスキーマ定義

Firestoreのlocation_history コレクション構造:
{
    "id": "auto-generated",
    "user_id": "firebase_auth_uid",
    "schedule_id": "schedule_id",
    "coords": {
        "lat": 35.6580,
        "lng": 139.7016
    },
    "recorded_at": "2025-01-15T14:05:00Z",
    "auto_delete_at": "2025-01-16T14:05:00Z"  # 24時間後
}
"""

from datetime import datetime, timedelta
from typing import List, Optional

from pydantic import BaseModel, ConfigDict, Field, field_serializer

from app.schemas.common import Coordinates
from app.utils.timezone import now_jst, jst_now_plus, to_jst


class LocationUpdateRequest(BaseModel):
    """位置情報更新リクエスト"""

    coords: Coordinates = Field(..., description="現在地の座標")
    accuracy: Optional[float] = Field(None, ge=0, description="位置情報の精度（メートル）")
    recorded_at: Optional[datetime] = Field(None, description="記録日時（省略時は現在時刻）")


class LocationHistoryInDB(BaseModel):
    """データベース内の位置情報履歴"""

    id: str = Field(..., description="位置情報履歴ID")
    user_id: str = Field(..., description="ユーザID")
    schedule_id: Optional[str] = Field(None, description="関連するスケジュールID")
    coords: Coordinates = Field(..., description="座標")
    accuracy: Optional[float] = Field(None, description="位置情報の精度（メートル）")
    recorded_at: datetime = Field(default_factory=now_jst)
    auto_delete_at: datetime = Field(
        default_factory=lambda: jst_now_plus(hours=24),
        description="自動削除日時（24時間後）",
    )

    model_config = ConfigDict(from_attributes=True)


class LocationHistoryResponse(BaseModel):
    """位置情報履歴のレスポンス"""

    id: str
    user_id: str
    schedule_id: Optional[str] = None
    coords: Coordinates
    accuracy: Optional[float] = None
    recorded_at: datetime
    auto_delete_at: datetime

    model_config = ConfigDict(from_attributes=True)

    @field_serializer('recorded_at', 'auto_delete_at')
    def serialize_datetime(self, dt: Optional[datetime], _info) -> Optional[str]:
        """datetimeをJSTタイムゾーン付きのISO 8601形式でシリアライズ"""
        if dt is None:
            return None
        jst_dt = to_jst(dt)
        return jst_dt.isoformat()


class ScheduleStatusInfo(BaseModel):
    """スケジュールのステータス情報"""

    schedule_id: str = Field(..., description="スケジュールID")
    destination_name: str = Field(..., description="目的地名")
    destination_coords: Coordinates = Field(..., description="目的地の座標")
    status: str = Field(..., description="ステータス（active/arrived/completed）")
    distance_to_destination: Optional[float] = Field(None, description="目的地までの距離（メートル）")
    arrived_at: Optional[datetime] = Field(None, description="到着日時")
    departed_at: Optional[datetime] = Field(None, description="退出日時")

    @field_serializer('arrived_at', 'departed_at')
    def serialize_datetime(self, dt: Optional[datetime], _info) -> Optional[str]:
        """datetimeをJSTタイムゾーン付きのISO 8601形式でシリアライズ"""
        if dt is None:
            return None
        jst_dt = to_jst(dt)
        return jst_dt.isoformat()


class LocationStatusResponse(BaseModel):
    """位置情報ステータスのレスポンス"""

    current_location: Optional[Coordinates] = Field(None, description="現在地")
    last_updated: Optional[datetime] = Field(None, description="最終更新日時")
    active_schedules: List[ScheduleStatusInfo] = Field(
        default_factory=list, description="アクティブなスケジュール一覧"
    )

    @field_serializer('last_updated')
    def serialize_datetime(self, dt: Optional[datetime], _info) -> Optional[str]:
        """datetimeをJSTタイムゾーン付きのISO 8601形式でシリアライズ"""
        if dt is None:
            return None
        jst_dt = to_jst(dt)
        return jst_dt.isoformat()


class LocationUpdateResponse(BaseModel):
    """位置情報更新レスポンス"""

    message: str = Field(..., description="処理結果メッセージ")
    location_recorded: bool = Field(..., description="位置情報が記録されたか")
    triggered_notifications: List[dict] = Field(
        default_factory=list, description="トリガーされた通知の情報"
    )
    schedule_updates: List[dict] = Field(
        default_factory=list, description="更新されたスケジュールの情報"
    )
