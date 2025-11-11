"""
フレンド管理サービス
"""

from datetime import datetime
from typing import List, Optional

from google.cloud.firestore_v1 import FieldFilter

from app.core.firebase import get_firestore_client
from app.utils.timezone import now_jst
from app.schemas.friend import (
    FriendRequestCreate,
    FriendRequestResponse,
    FriendRequestStatus,
    FriendshipInDB,
    FriendshipResponse,
    FriendshipStatus,
    FriendshipUpdate,
    LocationShareRequestCreate,
    LocationShareRequestResponse,
    TrustLevel,
)
from app.services.users import UserService


class FriendService:
    """フレンド管理サービスクラス"""

    def __init__(self):
        self.db = get_firestore_client()
        self.user_service = UserService()

    async def send_friend_request(
        self, from_user_id: str, request_data: FriendRequestCreate
    ) -> FriendRequestResponse:
        """
        フレンドリクエストを送信

        Args:
            from_user_id: リクエスト送信者のUID
            request_data: リクエストデータ

        Returns:
            作成されたリクエスト情報

        Raises:
            ValueError: 自分自身へのリクエスト、既存のリクエスト、既にフレンドの場合
        """
        to_user_id = request_data.to_user_id

        # 自分自身へのリクエストはエラー
        if from_user_id == to_user_id:
            raise ValueError("自分自身にフレンドリクエストを送信できません")

        # 送信先ユーザーが存在するか確認
        to_user = await self.user_service.get_user_by_uid(to_user_id)
        if not to_user:
            raise ValueError("指定されたユーザーが見つかりません")

        # 既にフレンドかチェック
        if await self.is_friend(from_user_id, to_user_id):
            raise ValueError("既にフレンドです")

        # 既存のpendingリクエストがないかチェック
        existing_requests = (
            self.db.collection("friend_requests")
            .where(filter=FieldFilter("from_user_id", "==", from_user_id))
            .where(filter=FieldFilter("to_user_id", "==", to_user_id))
            .where(filter=FieldFilter("status", "==", FriendRequestStatus.PENDING.value))
            .get()
        )

        if len(list(existing_requests)) > 0:
            raise ValueError("既にフレンドリクエストを送信済みです")

        # リクエストを作成
        request_ref = self.db.collection("friend_requests").document()
        request_data_dict = {
            "request_id": request_ref.id,
            "from_user_id": from_user_id,
            "to_user_id": to_user_id,
            "message": request_data.message,
            "status": FriendRequestStatus.PENDING.value,
            "created_at": now_jst(),
            "responded_at": None,
        }

        request_ref.set(request_data_dict)

        return FriendRequestResponse(**request_data_dict)

    async def get_received_requests(self, user_id: str) -> List[FriendRequestResponse]:
        """
        受信したフレンドリクエスト一覧を取得

        Args:
            user_id: ユーザID

        Returns:
            リクエスト一覧
        """
        requests = (
            self.db.collection("friend_requests")
            .where(filter=FieldFilter("to_user_id", "==", user_id))
            .where(filter=FieldFilter("status", "==", FriendRequestStatus.PENDING.value))
            .get()
        )

        result = []
        for req in requests:
            req_data = req.to_dict()

            # 送信者の情報を取得
            from_user = await self.user_service.get_user_by_uid(req_data["from_user_id"])
            if from_user:
                req_data["from_user_display_name"] = from_user.display_name
                req_data["from_user_username"] = from_user.username
                req_data["from_user_profile_image_url"] = from_user.profile_image_url

            result.append(FriendRequestResponse(**req_data))

        # Python側でソート（created_atの降順）
        result.sort(key=lambda x: x.created_at, reverse=True)

        return result

    async def get_sent_requests(self, user_id: str) -> List[FriendRequestResponse]:
        """
        送信したフレンドリクエスト一覧を取得

        Args:
            user_id: ユーザID

        Returns:
            リクエスト一覧
        """
        requests = (
            self.db.collection("friend_requests")
            .where(filter=FieldFilter("from_user_id", "==", user_id))
            .where(filter=FieldFilter("status", "==", FriendRequestStatus.PENDING.value))
            .get()
        )

        result = []
        for req in requests:
            req_data = req.to_dict()

            # 送信先の情報を取得
            to_user = await self.user_service.get_user_by_uid(req_data["to_user_id"])
            if to_user:
                req_data["to_user_display_name"] = to_user.display_name
                req_data["to_user_username"] = to_user.username
                req_data["to_user_profile_image_url"] = to_user.profile_image_url

            result.append(FriendRequestResponse(**req_data))

        # Python側でソート（created_atの降順）
        result.sort(key=lambda x: x.created_at, reverse=True)

        return result

    async def accept_friend_request(self, user_id: str, request_id: str) -> FriendshipInDB:
        """
        フレンドリクエストを承認

        Args:
            user_id: 承認するユーザID（リクエスト受信者）
            request_id: リクエストID

        Returns:
            作成されたフレンド関係

        Raises:
            ValueError: リクエストが見つからない、権限がない場合
        """
        request_ref = self.db.collection("friend_requests").document(request_id)
        request_doc = request_ref.get()

        if not request_doc.exists:
            raise ValueError("リクエストが見つかりません")

        request_data = request_doc.to_dict()

        # リクエスト受信者かチェック
        if request_data["to_user_id"] != user_id:
            raise ValueError("このリクエストを承認する権限がありません")

        # ステータスがpendingかチェック
        if request_data["status"] != FriendRequestStatus.PENDING.value:
            raise ValueError("このリクエストは既に処理済みです")

        # リクエストステータスを更新
        request_ref.update(
            {"status": FriendRequestStatus.ACCEPTED.value, "responded_at": now_jst()}
        )

        # フレンド関係を作成（双方向）
        # 位置情報共有はデフォルトでオフ（別途リクエストが必要）
        friendship1 = await self._create_friendship(
            user_id=request_data["to_user_id"],
            friend_id=request_data["from_user_id"],
            can_see_friend_location=False,
        )

        await self._create_friendship(
            user_id=request_data["from_user_id"],
            friend_id=request_data["to_user_id"],
            can_see_friend_location=False,
        )

        return friendship1

    async def reject_friend_request(self, user_id: str, request_id: str) -> None:
        """
        フレンドリクエストを拒否

        Args:
            user_id: 拒否するユーザID（リクエスト受信者）
            request_id: リクエストID

        Raises:
            ValueError: リクエストが見つからない、権限がない場合
        """
        request_ref = self.db.collection("friend_requests").document(request_id)
        request_doc = request_ref.get()

        if not request_doc.exists:
            raise ValueError("リクエストが見つかりません")

        request_data = request_doc.to_dict()

        # リクエスト受信者かチェック
        if request_data["to_user_id"] != user_id:
            raise ValueError("このリクエストを拒否する権限がありません")

        # ステータスがpendingかチェック
        if request_data["status"] != FriendRequestStatus.PENDING.value:
            raise ValueError("このリクエストは既に処理済みです")

        # リクエストステータスを更新
        request_ref.update(
            {"status": FriendRequestStatus.REJECTED.value, "responded_at": now_jst()}
        )

    async def _create_friendship(
        self,
        user_id: str,
        friend_id: str,
        can_see_friend_location: bool = False,
        nickname: Optional[str] = None,
    ) -> FriendshipInDB:
        """
        フレンド関係を作成（内部メソッド）

        Args:
            user_id: ユーザID
            friend_id: フレンドID
            can_see_friend_location: このユーザーがフレンドの位置を見られるか
            nickname: ニックネーム

        Returns:
            作成されたフレンド関係
        """
        friendship_ref = self.db.collection("friendships").document()
        friendship_data = {
            "friendship_id": friendship_ref.id,
            "user_id": user_id,
            "friend_id": friend_id,
            "can_see_friend_location": can_see_friend_location,
            "nickname": nickname,
            "status": FriendshipStatus.ACTIVE.value,
            "created_at": now_jst(),
            "updated_at": now_jst(),
            # 後方互換性のため
            "trust_level": TrustLevel.FRIEND.value,
        }

        friendship_ref.set(friendship_data)

        return FriendshipInDB(**friendship_data)

    async def get_friends(self, user_id: str) -> List[FriendshipResponse]:
        """
        フレンド一覧を取得

        Args:
            user_id: ユーザID

        Returns:
            フレンド一覧
        """
        friendships = (
            self.db.collection("friendships")
            .where(filter=FieldFilter("user_id", "==", user_id))
            .where(filter=FieldFilter("status", "==", FriendshipStatus.ACTIVE.value))
            .get()
        )

        result = []
        for friendship in friendships:
            friendship_data = friendship.to_dict()

            # フレンドのユーザー情報を取得
            friend = await self.user_service.get_user_by_uid(friendship_data["friend_id"])
            if friend:
                friendship_data["friend_display_name"] = friend.display_name
                friendship_data["friend_username"] = friend.username
                friendship_data["friend_email"] = friend.email
                friendship_data["friend_profile_image_url"] = friend.profile_image_url

            result.append(FriendshipResponse(**friendship_data))

        return result

    async def get_friendship(self, user_id: str, friend_id: str) -> Optional[FriendshipInDB]:
        """
        特定のフレンド関係を取得

        Args:
            user_id: ユーザID
            friend_id: フレンドID

        Returns:
            フレンド関係、存在しない場合はNone
        """
        friendships = (
            self.db.collection("friendships")
            .where(filter=FieldFilter("user_id", "==", user_id))
            .where(filter=FieldFilter("friend_id", "==", friend_id))
            .where(filter=FieldFilter("status", "==", FriendshipStatus.ACTIVE.value))
            .limit(1)
            .get()
        )

        friendship_list = list(friendships)
        if not friendship_list:
            return None

        return FriendshipInDB(**friendship_list[0].to_dict())

    async def is_friend(self, user_id: str, friend_id: str) -> bool:
        """
        フレンドかどうか確認

        Args:
            user_id: ユーザID
            friend_id: フレンドID

        Returns:
            フレンドの場合True
        """
        friendship = await self.get_friendship(user_id, friend_id)
        return friendship is not None

    async def update_friendship(
        self, user_id: str, friend_id: str, update_data: FriendshipUpdate
    ) -> FriendshipInDB:
        """
        フレンド関係を更新（信頼レベルやニックネーム）

        Args:
            user_id: ユーザID
            friend_id: フレンドID
            update_data: 更新データ

        Returns:
            更新後のフレンド関係

        Raises:
            ValueError: フレンド関係が見つからない場合
        """
        friendship = await self.get_friendship(user_id, friend_id)
        if not friendship:
            raise ValueError("フレンド関係が見つかりません")

        # 更新データの準備
        update_dict = update_data.model_dump(exclude_unset=True, exclude_none=True)
        # 後方互換性のため、trust_levelがあれば値に変換
        if "trust_level" in update_dict and update_dict["trust_level"] is not None:
            update_dict["trust_level"] = update_dict["trust_level"].value
        update_dict["updated_at"] = now_jst()

        # Firestoreを更新
        friendship_ref = self.db.collection("friendships").document(friendship.friendship_id)
        friendship_ref.update(update_dict)

        # 更新後のデータを取得
        updated_doc = friendship_ref.get()
        return FriendshipInDB(**updated_doc.to_dict())

    async def remove_friend(self, user_id: str, friend_id: str) -> None:
        """
        フレンド関係を削除（双方向）

        Args:
            user_id: ユーザID
            friend_id: フレンドID

        Raises:
            ValueError: フレンド関係が見つからない場合
        """
        # user_id -> friend_id の関係を削除
        friendship1 = await self.get_friendship(user_id, friend_id)
        if friendship1:
            friendship1_ref = self.db.collection("friendships").document(friendship1.friendship_id)
            friendship1_ref.delete()

        # friend_id -> user_id の関係を削除
        friendship2 = await self.get_friendship(friend_id, user_id)
        if friendship2:
            friendship2_ref = self.db.collection("friendships").document(friendship2.friendship_id)
            friendship2_ref.delete()

        if not friendship1 and not friendship2:
            raise ValueError("フレンド関係が見つかりません")

    async def block_user(self, user_id: str, friend_id: str) -> None:
        """
        ユーザーをブロック

        Args:
            user_id: ユーザID
            friend_id: ブロックするユーザID
        """
        friendship = await self.get_friendship(user_id, friend_id)
        if friendship:
            friendship_ref = self.db.collection("friendships").document(friendship.friendship_id)
            friendship_ref.update(
                {"status": FriendshipStatus.BLOCKED.value, "updated_at": now_jst()}
            )

    async def get_trust_level(self, user_id: str, friend_id: str) -> Optional[TrustLevel]:
        """
        フレンドの信頼レベルを取得（後方互換性のため残す、非推奨）

        Args:
            user_id: ユーザID
            friend_id: フレンドID

        Returns:
            信頼レベル、フレンドでない場合はNone
        """
        friendship = await self.get_friendship(user_id, friend_id)
        if not friendship:
            return None

        # 後方互換性のため
        if friendship.trust_level is not None:
            return TrustLevel(friendship.trust_level)
        return TrustLevel.FRIEND

    async def can_see_location(self, viewer_id: str, target_id: str) -> bool:
        """
        位置情報を見る権限があるかチェック

        Args:
            viewer_id: 位置を見たいユーザID
            target_id: 位置を見られるユーザID

        Returns:
            位置情報を見られる場合True
        """
        friendship = await self.get_friendship(viewer_id, target_id)
        if not friendship:
            return False

        return friendship.can_see_friend_location

    # ==================== 位置情報共有リクエスト ====================

    async def send_location_share_request(
        self, requester_id: str, request_data: LocationShareRequestCreate
    ) -> LocationShareRequestResponse:
        """
        位置情報共有リクエストを送信

        Args:
            requester_id: リクエスト送信者のUID（位置を見たい人）
            request_data: リクエストデータ

        Returns:
            作成されたリクエスト情報

        Raises:
            ValueError: 自分自身へのリクエスト、既存のリクエスト、フレンドでない場合
        """
        target_id = request_data.target_user_id

        # 自分自身へのリクエストはエラー
        if requester_id == target_id:
            raise ValueError("自分自身に位置情報共有リクエストを送信できません")

        # フレンドかチェック
        if not await self.is_friend(requester_id, target_id):
            raise ValueError("位置情報共有リクエストを送信するにはフレンドである必要があります")

        # 既に位置情報を見られる場合
        if await self.can_see_location(requester_id, target_id):
            raise ValueError("既に位置情報を見ることができます")

        # 既存のpendingリクエストがないかチェック
        existing_requests = (
            self.db.collection("location_share_requests")
            .where(filter=FieldFilter("requester_id", "==", requester_id))
            .where(filter=FieldFilter("target_id", "==", target_id))
            .where(filter=FieldFilter("status", "==", FriendRequestStatus.PENDING.value))
            .get()
        )

        if len(list(existing_requests)) > 0:
            raise ValueError("既に位置情報共有リクエストを送信済みです")

        # リクエストを作成
        request_ref = self.db.collection("location_share_requests").document()
        request_data_dict = {
            "request_id": request_ref.id,
            "requester_id": requester_id,
            "target_id": target_id,
            "status": FriendRequestStatus.PENDING.value,
            "created_at": now_jst(),
            "responded_at": None,
        }

        request_ref.set(request_data_dict)

        return LocationShareRequestResponse(**request_data_dict)

    async def get_received_location_share_requests(
        self, user_id: str
    ) -> List[LocationShareRequestResponse]:
        """
        受信した位置情報共有リクエスト一覧を取得

        Args:
            user_id: ユーザID

        Returns:
            リクエスト一覧
        """
        requests = (
            self.db.collection("location_share_requests")
            .where(filter=FieldFilter("target_id", "==", user_id))
            .where(filter=FieldFilter("status", "==", FriendRequestStatus.PENDING.value))
            .get()
        )

        result = []
        for req in requests:
            req_data = req.to_dict()

            # リクエスト送信者の情報を取得
            requester = await self.user_service.get_user_by_uid(req_data["requester_id"])
            if requester:
                req_data["requester_display_name"] = requester.display_name
                req_data["requester_profile_image_url"] = requester.profile_image_url

            result.append(LocationShareRequestResponse(**req_data))

        # Python側でソート（created_atの降順）
        result.sort(key=lambda x: x.created_at, reverse=True)

        return result

    async def get_sent_location_share_requests(
        self, user_id: str
    ) -> List[LocationShareRequestResponse]:
        """
        送信した位置情報共有リクエスト一覧を取得

        Args:
            user_id: ユーザID

        Returns:
            リクエスト一覧
        """
        requests = (
            self.db.collection("location_share_requests")
            .where(filter=FieldFilter("requester_id", "==", user_id))
            .where(filter=FieldFilter("status", "==", FriendRequestStatus.PENDING.value))
            .get()
        )

        result = []
        for req in requests:
            req_data = req.to_dict()
            result.append(LocationShareRequestResponse(**req_data))

        # Python側でソート（created_atの降順）
        result.sort(key=lambda x: x.created_at, reverse=True)

        return result

    async def accept_location_share_request(self, user_id: str, request_id: str) -> FriendshipInDB:
        """
        位置情報共有リクエストを承認

        Args:
            user_id: 承認するユーザID（リクエスト受信者＝位置を見られる人）
            request_id: リクエストID

        Returns:
            更新されたフレンド関係

        Raises:
            ValueError: リクエストが見つからない、権限がない場合
        """
        request_ref = self.db.collection("location_share_requests").document(request_id)
        request_doc = request_ref.get()

        if not request_doc.exists:
            raise ValueError("リクエストが見つかりません")

        request_data = request_doc.to_dict()

        # リクエスト受信者かチェック
        if request_data["target_id"] != user_id:
            raise ValueError("このリクエストを承認する権限がありません")

        # ステータスがpendingかチェック
        if request_data["status"] != FriendRequestStatus.PENDING.value:
            raise ValueError("このリクエストは既に処理済みです")

        # リクエストステータスを更新
        request_ref.update(
            {"status": FriendRequestStatus.ACCEPTED.value, "responded_at": now_jst()}
        )

        # フレンド関係を更新（requesterがtargetの位置を見られるようにする）
        friendship = await self.get_friendship(
            request_data["requester_id"], request_data["target_id"]
        )
        if not friendship:
            raise ValueError("フレンド関係が見つかりません")

        friendship_ref = self.db.collection("friendships").document(friendship.friendship_id)
        friendship_ref.update({"can_see_friend_location": True, "updated_at": now_jst()})

        # 更新後のフレンド関係を取得して返す
        updated_doc = friendship_ref.get()
        return FriendshipInDB(**updated_doc.to_dict())

    async def reject_location_share_request(self, user_id: str, request_id: str) -> None:
        """
        位置情報共有リクエストを拒否

        Args:
            user_id: 拒否するユーザID（リクエスト受信者）
            request_id: リクエストID

        Raises:
            ValueError: リクエストが見つからない、権限がない場合
        """
        request_ref = self.db.collection("location_share_requests").document(request_id)
        request_doc = request_ref.get()

        if not request_doc.exists:
            raise ValueError("リクエストが見つかりません")

        request_data = request_doc.to_dict()

        # リクエスト受信者かチェック
        if request_data["target_id"] != user_id:
            raise ValueError("このリクエストを拒否する権限がありません")

        # ステータスがpendingかチェック
        if request_data["status"] != FriendRequestStatus.PENDING.value:
            raise ValueError("このリクエストは既に処理済みです")

        # リクエストステータスを更新
        request_ref.update(
            {"status": FriendRequestStatus.REJECTED.value, "responded_at": now_jst()}
        )

    async def revoke_location_share(self, user_id: str, viewer_id: str) -> None:
        """
        位置情報共有を停止する

        自分の位置情報を相手に見せないようにします。
        相手の画面では、このユーザーの位置ステータスが表示されなくなります。

        Args:
            user_id: 共有を停止する人（位置を見られている人）
            viewer_id: 共有を停止される人（位置を見ている人）

        Raises:
            ValueError: フレンド関係が見つからない、既に共有していない場合
        """
        # viewer_id -> user_id のフレンド関係を取得
        # （viewer_id が user_id の位置を見る権限）
        friendship = await self.get_friendship(viewer_id, user_id)
        if not friendship:
            raise ValueError("フレンド関係が見つかりません")

        # 既に共有していない場合
        if not friendship.can_see_friend_location:
            raise ValueError("既に位置情報共有は停止されています")

        # can_see_friend_location を false にする
        friendship_ref = self.db.collection("friendships").document(friendship.friendship_id)
        friendship_ref.update({"can_see_friend_location": False, "updated_at": now_jst()})
