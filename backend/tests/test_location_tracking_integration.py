"""
位置情報トラッキング・ジオフェンシングの統合テスト

実際のFirestoreに接続して、位置情報更新からジオフェンス検出、
自動通知送信までの一連のフローをテストします。
"""

import pytest
from datetime import UTC, datetime, timedelta
from unittest.mock import AsyncMock, patch

from app.schemas.location import Coordinates, LocationUpdateRequest
from app.schemas.schedule import (
    LocationScheduleCreate,
    LocationScheduleInDB,
    ScheduleStatus,
)
from app.schemas.user import UserInDB
from app.services.geofencing import GeofencingService
from app.services.location import LocationService
from app.services.schedules import ScheduleService


@pytest.fixture
def location_service():
    """位置情報サービスのフィクスチャ"""
    return LocationService()


@pytest.fixture
def geofencing_service():
    """ジオフェンシングサービスのフィクスチャ"""
    return GeofencingService()


@pytest.fixture
def schedule_service():
    """スケジュールサービスのフィクスチャ"""
    return ScheduleService()


@pytest.fixture
def test_user():
    """テストユーザー"""
    return UserInDB(
        uid="integration_test_user_123",
        email="integration_test@example.com",
        username="integration_testuser",
        display_name="統合テストユーザー",
        fcm_tokens=["test_fcm_token"],
        created_at=datetime.now(UTC),
        updated_at=datetime.now(UTC),
    )


@pytest.fixture
def test_schedule_data():
    """テストスケジュールデータ"""
    now = datetime.now(UTC)
    return LocationScheduleCreate(
        destination_name="テスト目的地",
        destination_address="東京都渋谷区テスト町1-2-3",
        destination_coords=Coordinates(lat=35.6580, lng=139.7016),
        geofence_radius=50,
        notify_to_user_ids=["friend_test_123"],
        start_time=now - timedelta(hours=1),
        end_time=now + timedelta(hours=3),
        recurrence=None,
        notify_on_arrival=True,
        notify_after_minutes=60,
        notify_on_departure=True,
        favorite=False,
    )


@pytest.mark.asyncio
async def test_location_recording(location_service, test_user):
    """位置情報記録のテスト"""
    location_data = LocationUpdateRequest(
        coords=Coordinates(lat=35.6580, lng=139.7016),
        accuracy=10.0,
        recorded_at=datetime.now(UTC),
    )

    # 位置情報を記録
    location_history = await location_service.record_location(
        test_user.uid, location_data
    )

    assert location_history is not None
    assert location_history.user_id == test_user.uid
    assert location_history.coords.lat == 35.6580
    assert location_history.coords.lng == 139.7016

    # クリーンアップ
    await location_service.db.collection("location_history").document(
        location_history.id
    ).delete()


@pytest.mark.asyncio
async def test_schedule_creation_and_geofence_detection(
    schedule_service, geofencing_service, test_user, test_schedule_data
):
    """スケジュール作成とジオフェンス検出のテスト"""
    # スケジュールを作成
    schedule = await schedule_service.create_schedule(test_user.uid, test_schedule_data)

    assert schedule is not None
    assert schedule.user_id == test_user.uid
    assert schedule.status == ScheduleStatus.ACTIVE

    try:
        # 目的地の座標（ジオフェンス内）
        inside_coords = Coordinates(lat=35.6580, lng=139.7016)
        # ジオフェンス外の座標
        outside_coords = Coordinates(lat=35.6500, lng=139.7000)

        # ジオフェンス外 → 内への移動をシミュレート
        events = await geofencing_service.process_location_update(
            user_id=test_user.uid,
            current_coords=inside_coords,
            previous_coords=outside_coords,
        )

        # 到着イベントが検出されるはず
        assert len(events) > 0
        assert events[0].event_type == "entry"
        assert events[0].schedule.id == schedule.id

        # スケジュールステータスがARRIVEDに更新されているはず
        updated_schedule = await schedule_service.get_schedule_by_id(schedule.id, test_user.uid)
        assert updated_schedule.status == ScheduleStatus.ARRIVED
        assert updated_schedule.arrived_at is not None

        # ジオフェンス内 → 外への移動をシミュレート（退出）
        exit_events = await geofencing_service.process_location_update(
            user_id=test_user.uid,
            current_coords=outside_coords,
            previous_coords=inside_coords,
        )

        # 退出イベントが検出されるはず
        assert len(exit_events) > 0
        assert exit_events[0].event_type == "exit"

        # スケジュールステータスがCOMPLETEDに更新されているはず
        final_schedule = await schedule_service.get_schedule_by_id(schedule.id, test_user.uid)
        assert final_schedule.status == ScheduleStatus.COMPLETED
        assert final_schedule.departed_at is not None

    finally:
        # クリーンアップ
        await schedule_service.delete_schedule(schedule.id, test_user.uid)


