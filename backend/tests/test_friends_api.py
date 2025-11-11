"""
フレンド管理APIエンドポイントのテスト
"""

from datetime import datetime
from unittest.mock import AsyncMock, patch

from fastapi import status

from app.utils.timezone import now_jst

from app.schemas.friend import FriendRequestStatus, FriendshipStatus, TrustLevel


class TestFriendRequestEndpoints:
    """フレンドリクエスト関連エンドポイントのテスト"""

    def test_send_friend_request(self, client, sample_user1):
        """フレンドリクエスト送信エンドポイント"""
        mock_friend_service = AsyncMock()
        mock_friend_service.send_friend_request.return_value = AsyncMock(
            request_id="request_123",
            from_user_id=sample_user1.uid,
            to_user_id="target_user",
            message="よろしく",
            status=FriendRequestStatus.PENDING,
            created_at=now_jst(),
            responded_at=None,
        )

        with patch("app.api.v1.friends.FriendService", return_value=mock_friend_service):
            response = client.post(
                "/api/v1/friends/requests",
                json={"to_user_id": "target_user", "message": "よろしく"},
            )

            assert response.status_code == status.HTTP_201_CREATED
            data = response.json()
            assert "request_id" in data
            assert data["status"] == FriendRequestStatus.PENDING.value

    def test_send_friend_request_to_self_error(self, client):
        """自分自身へのフレンドリクエスト送信はエラー"""
        mock_friend_service = AsyncMock()
        mock_friend_service.send_friend_request.side_effect = ValueError(
            "自分自身にフレンドリクエストを送信できません"
        )

        with patch("app.api.v1.friends.FriendService", return_value=mock_friend_service):
            response = client.post(
                "/api/v1/friends/requests",
                json={"to_user_id": "test_user_1", "message": "test"},
            )

            assert response.status_code == status.HTTP_400_BAD_REQUEST

    def test_get_received_requests(self, client, sample_user1, sample_user2):
        """受信リクエスト一覧取得"""
        mock_friend_service = AsyncMock()
        mock_friend_service.get_received_requests.return_value = [
            AsyncMock(
                request_id="request_1",
                from_user_id=sample_user2.uid,
                to_user_id=sample_user1.uid,
                message="test",
                status=FriendRequestStatus.PENDING,
                created_at=now_jst(),
                responded_at=None,
                from_user_display_name=sample_user2.display_name,
                from_user_profile_image_url=None,
            )
        ]

        with patch("app.api.v1.friends.FriendService", return_value=mock_friend_service):
            response = client.get("/api/v1/friends/requests/received")

            assert response.status_code == status.HTTP_200_OK
            data = response.json()
            assert "requests" in data
            assert "total" in data
            assert data["total"] == 1

    def test_get_sent_requests(self, client):
        """送信リクエスト一覧取得"""
        mock_friend_service = AsyncMock()
        mock_friend_service.get_sent_requests.return_value = []

        with patch("app.api.v1.friends.FriendService", return_value=mock_friend_service):
            response = client.get("/api/v1/friends/requests/sent")

            assert response.status_code == status.HTTP_200_OK
            data = response.json()
            assert data["total"] == 0
            assert data["requests"] == []

    def test_accept_friend_request(self, client, sample_user1):
        """フレンドリクエスト承認"""
        mock_friend_service = AsyncMock()
        mock_friend_service.accept_friend_request.return_value = AsyncMock(
            friendship_id="friendship_1",
            user_id=sample_user1.uid,
            friend_id="friend_user",
            can_see_friend_location=False,  # 初期値はfalse
            nickname=None,
            status=FriendshipStatus.ACTIVE,
            created_at=now_jst(),
            updated_at=now_jst(),
            trust_level=TrustLevel.FRIEND,  # 後方互換性のため
        )

        with patch("app.api.v1.friends.FriendService", return_value=mock_friend_service):
            response = client.post("/api/v1/friends/requests/request_123/accept")

            assert response.status_code == status.HTTP_200_OK
            data = response.json()
            assert "friendship_id" in data
            assert "friend_id" in data

    def test_reject_friend_request(self, client):
        """フレンドリクエスト拒否"""
        mock_friend_service = AsyncMock()
        mock_friend_service.reject_friend_request.return_value = None

        with patch("app.api.v1.friends.FriendService", return_value=mock_friend_service):
            response = client.post("/api/v1/friends/requests/request_123/reject")

            assert response.status_code == status.HTTP_200_OK
            data = response.json()
            assert "message" in data


