"""
位置情報スケジュール管理サービス
"""

import uuid
from datetime import UTC, datetime
from typing import List, Optional

from app.core.firebase import get_firestore_client
from app.schemas.schedule import (
    LocationScheduleCreate,
    LocationScheduleInDB,
    LocationScheduleUpdate,
    ScheduleStatus,
)


class ScheduleService:
    """位置情報スケジュール管理サービスクラス"""

    def __init__(self):
        self.db = get_firestore_client()
        self.collection_name = "schedules"

    async def create_schedule(
        self, user_id: str, schedule_data: LocationScheduleCreate
    ) -> LocationScheduleInDB:
        """
        スケジュールを作成

        Args:
            user_id: 作成者のユーザID
            schedule_data: スケジュール作成データ

        Returns:
            作成されたスケジュール情報

        Raises:
            ValueError: バリデーションエラー
        """
        # 開始時刻と終了時刻のバリデーション
        if schedule_data.start_time >= schedule_data.end_time:
            raise ValueError("開始時刻は終了時刻より前である必要があります")

        # 新しいスケジュールIDを生成
        schedule_id = str(uuid.uuid4())
        now = datetime.now(UTC)

        # スケジュールデータを作成
        schedule_dict = schedule_data.model_dump()
        schedule_dict.update(
            {
                "id": schedule_id,
                "user_id": user_id,
                "status": ScheduleStatus.ACTIVE.value,
                "arrived_at": None,
                "departed_at": None,
                "created_at": now,
                "updated_at": now,
            }
        )

        # Coordinates を辞書に変換
        if "destination_coords" in schedule_dict:
            schedule_dict["destination_coords"] = schedule_dict["destination_coords"]

        # Firestoreに保存
        schedule_ref = self.db.collection(self.collection_name).document(schedule_id)
        schedule_ref.set(schedule_dict)

        return LocationScheduleInDB(**schedule_dict)

    async def get_schedule_by_id(
        self, schedule_id: str, user_id: str
    ) -> Optional[LocationScheduleInDB]:
        """
        スケジュールIDからスケジュール情報を取得

        Args:
            schedule_id: スケジュールID
            user_id: ユーザID（権限チェック用）

        Returns:
            スケジュール情報、存在しない場合はNone

        Raises:
            ValueError: 権限がない場合
        """
        schedule_ref = self.db.collection(self.collection_name).document(schedule_id)
        schedule_doc = schedule_ref.get()

        if not schedule_doc.exists:
            return None

        schedule_data = schedule_doc.to_dict()

        # 権限チェック: 作成者本人のみアクセス可能
        if schedule_data.get("user_id") != user_id:
            raise ValueError("このスケジュールにアクセスする権限がありません")

        return LocationScheduleInDB(**schedule_data)

    async def get_schedules_by_user(
        self, user_id: str, status: Optional[ScheduleStatus] = None
    ) -> List[LocationScheduleInDB]:
        """
        ユーザーのスケジュール一覧を取得

        Args:
            user_id: ユーザID
            status: フィルタリングするステータス（Noneの場合は全て取得）

        Returns:
            スケジュール一覧
        """
        query = self.db.collection(self.collection_name).where("user_id", "==", user_id)

        # ステータスでフィルタリング
        if status:
            query = query.where("status", "==", status.value)

        schedules_docs = query.stream()

        schedules = []
        for doc in schedules_docs:
            schedule_data = doc.to_dict()
            schedules.append(LocationScheduleInDB(**schedule_data))

        # Pythonで開始時刻で降順にソート
        schedules.sort(key=lambda x: x.start_time, reverse=True)

        return schedules

    async def get_active_schedules(self, user_id: str) -> List[LocationScheduleInDB]:
        """
        ユーザーのアクティブなスケジュール一覧を取得

        Args:
            user_id: ユーザID

        Returns:
            アクティブなスケジュール一覧
        """
        return await self.get_schedules_by_user(user_id, ScheduleStatus.ACTIVE)

    async def update_schedule(
        self, schedule_id: str, user_id: str, update_data: LocationScheduleUpdate
    ) -> LocationScheduleInDB:
        """
        スケジュール情報を更新

        Args:
            schedule_id: スケジュールID
            user_id: ユーザID（権限チェック用）
            update_data: 更新データ

        Returns:
            更新後のスケジュール情報

        Raises:
            ValueError: スケジュールが見つからない、または権限がない場合
        """
        schedule_ref = self.db.collection(self.collection_name).document(schedule_id)
        schedule_doc = schedule_ref.get()

        if not schedule_doc.exists:
            raise ValueError("スケジュールが見つかりません")

        schedule_data = schedule_doc.to_dict()

        # 権限チェック
        if schedule_data.get("user_id") != user_id:
            raise ValueError("このスケジュールを更新する権限がありません")

        # 更新データの準備（Noneでない値のみ）
        update_dict = update_data.model_dump(exclude_unset=True, exclude_none=True)

        # 開始時刻と終了時刻の整合性チェック
        start_time = update_dict.get("start_time", schedule_data.get("start_time"))
        end_time = update_dict.get("end_time", schedule_data.get("end_time"))
        if start_time >= end_time:
            raise ValueError("開始時刻は終了時刻より前である必要があります")

        update_dict["updated_at"] = datetime.now(UTC)

        # Firestoreを更新
        schedule_ref.update(update_dict)

        # 更新後のスケジュール情報を取得
        return await self.get_schedule_by_id(schedule_id, user_id)

    async def update_schedule_status(
        self,
        schedule_id: str,
        status: ScheduleStatus,
        arrived_at: Optional[datetime] = None,
        departed_at: Optional[datetime] = None,
    ) -> LocationScheduleInDB:
        """
        スケジュールのステータスを更新（内部処理用）

        Args:
            schedule_id: スケジュールID
            status: 新しいステータス
            arrived_at: 到着日時（オプション）
            departed_at: 退出日時（オプション）

        Returns:
            更新後のスケジュール情報

        Raises:
            ValueError: スケジュールが見つからない場合
        """
        schedule_ref = self.db.collection(self.collection_name).document(schedule_id)
        schedule_doc = schedule_ref.get()

        if not schedule_doc.exists:
            raise ValueError("スケジュールが見つかりません")

        update_dict = {
            "status": status.value,
            "updated_at": datetime.now(UTC),
        }

        if arrived_at:
            update_dict["arrived_at"] = arrived_at
        if departed_at:
            update_dict["departed_at"] = departed_at

        # Firestoreを更新
        schedule_ref.update(update_dict)

        # 更新後のスケジュール情報を取得
        schedule_doc = schedule_ref.get()
        schedule_data = schedule_doc.to_dict()
        return LocationScheduleInDB(**schedule_data)

    async def delete_schedule(self, schedule_id: str, user_id: str) -> None:
        """
        スケジュールを削除

        Args:
            schedule_id: スケジュールID
            user_id: ユーザID（権限チェック用）

        Raises:
            ValueError: スケジュールが見つからない、または権限がない場合
        """
        schedule_ref = self.db.collection(self.collection_name).document(schedule_id)
        schedule_doc = schedule_ref.get()

        if not schedule_doc.exists:
            raise ValueError("スケジュールが見つかりません")

        schedule_data = schedule_doc.to_dict()

        # 権限チェック
        if schedule_data.get("user_id") != user_id:
            raise ValueError("このスケジュールを削除する権限がありません")

        # Firestoreから削除
        schedule_ref.delete()
