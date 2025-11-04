"""
自動通知サービスのテスト
"""

import pytest
from datetime import UTC, datetime, timedelta
from unittest.mock import AsyncMock, MagicMock, patch

from app.schemas.common import Coordinates
from app.schemas.schedule import LocationScheduleInDB, ScheduleStatus
from app.services.auto_notification import AutoNotificationService


@pytest.fixture
def auto_notification_service():
    """自動通知サービスのフィクスチャ"""
    return AutoNotificationService()


@pytest.fixture
def sample_schedule():
    """サンプルスケジュール"""
    now = datetime.now(UTC)
    return LocationScheduleInDB(
        id="schedule_123",
        user_id="user_123",
        destination_name="渋谷駅",
        destination_address="東京都渋谷区",
        destination_coords=Coordinates(lat=35.6580, lng=139.7016),
        geofence_radius=50,
        notify_to_user_ids=["friend_1", "friend_2"],
        start_time=now - timedelta(hours=1),
        end_time=now + timedelta(hours=3),
        recurrence=None,
        notify_on_arrival=True,
        notify_after_minutes=60,
        notify_on_departure=True,
        status=ScheduleStatus.ACTIVE,
        arrived_at=None,
        departed_at=None,
        favorite=False,
        created_at=now,
        updated_at=now,
    )


@pytest.fixture
def sample_user():
    """サンプルユーザー"""
    from app.schemas.user import UserInDB

    return UserInDB(
        uid="user_123",
        email="test@example.com",
        username="testuser",
        display_name="テストユーザー",
        fcm_tokens=["fcm_token_123"],
        created_at=datetime.now(UTC),
        updated_at=datetime.now(UTC),
    )


def test_generate_map_link(auto_notification_service):
    """地図リンク生成のテスト"""
    coords = Coordinates(lat=35.6580, lng=139.7016)

    map_link = auto_notification_service._generate_map_link(coords)

    assert "https://www.google.com/maps?q=" in map_link
    assert "35.658" in map_link
    assert "139.7016" in map_link


def test_format_arrival_message(auto_notification_service):
    """到着メッセージフォーマットのテスト"""
    message = auto_notification_service._format_arrival_message("田中太郎", "渋谷駅")

    assert "今ね、" in message
    assert "田中太郎" in message
    assert "渋谷駅" in message
    assert "到着" in message
    assert "到着時刻:" in message


def test_format_stay_message_hours_and_minutes(auto_notification_service):
    """滞在メッセージフォーマットのテスト（時間+分）"""
    message = auto_notification_service._format_stay_message("田中太郎", "渋谷駅", 90)

    assert "今ね、" in message
    assert "田中太郎" in message
    assert "渋谷駅" in message
    assert "1時間30分" in message
    assert "滞在" in message


def test_format_stay_message_minutes_only(auto_notification_service):
    """滞在メッセージフォーマットのテスト（分のみ）"""
    message = auto_notification_service._format_stay_message("田中太郎", "渋谷駅", 45)

    assert "今ね、" in message
    assert "45分" in message


def test_format_stay_message_hours_only(auto_notification_service):
    """滞在メッセージフォーマットのテスト（時間のみ）"""
    message = auto_notification_service._format_stay_message("田中太郎", "渋谷駅", 120)

    assert "今ね、" in message
    assert "2時間" in message


def test_format_departure_message(auto_notification_service):
    """退出メッセージフォーマットのテスト"""
    message = auto_notification_service._format_departure_message("田中太郎", "渋谷駅")

    assert "今ね、" in message
    assert "田中太郎" in message
    assert "渋谷駅" in message
    assert "出発" in message
    assert "出発時刻:" in message


@pytest.mark.asyncio
async def test_send_arrival_notification(auto_notification_service, sample_schedule, sample_user):
    """到着通知送信のテスト"""
    current_coords = Coordinates(lat=35.6580, lng=139.7016)

    with patch.object(
        auto_notification_service.user_service, "get_user_by_uid", new_callable=AsyncMock
    ) as mock_get_user, patch.object(
        auto_notification_service.notification_service,
        "send_push_notification",
        new_callable=AsyncMock,
    ) as mock_send_push, patch.object(
        auto_notification_service.db, "collection", return_value=MagicMock()
    ):

        mock_get_user.return_value = sample_user

        notification_ids = await auto_notification_service.send_arrival_notification(
            sample_schedule, current_coords
        )

        # 通知先が2人なので2回呼ばれる
        assert mock_send_push.call_count == 2
        assert len(notification_ids) == 2

        # 呼び出しの引数を確認
        call_args = mock_send_push.call_args_list[0]
        assert call_args.kwargs["title"] == "テストユーザーさんが到着"
        assert "今ね、" in call_args.kwargs["body"]
        assert "渋谷駅" in call_args.kwargs["body"]


@pytest.mark.asyncio
async def test_send_arrival_notification_disabled(
    auto_notification_service, sample_schedule, sample_user
):
    """到着通知が無効な場合のテスト"""
    sample_schedule.notify_on_arrival = False
    current_coords = Coordinates(lat=35.6580, lng=139.7016)

    notification_ids = await auto_notification_service.send_arrival_notification(
        sample_schedule, current_coords
    )

    assert len(notification_ids) == 0


