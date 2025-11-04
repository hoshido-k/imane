"""
ユーザー管理サービス
"""

from datetime import UTC, datetime
from typing import Optional

from app.core.firebase import get_firestore_client
from app.schemas.user import UserInDB, UserUpdate


class UserService:
    """ユーザー管理サービスクラス"""

    def __init__(self):
        self.db = get_firestore_client()

    async def get_user_by_uid(self, uid: str) -> Optional[UserInDB]:
        """
        UIDからユーザー情報を取得

        Args:
            uid: ユーザーID

        Returns:
            ユーザー情報、存在しない場合はNone
        """
        user_ref = self.db.collection("users").document(uid)
        user_doc = user_ref.get()

        if not user_doc.exists:
            return None

        user_data = user_doc.to_dict()
        return UserInDB(**user_data)

    async def update_profile(self, uid: str, update_data: UserUpdate) -> UserInDB:
        """
        プロフィール情報を更新

        Args:
            uid: ユーザーID
            update_data: 更新データ

        Returns:
            更新後のユーザー情報

        Raises:
            ValueError: ユーザーが見つからない場合
        """
        user_ref = self.db.collection("users").document(uid)
        user_doc = user_ref.get()

        if not user_doc.exists:
            raise ValueError("ユーザーが見つかりません")

        # 更新データの準備（Noneでない値のみ）
        update_dict = update_data.model_dump(exclude_unset=True, exclude_none=True)
        update_dict["updated_at"] = datetime.now(UTC)

        # Firestoreを更新
        user_ref.update(update_dict)

        # 更新後のユーザー情報を取得
        return await self.get_user_by_uid(uid)
