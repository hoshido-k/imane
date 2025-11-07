"""
ユーザー管理サービス
"""

from datetime import UTC, datetime
from typing import List, Optional

from google.cloud.firestore_v1 import FieldFilter

from app.core.firebase import get_firestore_client
from app.schemas.user import UserInDB, UserUpdate


class UserService:
    """ユーザー管理サービスクラス"""

    def __init__(self):
        self.db = get_firestore_client()

    async def check_username_availability(self, username: str) -> bool:
        """
        ユーザーIDの利用可否をチェック

        Args:
            username: チェックするユーザーID

        Returns:
            True: 利用可能、False: 既に使用されている
        """
        from google.cloud.firestore_v1 import FieldFilter

        existing_users = self.db.collection("users").where(
            filter=FieldFilter("username", "==", username)
        ).limit(1).get()

        # ユーザーが存在しない場合は利用可能
        return len(existing_users) == 0

    async def search_users(
        self, query: str, current_user_id: str, limit: int = 20
    ) -> List[UserInDB]:
        """
        ユーザーをusernameで検索

        Args:
            query: 検索クエリ（username）
            current_user_id: 現在のユーザーID（自分自身は除外）
            limit: 取得件数の上限

        Returns:
            検索結果のユーザーリスト
        """
        if not query or len(query.strip()) == 0:
            return []

        query = query.strip().lower()
        results = []

        # usernameで検索（部分一致）
        # Firestoreは部分一致検索をサポートしていないため、全件取得してフィルタリング
        # 本番環境ではAlgoliaやElasticsearchの使用を推奨
        users_ref = self.db.collection("users").limit(100)
        users = users_ref.get()

        for user_doc in users:
            user_data = user_doc.to_dict()
            user = UserInDB(**user_data)

            # 自分自身は除外
            if user.uid == current_user_id:
                continue

            # usernameに検索クエリが含まれるか
            username_match = query in user.username.lower() if user.username else False

            if username_match:
                results.append(user)

            if len(results) >= limit:
                break

        return results

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
            ValueError: ユーザーが見つからない場合、またはusernameが重複している場合
        """
        user_ref = self.db.collection("users").document(uid)
        user_doc = user_ref.get()

        if not user_doc.exists:
            raise ValueError("ユーザーが見つかりません")

        # username変更の場合は重複チェック
        if update_data.username is not None:
            from google.cloud.firestore_v1 import FieldFilter
            existing_users = self.db.collection("users").where(
                filter=FieldFilter("username", "==", update_data.username)
            ).limit(1).get()

            # 自分以外のユーザーが同じusernameを持っている場合はエラー
            for existing_user in existing_users:
                if existing_user.id != uid:
                    raise ValueError("このユーザーIDは既に使用されています")

        # 更新データの準備（Noneでない値のみ）
        update_dict = update_data.model_dump(exclude_unset=True, exclude_none=True)
        update_dict["updated_at"] = datetime.now(UTC)

        # Firestoreを更新
        user_ref.update(update_dict)

        # 更新後のユーザー情報を取得
        return await self.get_user_by_uid(uid)