class TestFriendshipEndpoints:
    """フレンド関係管理エンドポイントのテスト"""

    def test_get_friends_list(self, client, sample_user1, sample_user2):
        """フレンド一覧取得"""
        mock_friend_service = AsyncMock()
        mock_friend_service.get_friends.return_value = [
            AsyncMock(
                friendship_id="friendship_1",
                friend_id=sample_user2.uid,
                can_see_friend_location=False,
                nickname=None,
                status=FriendshipStatus.ACTIVE,
                created_at=now_jst(),
                friend_display_name=sample_user2.display_name,
                friend_email=sample_user2.email,
                friend_profile_image_url=None,
                trust_level=TrustLevel.FRIEND,  # 後方互換性のため
            )
        ]

        with patch("app.api.v1.friends.FriendService", return_value=mock_friend_service):
            response = client.get("/api/v1/friends")

            assert response.status_code == status.HTTP_200_OK
            data = response.json()
            assert "friends" in data
            assert "total" in data
            assert data["total"] == 1
            assert data["friends"][0]["friend_id"] == sample_user2.uid

    def test_get_friend_detail(self, client, sample_user1, sample_user2):
        """特定フレンド情報取得"""
        mock_friend_service = AsyncMock()

        # get_friendshipのモック
        mock_friend_service.get_friendship.return_value = AsyncMock(
            friendship_id="friendship_1",
            user_id=sample_user1.uid,
            friend_id=sample_user2.uid,
            can_see_friend_location=False,
            trust_level=TrustLevel.FRIEND,
        )

        # get_friendsのモック
        mock_friend_service.get_friends.return_value = [
            AsyncMock(
                friendship_id="friendship_1",
                friend_id=sample_user2.uid,
                can_see_friend_location=False,
                nickname=None,
                status=FriendshipStatus.ACTIVE,
                created_at=now_jst(),
                friend_display_name=sample_user2.display_name,
                friend_email=sample_user2.email,
                friend_profile_image_url=None,
                trust_level=TrustLevel.FRIEND,
            )
        ]

        with patch("app.api.v1.friends.FriendService", return_value=mock_friend_service):
            response = client.get(f"/api/v1/friends/{sample_user2.uid}")

            assert response.status_code == status.HTTP_200_OK
            data = response.json()
            assert data["friend_id"] == sample_user2.uid

    def test_get_friend_not_found(self, client):
        """存在しないフレンド情報取得はエラー"""
        mock_friend_service = AsyncMock()
        mock_friend_service.get_friendship.return_value = None

        with patch("app.api.v1.friends.FriendService", return_value=mock_friend_service):
            response = client.get("/api/v1/friends/nonexistent_user")

            assert response.status_code == status.HTTP_404_NOT_FOUND

    def test_update_friendship(self, client, sample_user2):
        """フレンド関係更新（ニックネーム）"""
        mock_friend_service = AsyncMock()

        # update_friendshipのモック
        mock_friend_service.update_friendship.return_value = AsyncMock()

        # get_friendsのモック（更新後）
        mock_friend_service.get_friends.return_value = [
            AsyncMock(
                friendship_id="friendship_1",
                friend_id=sample_user2.uid,
                can_see_friend_location=False,
                nickname="親友",
                status=FriendshipStatus.ACTIVE,
                created_at=now_jst(),
                friend_display_name=sample_user2.display_name,
                friend_email=sample_user2.email,
                friend_profile_image_url=None,
                trust_level=TrustLevel.FRIEND,
            )
        ]

        with patch("app.api.v1.friends.FriendService", return_value=mock_friend_service):
            response = client.patch(
                f"/api/v1/friends/{sample_user2.uid}",
                json={"nickname": "親友"},
            )

            assert response.status_code == status.HTTP_200_OK
            data = response.json()
            assert data["nickname"] == "親友"

    def test_remove_friend(self, client, sample_user2):
        """フレンド削除"""
        mock_friend_service = AsyncMock()
        mock_friend_service.remove_friend.return_value = None

        with patch("app.api.v1.friends.FriendService", return_value=mock_friend_service):
            response = client.delete(f"/api/v1/friends/{sample_user2.uid}")

            assert response.status_code == status.HTTP_204_NO_CONTENT

    def test_block_user(self, client, sample_user2):
        """ユーザーブロック"""
        mock_friend_service = AsyncMock()
        mock_friend_service.block_user.return_value = None

        with patch("app.api.v1.friends.FriendService", return_value=mock_friend_service):
            response = client.post(f"/api/v1/friends/{sample_user2.uid}/block")

            assert response.status_code == status.HTTP_200_OK
            data = response.json()
            assert "message" in data