@pytest.mark.asyncio
async def test_send_departure_notification(
    auto_notification_service, sample_schedule, sample_user
):
    """退出通知送信のテスト"""
    current_coords = Coordinates(lat=35.6500, lng=139.7000)

    with patch.object(
        auto_notification_service.user_service, "get_user_by_uid", new_callable=AsyncMock
    ) as mock_get_user, patch.object(
        auto_notification_service.notification_service,
        "send_push_notification",
        new_callable=AsyncMock,
    ) as mock_send_push, patch.object(
        auto_notification_service.db, "collection", return_value=MagicMock()
    ):

        mock_get_user.return_value = sample_user

        notification_ids = await auto_notification_service.send_departure_notification(
            sample_schedule, current_coords
        )

        # 通知先が2人なので2回呼ばれる
        assert mock_send_push.call_count == 2
        assert len(notification_ids) == 2

        # 呼び出しの引数を確認
        call_args = mock_send_push.call_args_list[0]
        assert call_args.kwargs["title"] == "テストユーザーさんが出発"
        assert "今ね、" in call_args.kwargs["body"]
        assert "出発" in call_args.kwargs["body"]


@pytest.mark.asyncio
async def test_send_departure_notification_disabled(
    auto_notification_service, sample_schedule, sample_user
):
    """退出通知が無効な場合のテスト"""
    sample_schedule.notify_on_departure = False
    current_coords = Coordinates(lat=35.6500, lng=139.7000)

    notification_ids = await auto_notification_service.send_departure_notification(
        sample_schedule, current_coords
    )

    assert len(notification_ids) == 0


@pytest.mark.asyncio
async def test_send_stay_notification(auto_notification_service, sample_schedule, sample_user):
    """滞在通知送信のテスト"""
    # 到着から60分経過した状態を設定
    sample_schedule.arrived_at = datetime.now(UTC) - timedelta(minutes=60)
    current_coords = Coordinates(lat=35.6580, lng=139.7016)

    with patch.object(
        auto_notification_service.user_service, "get_user_by_uid", new_callable=AsyncMock
    ) as mock_get_user, patch.object(
        auto_notification_service.notification_service,
        "send_push_notification",
        new_callable=AsyncMock,
    ) as mock_send_push, patch.object(
        auto_notification_service.db, "collection", return_value=MagicMock()
    ):

        mock_get_user.return_value = sample_user

        notification_ids = await auto_notification_service.send_stay_notification(
            sample_schedule, current_coords
        )

        # 通知先が2人なので2回呼ばれる
        assert mock_send_push.call_count == 2
        assert len(notification_ids) == 2

        # 呼び出しの引数を確認
        call_args = mock_send_push.call_args_list[0]
        assert call_args.kwargs["title"] == "テストユーザーさんが滞在中"
        assert "今ね、" in call_args.kwargs["body"]
        assert "滞在" in call_args.kwargs["body"]


@pytest.mark.asyncio
async def test_send_stay_notification_insufficient_duration(
    auto_notification_service, sample_schedule, sample_user
):
    """滞在時間が不足している場合のテスト"""
    # 到着から30分しか経過していない
    sample_schedule.arrived_at = datetime.now(UTC) - timedelta(minutes=30)
    current_coords = Coordinates(lat=35.6580, lng=139.7016)

    with patch.object(
        auto_notification_service.user_service, "get_user_by_uid", new_callable=AsyncMock
    ) as mock_get_user:

        mock_get_user.return_value = sample_user

        notification_ids = await auto_notification_service.send_stay_notification(
            sample_schedule, current_coords
        )

        # 滞在時間が不足しているので通知されない
        assert len(notification_ids) == 0


@pytest.mark.asyncio
async def test_send_stay_notification_no_arrival_time(
    auto_notification_service, sample_schedule, sample_user
):
    """到着時刻が記録されていない場合のテスト"""
    sample_schedule.arrived_at = None
    current_coords = Coordinates(lat=35.6580, lng=139.7016)

    notification_ids = await auto_notification_service.send_stay_notification(
        sample_schedule, current_coords
    )

    # 到着時刻がないので通知されない
    assert len(notification_ids) == 0


@pytest.mark.asyncio
async def test_save_notification_history(auto_notification_service):
    """通知履歴保存のテスト"""
    mock_doc_ref = MagicMock()
    mock_collection = MagicMock()
    mock_collection.document.return_value = mock_doc_ref

    with patch.object(
        auto_notification_service.db, "collection", return_value=mock_collection
    ):

        history = await auto_notification_service._save_notification_history(
            from_user_id="user_123",
            to_user_id="friend_1",
            schedule_id="schedule_123",
            notification_type="arrival",
            message="今ね、テストユーザーさんが渋谷駅へ到着したよ",
            map_link="https://www.google.com/maps?q=35.658,139.7016",
        )

        # Firestoreへの保存が呼ばれたことを確認
        mock_doc_ref.set.assert_called_once()

        # 保存されたデータを確認
        saved_data = mock_doc_ref.set.call_args[0][0]
        assert saved_data["from_user_id"] == "user_123"
        assert saved_data["to_user_id"] == "friend_1"
        assert saved_data["schedule_id"] == "schedule_123"
        assert saved_data["type"] == "arrival"
        assert "auto_delete_at" in saved_data  # 24時間TTLが設定されている