@pytest.mark.asyncio
async def test_location_update_with_notification(
    location_service, schedule_service, test_user, test_schedule_data
):
    """位置情報更新と通知送信の統合テスト"""
    from app.services.auto_notification import AutoNotificationService
    from app.services.geofencing import GeofencingService

    # モックでユーザーサービスと通知サービスをセットアップ
    with patch(
        "app.services.auto_notification.UserService"
    ) as MockUserService, patch(
        "app.services.auto_notification.NotificationService"
    ) as MockNotificationService:

        mock_user_service_instance = MockUserService.return_value
        mock_user_service_instance.get_user_by_uid = AsyncMock(return_value=test_user)

        mock_notification_service_instance = MockNotificationService.return_value
        mock_notification_service_instance.send_push_notification = AsyncMock()

        # スケジュールを作成
        schedule = await schedule_service.create_schedule(test_user.uid, test_schedule_data)

        try:
            # 位置情報を記録（ジオフェンス外）
            outside_location = LocationUpdateRequest(
                coords=Coordinates(lat=35.6500, lng=139.7000),
                accuracy=10.0,
            )
            await location_service.record_location(test_user.uid, outside_location)

            # 位置情報を更新（ジオフェンス内に入る）
            inside_location = LocationUpdateRequest(
                coords=Coordinates(lat=35.6580, lng=139.7016),
                accuracy=10.0,
            )
            await location_service.record_location(test_user.uid, inside_location)

            # ジオフェンスチェック
            geofencing_service = GeofencingService()
            events = await geofencing_service.process_location_update(
                user_id=test_user.uid,
                current_coords=inside_location.coords,
                previous_coords=outside_location.coords,
            )

            # 到着イベントが検出される
            assert len(events) > 0
            assert events[0].event_type == "entry"

            # 自動通知サービスで通知を送信
            auto_notification_service = AutoNotificationService()

            # 通知履歴の保存をモック
            with patch.object(
                auto_notification_service.db, "collection"
            ) as mock_collection:
                mock_doc_ref = mock_collection.return_value.document.return_value
                mock_doc_ref.set = AsyncMock()

                notification_ids = await auto_notification_service.send_arrival_notification(
                    schedule=events[0].schedule,
                    current_coords=inside_location.coords,
                )

                # 通知が送信される（モック）
                assert (
                    mock_notification_service_instance.send_push_notification.call_count
                    == len(schedule.notify_to_user_ids)
                )

        finally:
            # クリーンアップ
            await schedule_service.delete_schedule(schedule.id, test_user.uid)

            # 位置情報履歴のクリーンアップ
            location_histories = await location_service.get_location_history(test_user.uid)
            for history in location_histories:
                await location_service.db.collection("location_history").document(
                    history.id
                ).delete()


@pytest.mark.asyncio
async def test_distance_calculation_accuracy(geofencing_service):
    """距離計算の精度テスト"""
    # 東京駅
    tokyo_station = Coordinates(lat=35.6812, lng=139.7671)
    # 渋谷駅（約6.5km）
    shibuya_station = Coordinates(lat=35.6580, lng=139.7016)
    # 新宿駅（東京駅から約7.5km）
    shinjuku_station = Coordinates(lat=35.6896, lng=139.7006)

    # 東京駅 - 渋谷駅
    distance_tokyo_shibuya = geofencing_service._calculate_distance(
        tokyo_station, shibuya_station
    )
    assert 6000 <= distance_tokyo_shibuya <= 7000

    # 東京駅 - 新宿駅
    distance_tokyo_shinjuku = geofencing_service._calculate_distance(
        tokyo_station, shinjuku_station
    )
    assert 7000 <= distance_tokyo_shinjuku <= 8000

    # 渋谷駅 - 新宿駅（約3.5km）
    distance_shibuya_shinjuku = geofencing_service._calculate_distance(
        shibuya_station, shinjuku_station
    )
    assert 3000 <= distance_shibuya_shinjuku <= 4000


@pytest.mark.asyncio
async def test_multiple_schedules_geofence(
    schedule_service, geofencing_service, test_user, test_schedule_data
):
    """複数スケジュールのジオフェンス処理テスト"""
    # 2つのスケジュールを作成（異なる目的地）
    schedule1_data = test_schedule_data.model_copy()
    schedule1_data.destination_name = "目的地A"
    schedule1_data.destination_coords = Coordinates(lat=35.6580, lng=139.7016)

    schedule2_data = test_schedule_data.model_copy()
    schedule2_data.destination_name = "目的地B"
    schedule2_data.destination_coords = Coordinates(lat=35.6590, lng=139.7026)

    schedule1 = await schedule_service.create_schedule(test_user.uid, schedule1_data)
    schedule2 = await schedule_service.create_schedule(test_user.uid, schedule2_data)

    try:
        # 目的地Aのジオフェンス内
        coords_a = Coordinates(lat=35.6580, lng=139.7016)

        events = await geofencing_service.process_location_update(
            user_id=test_user.uid, current_coords=coords_a, previous_coords=None
        )

        # 目的地Aの到着イベントのみ検出されるはず
        arrival_events = [e for e in events if e.event_type == "entry"]
        assert len(arrival_events) == 1
        assert arrival_events[0].schedule.destination_name == "目的地A"

    finally:
        # クリーンアップ
        await schedule_service.delete_schedule(schedule1.id, test_user.uid)
        await schedule_service.delete_schedule(schedule2.id, test_user.uid)
