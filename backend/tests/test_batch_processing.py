"""
バッチ処理のテスト

滞在通知の自動送信、データクリーンアップなどのバッチ処理をテストします。
"""

import pytest
from datetime import UTC, datetime, timedelta
from unittest.mock import AsyncMock, MagicMock, patch

from app.schemas.location import Coordinates
from app.schemas.schedule import LocationScheduleInDB, ScheduleStatus
from app.services.auto_notification import AutoNotificationService
from app.services.cleanup import CleanupService


@pytest.fixture
def auto_notification_service():
    """自動通知サービスのフィクスチャ"""
    return AutoNotificationService()


@pytest.fixture
def cleanup_service():
    """クリーンアップサービスのフィクスチャ"""
    return CleanupService()


@pytest.fixture
def sample_arrived_schedule():
    """到着済みスケジュールのサンプル（60分滞在済み）"""
    now = datetime.now(UTC)
    return LocationScheduleInDB(
        id="schedule_arrived_123",
        user_id="user_arrived_123",
        destination_name="カフェA",
        destination_address="東京都渋谷区",
        destination_coords=Coordinates(lat=35.6580, lng=139.7016),
        geofence_radius=50,
        notify_to_user_ids=["friend_1", "friend_2"],
        start_time=now - timedelta(hours=2),
        end_time=now + timedelta(hours=2),
        recurrence=None,
        notify_on_arrival=True,
        notify_after_minutes=60,
        notify_on_departure=True,
        status=ScheduleStatus.ARRIVED,
        arrived_at=now - timedelta(minutes=65),  # 65分前に到着
        departed_at=None,
        favorite=False,
        created_at=now - timedelta(hours=2),
        updated_at=now - timedelta(minutes=65),
    )


@pytest.mark.asyncio
async def test_check_and_send_stay_notifications(
    auto_notification_service, sample_arrived_schedule
):
    """滞在通知バッチ処理のテスト"""
    mock_schedule_doc = MagicMock()
    mock_schedule_doc.to_dict.return_value = sample_arrived_schedule.model_dump()

    mock_location_history = MagicMock()
    mock_location_history.coords = Coordinates(lat=35.6580, lng=139.7016)

    with patch.object(
        auto_notification_service.db, "collection"
    ) as mock_collection, patch(
        "app.services.auto_notification.LocationService"
    ) as MockLocationService, patch(
        "app.services.auto_notification.UserService"
    ) as MockUserService, patch.object(
        auto_notification_service.notification_service,
        "send_push_notification",
        new_callable=AsyncMock,
    ):

        # スケジュールクエリのモック
        mock_schedules_query = mock_collection.return_value.where.return_value
        mock_schedules_query.stream.return_value = [mock_schedule_doc]

        # 通知履歴クエリのモック（まだ送信されていない）
        def mock_collection_side_effect(collection_name):
            if collection_name == "schedules":
                return mock_collection.return_value
            elif collection_name == "notification_history":
                mock_history_collection = MagicMock()
                mock_history_query = (
                    mock_history_collection.where.return_value.where.return_value
                )
                mock_history_query.stream.return_value = []  # 通知履歴なし
                return mock_history_collection
            return MagicMock()

        mock_collection.side_effect = mock_collection_side_effect

        # LocationServiceのモック
        mock_location_service = MockLocationService.return_value
        mock_location_service.get_latest_location = AsyncMock(
            return_value=mock_location_history
        )

        # UserServiceのモック
        from app.schemas.user import UserInDB

        mock_user = UserInDB(
            uid="user_arrived_123",
            email="test@example.com",
            username="testuser",
            display_name="テストユーザー",
            fcm_tokens=["fcm_token_123"],
            created_at=datetime.now(UTC),
            updated_at=datetime.now(UTC),
        )
        mock_user_service = MockUserService.return_value
        mock_user_service.get_user_by_uid = AsyncMock(return_value=mock_user)

        # 通知履歴保存のモック
        mock_history_doc = MagicMock()
        auto_notification_service.db.collection = lambda name: (
            MagicMock(
                document=lambda: MagicMock(set=AsyncMock(), id="notification_123")
            )
        )

        sent_count = await auto_notification_service.check_and_send_stay_notifications()

        # 通知が送信される（フレンド2人分）
        assert sent_count == 2


@pytest.mark.asyncio
async def test_check_and_send_stay_notifications_insufficient_duration(
    auto_notification_service, sample_arrived_schedule
):
    """滞在時間が不足している場合のテスト"""
    # 到着から30分しか経過していない
    sample_arrived_schedule.arrived_at = datetime.now(UTC) - timedelta(minutes=30)

    mock_schedule_doc = MagicMock()
    mock_schedule_doc.to_dict.return_value = sample_arrived_schedule.model_dump()

    with patch.object(auto_notification_service.db, "collection") as mock_collection:
        mock_schedules_query = mock_collection.return_value.where.return_value
        mock_schedules_query.stream.return_value = [mock_schedule_doc]

        sent_count = await auto_notification_service.check_and_send_stay_notifications()

        # 滞在時間が不足しているので通知されない
        assert sent_count == 0


@pytest.mark.asyncio
async def test_cleanup_old_locations(cleanup_service):
    """古い位置情報履歴のクリーンアップテスト"""
    now = datetime.now(UTC)

    # 24時間以上前の位置情報履歴をモック
    old_location_doc = MagicMock()
    old_location_doc.to_dict.return_value = {
        "id": "old_location_123",
        "user_id": "user_123",
        "coords": {"lat": 35.6580, "lng": 139.7016},
        "auto_delete_at": now - timedelta(hours=25),
    }

    with patch.object(
        cleanup_service.location_service.db, "collection"
    ) as mock_collection:
        mock_query = mock_collection.return_value.where.return_value
        mock_query.stream.return_value = [old_location_doc]

        deleted_count = await cleanup_service.location_service.cleanup_old_locations()

        assert deleted_count == 1
        old_location_doc.reference.delete.assert_called_once()


