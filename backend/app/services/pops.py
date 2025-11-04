"""
ポップサービス - Firestore連携
"""

import uuid
from datetime import UTC, datetime, timedelta
from typing import List, Optional

import pygeohash as gh
from firebase_admin import firestore

from app.core.firebase import get_firestore_client
from app.schemas.pop import (
    PopCategory,
    PopCreate,
    PopInDB,
    PopResponse,
    PopSearchRequest,
    PopStatus,
    PopUpdate,
)


class PopService:
    """ポップサービスクラス"""

    def __init__(self):
        self.db = get_firestore_client()
        self.collection = "pops"

    async def create_pop(self, user_id: str, pop_data: PopCreate) -> PopResponse:
        """
        ポップを作成

        Args:
            user_id: 投稿者のUID
            pop_data: ポップデータ

        Returns:
            作成されたポップ

        Raises:
            ValueError: バリデーションエラー
        """
        # 有効期間のバリデーション
        if not pop_data.validate_duration():
            raise ValueError("有効期間は15, 30, 45, 60分のいずれかを指定してください")

        # Geohashを生成（精度7 = 約153m四方）
        geohash = gh.encode(
            pop_data.location.latitude, pop_data.location.longitude, precision=7
        )

        # 有効期限を計算
        now = datetime.now(UTC)
        expires_at = now + timedelta(minutes=pop_data.duration_minutes)

        # ポップIDを生成
        pop_id = str(uuid.uuid4())

        # データベースに保存するデータ
        pop_dict = {
            "pop_id": pop_id,
            "user_id": user_id,
            "content": pop_data.content,
            "category": pop_data.category.value,
            "location": {
                "latitude": pop_data.location.latitude,
                "longitude": pop_data.location.longitude,
                "geohash": geohash,
            },
            "created_at": now,
            "expires_at": expires_at,
            "duration_minutes": pop_data.duration_minutes,
            "reaction_count": 0,
            "is_premium": pop_data.is_premium,
            "status": PopStatus.ACTIVE.value,
            "visibility": pop_data.visibility.value,
        }

        # Firestoreに保存
        self.db.collection(self.collection).document(pop_id).set(pop_dict)

        # レスポンスを作成
        pop_in_db = PopInDB(**pop_dict)
        return self._to_response(pop_in_db)

    async def get_pop_by_id(self, pop_id: str) -> Optional[PopResponse]:
        """
        ポップIDでポップを取得

        Args:
            pop_id: ポップID

        Returns:
            ポップ情報（見つからない場合はNone）
        """
        doc = self.db.collection(self.collection).document(pop_id).get()

        if not doc.exists:
            return None

        pop_data = doc.to_dict()
        pop_in_db = PopInDB(**pop_data)
        return self._to_response(pop_in_db)

    async def search_nearby_pops(self, search_request: PopSearchRequest) -> List[PopResponse]:
        """
        周辺のポップを検索

        Args:
            search_request: 検索条件

        Returns:
            ポップのリスト
        """
        # Geohashの範囲を計算（簡易実装）
        center_geohash = gh.encode(
            search_request.latitude, search_request.longitude, precision=5
        )

        # クエリを構築
        query = self.db.collection(self.collection)

        # 有効なポップのみ取得する場合
        if search_request.only_active:
            query = query.where("status", "==", PopStatus.ACTIVE.value)
            query = query.where("expires_at", ">", datetime.now(UTC))

        # カテゴリフィルター
        if search_request.categories:
            category_values = [cat.value for cat in search_request.categories]
            query = query.where("category", "in", category_values)

        # 件数制限
        query = query.limit(search_request.limit)

        # クエリ実行
        docs = query.stream()

        pops = []
        for doc in docs:
            pop_data = doc.to_dict()
            pop_in_db = PopInDB(**pop_data)

            # 距離フィルタリング（簡易実装 - より正確にはHaversine式を使用）
            distance = self._calculate_distance(
                search_request.latitude,
                search_request.longitude,
                pop_in_db.location.latitude,
                pop_in_db.location.longitude,
            )

            if distance <= search_request.radius_km:
                pops.append(self._to_response(pop_in_db))

        return pops

    async def get_user_pops(self, user_id: str, include_expired: bool = False) -> List[PopResponse]:
        """
        ユーザーが投稿したポップ一覧を取得

        Args:
            user_id: ユーザーID
            include_expired: 期限切れポップも含めるか

        Returns:
            ポップのリスト
        """
        query = self.db.collection(self.collection).where("user_id", "==", user_id)

        if not include_expired:
            query = query.where("status", "==", PopStatus.ACTIVE.value)
            query = query.where("expires_at", ">", datetime.now(UTC))

        query = query.order_by("created_at", direction=firestore.Query.DESCENDING)

        docs = query.stream()

        pops = []
        for doc in docs:
            pop_data = doc.to_dict()
            pop_in_db = PopInDB(**pop_data)
            pops.append(self._to_response(pop_in_db))

        return pops

    async def update_pop(self, pop_id: str, user_id: str, update_data: PopUpdate) -> bool:
        """
        ポップを更新

        Args:
            pop_id: ポップID
            user_id: ユーザーID（投稿者確認用）
            update_data: 更新データ

        Returns:
            更新成功時True

        Raises:
            ValueError: ポップが見つからない、権限がない場合
        """
        pop_ref = self.db.collection(self.collection).document(pop_id)
        pop_doc = pop_ref.get()

        if not pop_doc.exists:
            raise ValueError("ポップが見つかりません")

        pop_data = pop_doc.to_dict()
        if pop_data["user_id"] != user_id:
            raise ValueError("このポップを更新する権限がありません")

        # 更新するフィールドを準備
        update_fields = {}
        if update_data.content is not None:
            update_fields["content"] = update_data.content
        if update_data.category is not None:
            update_fields["category"] = update_data.category.value

        if update_fields:
            pop_ref.update(update_fields)

        return True

    async def delete_pop(self, pop_id: str, user_id: str) -> bool:
        """
        ポップを削除（論理削除）

        Args:
            pop_id: ポップID
            user_id: ユーザーID（投稿者確認用）

        Returns:
            削除成功時True

        Raises:
            ValueError: ポップが見つからない、権限がない場合
        """
        pop_ref = self.db.collection(self.collection).document(pop_id)
        pop_doc = pop_ref.get()

        if not pop_doc.exists:
            raise ValueError("ポップが見つかりません")

        pop_data = pop_doc.to_dict()
        if pop_data["user_id"] != user_id:
            raise ValueError("このポップを削除する権限がありません")

        # 論理削除
        pop_ref.update({"status": PopStatus.DELETED.value})

        return True

    async def increment_reaction_count(self, pop_id: str) -> bool:
        """
        リアクション数をインクリメント

        Args:
            pop_id: ポップID

        Returns:
            成功時True
        """
        pop_ref = self.db.collection(self.collection).document(pop_id)
        pop_ref.update({"reaction_count": firestore.Increment(1)})
        return True

    async def decrement_reaction_count(self, pop_id: str) -> bool:
        """
        リアクション数をデクリメント

        Args:
            pop_id: ポップID

        Returns:
            成功時True
        """
        pop_ref = self.db.collection(self.collection).document(pop_id)
        pop_ref.update({"reaction_count": firestore.Increment(-1)})
        return True

    async def expire_old_pops(self) -> int:
        """
        期限切れポップを自動で無効化（Cloud Functionsから呼び出される）

        Returns:
            無効化したポップの件数
        """
        query = (
            self.db.collection(self.collection)
            .where("status", "==", PopStatus.ACTIVE.value)
            .where("expires_at", "<=", datetime.now(UTC))
        )

        docs = query.stream()
        count = 0

        for doc in docs:
            doc.reference.update({"status": PopStatus.EXPIRED.value})
            count += 1

        return count

    def _to_response(self, pop_in_db: PopInDB) -> PopResponse:
        """
        PopInDBをPopResponseに変換

        Args:
            pop_in_db: データベース内のポップ

        Returns:
            レスポンス用ポップ
        """
        return PopResponse(
            pop_id=pop_in_db.pop_id,
            user_id=pop_in_db.user_id,
            content=pop_in_db.content,
            category=pop_in_db.category,
            location=pop_in_db.location,
            created_at=pop_in_db.created_at,
            expires_at=pop_in_db.expires_at,
            duration_minutes=pop_in_db.duration_minutes,
            reaction_count=pop_in_db.reaction_count,
            is_premium=pop_in_db.is_premium,
            status=pop_in_db.status,
            visibility=pop_in_db.visibility,
            remaining_minutes=pop_in_db.remaining_minutes(),
            shrink_ratio=pop_in_db.shrink_ratio(),
        )

    def _calculate_distance(
        self, lat1: float, lon1: float, lat2: float, lon2: float
    ) -> float:
        """
        2点間の距離を計算（Haversine式）

        Args:
            lat1: 地点1の緯度
            lon1: 地点1の経度
            lat2: 地点2の緯度
            lon2: 地点2の経度

        Returns:
            距離（km）
        """
        from math import asin, cos, radians, sin, sqrt

        # 地球の半径（km）
        R = 6371.0

        # ラジアンに変換
        lat1_rad = radians(lat1)
        lon1_rad = radians(lon1)
        lat2_rad = radians(lat2)
        lon2_rad = radians(lon2)

        # 差分
        dlat = lat2_rad - lat1_rad
        dlon = lon2_rad - lon1_rad

        # Haversine式
        a = sin(dlat / 2) ** 2 + cos(lat1_rad) * cos(lat2_rad) * sin(dlon / 2) ** 2
        c = 2 * asin(sqrt(a))

        return R * c
