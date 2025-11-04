"""
お気に入り場所管理サービス
"""

import uuid
from datetime import UTC, datetime
from typing import List, Optional

from app.core.firebase import get_firestore_client
from app.schemas.favorite import (
    FavoriteLocationCreate,
    FavoriteLocationInDB,
)


class FavoriteService:
    """お気に入り場所管理サービスクラス"""

    def __init__(self):
        self.db = get_firestore_client()
        self.collection_name = "favorites"

    async def create_favorite(
        self, user_id: str, favorite_data: FavoriteLocationCreate
    ) -> FavoriteLocationInDB:
        """
        お気に入り場所を作成

        Args:
            user_id: ユーザーID
            favorite_data: お気に入り場所作成データ

        Returns:
            作成されたお気に入り場所情報
        """
        # 新しいお気に入りIDを生成
        favorite_id = str(uuid.uuid4())
        now = datetime.now(UTC)

        # お気に入りデータを作成
        favorite_dict = favorite_data.model_dump()
        favorite_dict.update(
            {
                "id": favorite_id,
                "user_id": user_id,
                "created_at": now,
            }
        )

        # Firestoreに保存
        favorite_ref = self.db.collection(self.collection_name).document(favorite_id)
        favorite_ref.set(favorite_dict)

        return FavoriteLocationInDB(**favorite_dict)

    async def get_favorite_by_id(
        self, favorite_id: str, user_id: str
    ) -> Optional[FavoriteLocationInDB]:
        """
        お気に入りIDからお気に入り場所を取得

        Args:
            favorite_id: お気に入りID
            user_id: ユーザーID（権限チェック用）

        Returns:
            お気に入り場所情報、存在しない場合はNone

        Raises:
            ValueError: 権限がない場合
        """
        favorite_ref = self.db.collection(self.collection_name).document(favorite_id)
        favorite_doc = favorite_ref.get()

        if not favorite_doc.exists:
            return None

        favorite_data = favorite_doc.to_dict()

        # 権限チェック: 作成者本人のみアクセス可能
        if favorite_data.get("user_id") != user_id:
            raise ValueError("このお気に入り場所にアクセスする権限がありません")

        return FavoriteLocationInDB(**favorite_data)

    async def get_favorites_by_user(self, user_id: str) -> List[FavoriteLocationInDB]:
        """
        ユーザーのお気に入り場所一覧を取得

        Args:
            user_id: ユーザーID

        Returns:
            お気に入り場所一覧
        """
        query = self.db.collection(self.collection_name).where("user_id", "==", user_id)

        # 作成日時で降順にソート
        query = query.order_by("created_at", direction="DESCENDING")

        favorites_docs = query.stream()

        favorites = []
        for doc in favorites_docs:
            favorite_data = doc.to_dict()
            favorites.append(FavoriteLocationInDB(**favorite_data))

        return favorites

    async def delete_favorite(self, favorite_id: str, user_id: str) -> None:
        """
        お気に入り場所を削除

        Args:
            favorite_id: お気に入りID
            user_id: ユーザーID（権限チェック用）

        Raises:
            ValueError: お気に入りが見つからない、または権限がない場合
        """
        favorite_ref = self.db.collection(self.collection_name).document(favorite_id)
        favorite_doc = favorite_ref.get()

        if not favorite_doc.exists:
            raise ValueError("お気に入り場所が見つかりません")

        favorite_data = favorite_doc.to_dict()

        # 権限チェック
        if favorite_data.get("user_id") != user_id:
            raise ValueError("このお気に入り場所を削除する権限がありません")

        # Firestoreから削除
        favorite_ref.delete()