@pytest.mark.asyncio
async def test_cleanup_old_notification_history(cleanup_service):
    """古い通知履歴のクリーンアップテスト"""
    now = datetime.now(UTC)

    # 24時間以上前の通知履歴をモック
    old_notification_doc = MagicMock()
    old_notification_doc.to_dict.return_value = {
        "id": "old_notification_123",
        "schedule_id": "schedule_123",
        "auto_delete_at": now - timedelta(hours=25),
    }

    with patch.object(
        cleanup_service.notification_service.db, "collection"
    ) as mock_collection:
        mock_query = mock_collection.return_value.where.return_value
        mock_query.stream.return_value = [old_notification_doc]

        deleted_count = (
            await cleanup_service.notification_service.cleanup_old_notification_history()
        )

        assert deleted_count == 1
        old_notification_doc.reference.delete.assert_called_once()


@pytest.mark.asyncio
async def test_update_expired_schedules_status(cleanup_service):
    """期限切れスケジュールのステータス更新テスト"""
    now = datetime.now(UTC)

    # 終了時刻を過ぎたスケジュール
    expired_schedule_doc = MagicMock()
    expired_schedule_doc.id = "expired_schedule_123"
    expired_schedule_doc.to_dict.return_value = {
        "id": "expired_schedule_123",
        "status": "active",
        "end_time": now - timedelta(hours=1),
    }

    with patch.object(cleanup_service.db, "collection") as mock_collection:
        mock_query_active = (
            mock_collection.return_value.where.return_value.where.return_value
        )
        mock_query_active.stream.return_value = [expired_schedule_doc]

        mock_query_arrived = (
            mock_collection.return_value.where.return_value.where.return_value
        )
        mock_query_arrived.stream.return_value = []

        updated_count = await cleanup_service.update_expired_schedules_status()

        assert updated_count == 1
        expired_schedule_doc.reference.update.assert_called_once()


@pytest.mark.asyncio
async def test_cleanup_expired_schedules(cleanup_service):
    """期限切れスケジュールの削除テスト"""
    now = datetime.now(UTC)

    # 終了から24時間以上経過したスケジュール
    old_schedule_doc = MagicMock()
    old_schedule_doc.to_dict.return_value = {
        "id": "old_schedule_123",
        "end_time": now - timedelta(hours=25),
        "status": "completed",
    }

    with patch.object(cleanup_service.db, "collection") as mock_collection, patch.object(
        cleanup_service, "_delete_related_location_history", new_callable=AsyncMock
    ) as mock_delete_location, patch.object(
        cleanup_service, "_delete_related_notification_history", new_callable=AsyncMock
    ) as mock_delete_notification:

        mock_query = mock_collection.return_value.where.return_value
        mock_query.stream.return_value = [old_schedule_doc]

        mock_delete_location.return_value = 5
        mock_delete_notification.return_value = 3

        deleted_count = await cleanup_service.cleanup_expired_schedules()

        assert deleted_count == 1
        old_schedule_doc.reference.delete.assert_called_once()
        mock_delete_location.assert_called_once_with("old_schedule_123")
        mock_delete_notification.assert_called_once_with("old_schedule_123")


@pytest.mark.asyncio
async def test_get_cleanup_stats(cleanup_service):
    """クリーンアップ統計情報取得のテスト"""
    now = datetime.now(UTC)

    # モックデータ
    location_docs = [MagicMock() for _ in range(3)]
    notification_docs = [MagicMock() for _ in range(2)]
    schedule_docs = [
        MagicMock(
            to_dict=lambda: {
                "id": "schedule_1",
                "end_time": now - timedelta(hours=25),
            }
        )
    ]

    with patch.object(cleanup_service.db, "collection") as mock_collection:

        def mock_query_side_effect(collection_name):
            mock_col = MagicMock()
            mock_query = mock_col.where.return_value

            if collection_name == "location_history":
                mock_query.stream.return_value = location_docs
            elif collection_name == "notification_history":
                mock_query.stream.return_value = notification_docs
            elif collection_name == "schedules":
                mock_query.stream.return_value = schedule_docs

            return mock_col

        mock_collection.side_effect = mock_query_side_effect

        stats = await cleanup_service.get_cleanup_stats()

        assert stats["location_history_count"] == 3
        assert stats["notification_history_count"] == 2
        assert stats["expired_schedules_count"] == 1
        assert stats["total_cleanup_items"] == 6


@pytest.mark.asyncio
async def test_cleanup_expired_data_integration(cleanup_service):
    """期限切れデータ一括削除の統合テスト"""
    with patch.object(
        cleanup_service.location_service, "cleanup_old_locations", new_callable=AsyncMock
    ) as mock_location_cleanup, patch.object(
        cleanup_service.notification_service,
        "cleanup_old_notification_history",
        new_callable=AsyncMock,
    ) as mock_notification_cleanup, patch.object(
        cleanup_service, "cleanup_expired_schedules", new_callable=AsyncMock
    ) as mock_schedule_cleanup:

        mock_location_cleanup.return_value = 10
        mock_notification_cleanup.return_value = 5
        mock_schedule_cleanup.return_value = 2

        results = await cleanup_service.cleanup_expired_data()

        assert results["location_history"] == 10
        assert results["notification_history"] == 5
        assert results["expired_schedules"] == 2

        mock_location_cleanup.assert_called_once()
        mock_notification_cleanup.assert_called_once()
        mock_schedule_cleanup.assert_called_once()