class TestLocationShareEndpoints:
    """位置情報共有関連エンドポイントのテスト"""

    def test_send_location_share_request(self, client, sample_user1, sample_user2):
        """位置情報共有リクエスト送信"""
        mock_friend_service = AsyncMock()
        mock_friend_service.send_location_share_request.return_value = AsyncMock(
            request_id="loc_request_123",
            requester_id=sample_user1.uid,
            target_id=sample_user2.uid,
            status=FriendRequestStatus.PENDING,
            created_at=now_jst(),
            responded_at=None,
        )

        with patch("app.api.v1.friends.FriendService", return_value=mock_friend_service):
            response = client.post(
                "/api/v1/friends/location-share/requests",
                json={"target_user_id": sample_user2.uid},
            )

            assert response.status_code == status.HTTP_201_CREATED
            data = response.json()
            assert "request_id" in data
            assert data["status"] == FriendRequestStatus.PENDING.value

    def test_send_location_share_request_not_friend_error(self, client, sample_user2):
        """フレンドでないユーザーへの位置情報共有リクエストはエラー"""
        mock_friend_service = AsyncMock()
        mock_friend_service.send_location_share_request.side_effect = ValueError(
            "位置情報共有リクエストを送信するにはフレンドである必要があります"
        )

        with patch("app.api.v1.friends.FriendService", return_value=mock_friend_service):
            response = client.post(
                "/api/v1/friends/location-share/requests",
                json={"target_user_id": sample_user2.uid},
            )

            assert response.status_code == status.HTTP_400_BAD_REQUEST

    def test_get_received_location_share_requests(self, client, sample_user1, sample_user2):
        """受信した位置情報共有リクエスト一覧取得"""
        mock_friend_service = AsyncMock()
        mock_friend_service.get_received_location_share_requests.return_value = [
            AsyncMock(
                request_id="loc_request_1",
                requester_id=sample_user2.uid,
                target_id=sample_user1.uid,
                status=FriendRequestStatus.PENDING,
                created_at=now_jst(),
                responded_at=None,
                requester_display_name=sample_user2.display_name,
                requester_profile_image_url=None,
            )
        ]

        with patch("app.api.v1.friends.FriendService", return_value=mock_friend_service):
            response = client.get("/api/v1/friends/location-share/requests/received")

            assert response.status_code == status.HTTP_200_OK
            data = response.json()
            assert "requests" in data
            assert "total" in data
            assert data["total"] == 1

    def test_get_sent_location_share_requests(self, client):
        """送信した位置情報共有リクエスト一覧取得"""
        mock_friend_service = AsyncMock()
        mock_friend_service.get_sent_location_share_requests.return_value = []

        with patch("app.api.v1.friends.FriendService", return_value=mock_friend_service):
            response = client.get("/api/v1/friends/location-share/requests/sent")

            assert response.status_code == status.HTTP_200_OK
            data = response.json()
            assert data["total"] == 0
            assert data["requests"] == []

    def test_accept_location_share_request(self, client, sample_user1):
        """位置情報共有リクエスト承認"""
        mock_friend_service = AsyncMock()
        mock_friend_service.accept_location_share_request.return_value = AsyncMock(
            friendship_id="friendship_1",
            user_id=sample_user1.uid,
            friend_id="requester_user",
            can_see_friend_location=True,  # 承認後はtrue
            status=FriendshipStatus.ACTIVE,
        )

        with patch("app.api.v1.friends.FriendService", return_value=mock_friend_service):
            response = client.post(
                "/api/v1/friends/location-share/requests/loc_request_123/accept"
            )

            assert response.status_code == status.HTTP_200_OK
            data = response.json()
            assert "friendship_id" in data

    def test_reject_location_share_request(self, client):
        """位置情報共有リクエスト拒否"""
        mock_friend_service = AsyncMock()
        mock_friend_service.reject_location_share_request.return_value = None

        with patch("app.api.v1.friends.FriendService", return_value=mock_friend_service):
            response = client.post(
                "/api/v1/friends/location-share/requests/loc_request_123/reject"
            )

            assert response.status_code == status.HTTP_200_OK
            data = response.json()
            assert "message" in data

    def test_revoke_location_share(self, client, sample_user2):
        """位置情報共有を停止"""
        mock_friend_service = AsyncMock()
        mock_friend_service.revoke_location_share.return_value = None

        with patch("app.api.v1.friends.FriendService", return_value=mock_friend_service):
            response = client.post(f"/api/v1/friends/{sample_user2.uid}/location-share/revoke")

            assert response.status_code == status.HTTP_200_OK
            data = response.json()
            assert "message" in data
            assert "停止" in data["message"]

    def test_revoke_location_share_already_stopped_error(self, client, sample_user2):
        """既に停止済みの位置情報共有を停止しようとするとエラー"""
        mock_friend_service = AsyncMock()
        mock_friend_service.revoke_location_share.side_effect = ValueError(
            "既に位置情報共有は停止されています"
        )

        with patch("app.api.v1.friends.FriendService", return_value=mock_friend_service):
            response = client.post(f"/api/v1/friends/{sample_user2.uid}/location-share/revoke")

            assert response.status_code == status.HTTP_400_BAD_REQUEST
