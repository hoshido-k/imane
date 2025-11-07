"""
リアクションサービス - Firestore連携
"""

import uuid
from datetime import UTC, datetime
from typing import List, Optional

from firebase_admin import firestore

from app.core.firebase import get_firestore_client
from app.schemas.reaction import (
    ReactionCreate,
    ReactionInDB,
    ReactionResponse,
    ReactionStatus,
)


class ReactionService:
    """リアクションサービスクラス"""

    def __init__(self):
        self.db = get_firestore_client()
        self.collection = "reactions"
        self.pops_collection = "pops"
        self.users_collection = "users"

    async def create_reaction(
        self, from_user_id: str, reaction_data: ReactionCreate
    ) -> ReactionResponse:
        """
        リアクションを送信

        Args:
            from_user_id: 送信者のUID
            reaction_data: リアクションデータ

        Returns:
            作成されたリアクション

        Raises:
            ValueError: ポップが見つからない、自分のポップへのリアクション、重複リアクション
        """
        # ポップの存在確認と投稿者取得
        pop_ref = self.db.collection(self.pops_collection).document(reaction_data.pop_id)
        pop_doc = pop_ref.get()

        if not pop_doc.exists:
            raise ValueError("ポップが見つかりません")

        pop_data = pop_doc.to_dict()
        to_user_id = pop_data.get("user_id")

        # 自分のポップへのリアクションは禁止
        if from_user_id == to_user_id:
            raise ValueError("自分のポップにリアクションできません")

        # 既にリアクション済みかチェック
        existing_reactions = (
            self.db.collection(self.collection)
            .where("pop_id", "==", reaction_data.pop_id)
            .where("from_user_id", "==", from_user_id)
            .where("status", "in", [ReactionStatus.PENDING.value, ReactionStatus.ACCEPTED.value])
            .limit(1)
            .stream()
        )

        if any(existing_reactions):
            raise ValueError("既にこのポップにリアクションしています")

        # リアクションIDを生成
        reaction_id = str(uuid.uuid4())

        # データベースに保存
        reaction_dict = {
            "reaction_id": reaction_id,
            "pop_id": reaction_data.pop_id,
            "from_user_id": from_user_id,
            "to_user_id": to_user_id,
            "message": reaction_data.message,
            "created_at": datetime.now(UTC),
            "status": ReactionStatus.PENDING.value,
        }

        self.db.collection(self.collection).document(reaction_id).set(reaction_dict)

        # ポップのリアクション数をインクリメント
        pop_ref.update({"reaction_count": firestore.Increment(1)})

        # レスポンスを作成
        reaction_in_db = ReactionInDB(**reaction_dict)
        return await self._to_response(reaction_in_db)

    async def get_reaction_by_id(self, reaction_id: str) -> Optional[ReactionResponse]:
        """
        リアクションIDでリアクションを取得

        Args:
            reaction_id: リアクションID

        Returns:
            リアクション情報（見つからない場合はNone）
        """
        doc = self.db.collection(self.collection).document(reaction_id).get()

        if not doc.exists:
            return None

        reaction_data = doc.to_dict()
        reaction_in_db = ReactionInDB(**reaction_data)
        return await self._to_response(reaction_in_db)

    async def get_received_reactions(
        self, user_id: str, status_filter: Optional[ReactionStatus] = None
    ) -> List[ReactionResponse]:
        """
        受信したリアクション一覧を取得

        Args:
            user_id: ユーザID
            status_filter: ステータスフィルター（None=全て）

        Returns:
            リアクション一覧
        """
        query = self.db.collection(self.collection).where("to_user_id", "==", user_id)

        if status_filter:
            query = query.where("status", "==", status_filter.value)

        query = query.order_by("created_at", direction=firestore.Query.DESCENDING)

        docs = query.stream()

        reactions = []
        for doc in docs:
            reaction_data = doc.to_dict()
            reaction_in_db = ReactionInDB(**reaction_data)
            reactions.append(await self._to_response(reaction_in_db))

        return reactions

    async def get_sent_reactions(
        self, user_id: str, status_filter: Optional[ReactionStatus] = None
    ) -> List[ReactionResponse]:
        """
        送信したリアクション一覧を取得

        Args:
            user_id: ユーザID
            status_filter: ステータスフィルター（None=全て）

        Returns:
            リアクション一覧
        """
        query = self.db.collection(self.collection).where("from_user_id", "==", user_id)

        if status_filter:
            query = query.where("status", "==", status_filter.value)

        query = query.order_by("created_at", direction=firestore.Query.DESCENDING)

        docs = query.stream()

        reactions = []
        for doc in docs:
            reaction_data = doc.to_dict()
            reaction_in_db = ReactionInDB(**reaction_data)
            reactions.append(await self._to_response(reaction_in_db))

        return reactions

    async def get_pop_reactions(self, pop_id: str) -> List[ReactionResponse]:
        """
        特定のポップへのリアクション一覧を取得

        Args:
            pop_id: ポップID

        Returns:
            リアクション一覧
        """
        query = (
            self.db.collection(self.collection)
            .where("pop_id", "==", pop_id)
            .order_by("created_at", direction=firestore.Query.DESCENDING)
        )

        docs = query.stream()

        reactions = []
        for doc in docs:
            reaction_data = doc.to_dict()
            reaction_in_db = ReactionInDB(**reaction_data)
            reactions.append(await self._to_response(reaction_in_db))

        return reactions

    async def accept_reaction(self, reaction_id: str, user_id: str) -> bool:
        """
        リアクションを承認（マッチング成立）

        Args:
            reaction_id: リアクションID
            user_id: ユーザID（受信者確認用）

        Returns:
            承認成功時True

        Raises:
            ValueError: リアクションが見つからない、権限がない場合
        """
        reaction_ref = self.db.collection(self.collection).document(reaction_id)
        reaction_doc = reaction_ref.get()

        if not reaction_doc.exists:
            raise ValueError("リアクションが見つかりません")

        reaction_data = reaction_doc.to_dict()

        # 受信者かチェック
        if reaction_data["to_user_id"] != user_id:
            raise ValueError("このリアクションを承認する権限がありません")

        # ステータス確認
        if reaction_data["status"] != ReactionStatus.PENDING.value:
            raise ValueError("このリアクションは既に処理されています")

        # ステータスを承認に更新
        reaction_ref.update({"status": ReactionStatus.ACCEPTED.value})

        return True

    async def reject_reaction(self, reaction_id: str, user_id: str) -> bool:
        """
        リアクションを拒否

        Args:
            reaction_id: リアクションID
            user_id: ユーザID（受信者確認用）

        Returns:
            拒否成功時True

        Raises:
            ValueError: リアクションが見つからない、権限がない場合
        """
        reaction_ref = self.db.collection(self.collection).document(reaction_id)
        reaction_doc = reaction_ref.get()

        if not reaction_doc.exists:
            raise ValueError("リアクションが見つかりません")

        reaction_data = reaction_doc.to_dict()

        # 受信者かチェック
        if reaction_data["to_user_id"] != user_id:
            raise ValueError("このリアクションを拒否する権限がありません")

        # ステータス確認
        if reaction_data["status"] != ReactionStatus.PENDING.value:
            raise ValueError("このリアクションは既に処理されています")

        # ステータスを拒否に更新
        reaction_ref.update({"status": ReactionStatus.REJECTED.value})

        # ポップのリアクション数をデクリメント
        pop_ref = self.db.collection(self.pops_collection).document(reaction_data["pop_id"])
        pop_ref.update({"reaction_count": firestore.Increment(-1)})

        return True

    async def cancel_reaction(self, reaction_id: str, user_id: str) -> bool:
        """
        リアクションをキャンセル（送信者がキャンセル）

        Args:
            reaction_id: リアクションID
            user_id: ユーザID（送信者確認用）

        Returns:
            キャンセル成功時True

        Raises:
            ValueError: リアクションが見つからない、権限がない場合
        """
        reaction_ref = self.db.collection(self.collection).document(reaction_id)
        reaction_doc = reaction_ref.get()

        if not reaction_doc.exists:
            raise ValueError("リアクションが見つかりません")

        reaction_data = reaction_doc.to_dict()

        # 送信者かチェック
        if reaction_data["from_user_id"] != user_id:
            raise ValueError("このリアクションをキャンセルする権限がありません")

        # ステータス確認
        if reaction_data["status"] != ReactionStatus.PENDING.value:
            raise ValueError("このリアクションは既に処理されています")

        # ステータスをキャンセルに更新
        reaction_ref.update({"status": ReactionStatus.CANCELLED.value})

        # ポップのリアクション数をデクリメント
        pop_ref = self.db.collection(self.pops_collection).document(reaction_data["pop_id"])
        pop_ref.update({"reaction_count": firestore.Increment(-1)})

        return True

    async def get_unread_count(self, user_id: str) -> int:
        """
        未読リアクション数を取得

        Args:
            user_id: ユーザID

        Returns:
            未読（pending）リアクション数
        """
        query = (
            self.db.collection(self.collection)
            .where("to_user_id", "==", user_id)
            .where("status", "==", ReactionStatus.PENDING.value)
        )

        docs = list(query.stream())
        return len(docs)

    async def _to_response(self, reaction_in_db: ReactionInDB) -> ReactionResponse:
        """
        ReactionInDBをReactionResponseに変換（ユーザー情報とポップ情報を付加）

        Args:
            reaction_in_db: データベース内のリアクション

        Returns:
            レスポンス用リアクション
        """
        # 送信者情報を取得
        from_user_doc = (
            self.db.collection(self.users_collection).document(reaction_in_db.from_user_id).get()
        )
        from_user_data = from_user_doc.to_dict() if from_user_doc.exists else {}

        # 受信者情報を取得
        to_user_doc = (
            self.db.collection(self.users_collection).document(reaction_in_db.to_user_id).get()
        )
        to_user_data = to_user_doc.to_dict() if to_user_doc.exists else {}

        # ポップ情報を取得
        pop_doc = self.db.collection(self.pops_collection).document(reaction_in_db.pop_id).get()
        pop_data = pop_doc.to_dict() if pop_doc.exists else {}

        return ReactionResponse(
            reaction_id=reaction_in_db.reaction_id,
            pop_id=reaction_in_db.pop_id,
            from_user_id=reaction_in_db.from_user_id,
            to_user_id=reaction_in_db.to_user_id,
            message=reaction_in_db.message,
            created_at=reaction_in_db.created_at,
            status=reaction_in_db.status,
            from_user_display_name=from_user_data.get("display_name"),
            from_user_profile_image_url=from_user_data.get("profile_image_url"),
            to_user_display_name=to_user_data.get("display_name"),
            to_user_profile_image_url=to_user_data.get("profile_image_url"),
            pop_content=pop_data.get("content"),
            pop_category=pop_data.get("category"),
        )
