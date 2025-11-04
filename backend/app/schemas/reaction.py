"""
リアクション関連のPydanticスキーマ定義

Firestoreのreactionsコレクション構造:
{
    "reaction_id": "auto_generated",
    "pop_id": "pop_abc123",
    "from_user_id": "user_xyz789",
    "to_user_id": "user_abc123",
    "created_at": "2024-01-01T00:00:00Z",
    "status": "pending"
}
"""

from datetime import datetime
from enum import Enum
from typing import Optional

from pydantic import BaseModel, ConfigDict, Field


class ReactionStatus(str, Enum):
    """リアクションのステータス"""

    PENDING = "pending"  # 承認待ち
    ACCEPTED = "accepted"  # 承認済み（マッチング成立）
    REJECTED = "rejected"  # 拒否
    CANCELLED = "cancelled"  # 送信者がキャンセル


class ReactionBase(BaseModel):
    """リアクションの基本情報"""

    pop_id: str = Field(..., description="ポップID")


class ReactionCreate(ReactionBase):
    """リアクション作成時のリクエスト"""

    message: Optional[str] = Field(None, max_length=200, description="添付メッセージ（任意）")


class ReactionInDB(ReactionBase):
    """データベース内のリアクション情報"""

    reaction_id: str = Field(..., description="リアクションID")
    from_user_id: str = Field(..., description="送信者のUID")
    to_user_id: str = Field(..., description="受信者のUID（ポップの投稿者）")
    message: Optional[str] = Field(None, description="添付メッセージ")
    created_at: datetime = Field(default_factory=datetime.utcnow)
    status: ReactionStatus = Field(default=ReactionStatus.PENDING)

    model_config = ConfigDict(from_attributes=True)


class ReactionResponse(ReactionBase):
    """リアクション情報のレスポンス"""

    reaction_id: str
    from_user_id: str
    to_user_id: str
    message: Optional[str] = None
    created_at: datetime
    status: ReactionStatus

    # ユーザー情報（追加情報）
    from_user_display_name: Optional[str] = Field(None, description="送信者の表示名")
    from_user_profile_image_url: Optional[str] = Field(None, description="送信者のプロフィール画像")
    to_user_display_name: Optional[str] = Field(None, description="受信者の表示名")
    to_user_profile_image_url: Optional[str] = Field(None, description="受信者のプロフィール画像")

    # ポップ情報（追加情報）
    pop_content: Optional[str] = Field(None, description="ポップの内容")
    pop_category: Optional[str] = Field(None, description="ポップのカテゴリ")

    model_config = ConfigDict(from_attributes=True)


class ReactionListResponse(BaseModel):
    """リアクション一覧のレスポンス"""

    reactions: list[ReactionResponse]
    total: int
    unread_count: int = Field(default=0, description="未読（pending）の件数")


class ReactionUpdateStatus(BaseModel):
    """リアクションステータス更新"""

    status: ReactionStatus
