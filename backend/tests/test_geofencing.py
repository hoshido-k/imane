"""
ジオフェンシングサービスのテスト
"""

import pytest
from datetime import UTC, datetime, timedelta
from unittest.mock import AsyncMock, MagicMock, patch

from app.schemas.location import Coordinates
from app.schemas.schedule import LocationScheduleInDB, ScheduleStatus
from app.services.geofencing import GeofencingService


@pytest.fixture
def geofencing_service():
    """ジオフェンシングサービスのフィクスチャ"""
    return GeofencingService()


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


def test_calculate_distance(geofencing_service):
    """距離計算のテスト"""
    # 東京駅 -> 渋谷駅の距離（約6.5km）
    tokyo_station = Coordinates(lat=35.6812, lng=139.7671)
    shibuya_station = Coordinates(lat=35.6580, lng=139.7016)

    distance = geofencing_service._calculate_distance(tokyo_station, shibuya_station)

    # 約6500メートル（誤差±500m）
    assert 6000 <= distance <= 7000


def test_calculate_distance_same_point(geofencing_service):
    """同一地点の距離計算テスト"""
    coords = Coordinates(lat=35.6580, lng=139.7016)

    distance = geofencing_service._calculate_distance(coords, coords)

    assert distance == 0.0


@pytest.mark.asyncio
async def test_check_geofence_entry_inside(geofencing_service, sample_schedule):
    """ジオフェンス内への侵入判定テスト"""
    # 目的地の座標（ジオフェンス内）
    current_coords = Coordinates(lat=35.6580, lng=139.7016)
    # ジオフェンス外の前回の座標
    previous_coords = Coordinates(lat=35.6500, lng=139.7000)

    is_entry, distance = await geofencing_service.check_geofence_entry(
        sample_schedule, current_coords, previous_coords
    )

    assert is_entry is True
    assert distance <= 50  # ジオフェンス半径内


@pytest.mark.asyncio
async def test_check_geofence_entry_outside(geofencing_service, sample_schedule):
    """ジオフェンス外の場合の侵入判定テスト"""
    # ジオフェンス外の座標（約800m離れた場所）
    current_coords = Coordinates(lat=35.6500, lng=139.7000)
    previous_coords = Coordinates(lat=35.6450, lng=139.6950)

    is_entry, distance = await geofencing_service.check_geofence_entry(
        sample_schedule, current_coords, previous_coords
    )

    assert is_entry is False
    assert distance > 50  # ジオフェンス半径外


@pytest.mark.asyncio
async def test_check_geofence_entry_already_arrived(geofencing_service, sample_schedule):
    """既に到着済みの場合の侵入判定テスト"""
    sample_schedule.status = ScheduleStatus.ARRIVED
    current_coords = Coordinates(lat=35.6580, lng=139.7016)

    is_entry, distance = await geofencing_service.check_geofence_entry(
        sample_schedule, current_coords, None
    )

    assert is_entry is False  # 既に到着済みなので侵入イベントとしない


@pytest.mark.asyncio
async def test_check_geofence_exit_outside(geofencing_service, sample_schedule):
    """ジオフェンスからの退出判定テスト"""
    # 到着済みステータスに設定
    sample_schedule.status = ScheduleStatus.ARRIVED

    # ジオフェンス外の現在座標
    current_coords = Coordinates(lat=35.6500, lng=139.7000)
    # ジオフェンス内の前回座標
    previous_coords = Coordinates(lat=35.6580, lng=139.7016)

    is_exit, distance = await geofencing_service.check_geofence_exit(
        sample_schedule, current_coords, previous_coords
    )

    assert is_exit is True
    assert distance > 50  # ジオフェンス半径外


@pytest.mark.asyncio
async def test_check_geofence_exit_not_arrived(geofencing_service, sample_schedule):
    """到着していない場合の退出判定テスト"""
    # ACTIVEステータスのまま
    sample_schedule.status = ScheduleStatus.ACTIVE
    current_coords = Coordinates(lat=35.6500, lng=139.7000)
    previous_coords = Coordinates(lat=35.6580, lng=139.7016)

    is_exit, distance = await geofencing_service.check_geofence_exit(
        sample_schedule, current_coords, previous_coords
    )

    assert is_exit is False  # 到着していないので退出イベントとしない


@pytest.mark.asyncio
async def test_process_location_update_entry(geofencing_service, sample_schedule):
    """位置情報更新時のジオフェンス侵入処理テスト"""
    # モックでスケジュールサービスをセットアップ
    with patch.object(
        geofencing_service.schedule_service, "get_schedules_by_user", new_callable=AsyncMock
    ) as mock_get_schedules, patch.object(
        geofencing_service.schedule_service, "update_schedule_status", new_callable=AsyncMock
    ) as mock_update_status:

        # ACTIVEスケジュールとして返す
        mock_get_schedules.side_effect = lambda user_id, status: (
            [sample_schedule] if status == ScheduleStatus.ACTIVE else []
        )

        # ジオフェンス内の座標
        current_coords = Coordinates(lat=35.6580, lng=139.7016)
        previous_coords = None  # 初回記録

        events = await geofencing_service.process_location_update(
            user_id="user_123", current_coords=current_coords, previous_coords=previous_coords
        )

        assert len(events) == 1
        assert events[0].event_type == "entry"
        assert events[0].schedule.id == "schedule_123"

        # ステータス更新が呼ばれたことを確認
        mock_update_status.assert_called_once()


@pytest.mark.asyncio
async def test_process_location_update_exit(geofencing_service, sample_schedule):
    """位置情報更新時のジオフェンス退出処理テスト"""
    # 到着済みステータスに設定
    sample_schedule.status = ScheduleStatus.ARRIVED

    with patch.object(
        geofencing_service.schedule_service, "get_schedules_by_user", new_callable=AsyncMock
    ) as mock_get_schedules, patch.object(
        geofencing_service.schedule_service, "update_schedule_status", new_callable=AsyncMock
    ) as mock_update_status:

        # ARRIVEDスケジュールとして返す
        mock_get_schedules.side_effect = lambda user_id, status: (
            [sample_schedule] if status == ScheduleStatus.ARRIVED else []
        )

        # ジオフェンス外の座標
        current_coords = Coordinates(lat=35.6500, lng=139.7000)
        # ジオフェンス内の前回座標
        previous_coords = Coordinates(lat=35.6580, lng=139.7016)

        events = await geofencing_service.process_location_update(
            user_id="user_123", current_coords=current_coords, previous_coords=previous_coords
        )

        assert len(events) == 1
        assert events[0].event_type == "exit"
        assert events[0].schedule.id == "schedule_123"

        # ステータス更新が呼ばれたことを確認
        mock_update_status.assert_called_once()


@pytest.mark.asyncio
async def test_get_nearby_schedules(geofencing_service, sample_schedule):
    """近くのスケジュール取得テスト"""
    with patch.object(
        geofencing_service.schedule_service, "get_schedules_by_user", new_callable=AsyncMock
    ) as mock_get_schedules:

        mock_get_schedules.return_value = [sample_schedule]

        # 目的地から約100m離れた座標
        current_coords = Coordinates(lat=35.6590, lng=139.7016)

        nearby = await geofencing_service.get_nearby_schedules(
            user_id="user_123", current_coords=current_coords, radius_meters=200
        )

        assert len(nearby) == 1
        assert nearby[0][0].id == "schedule_123"
        assert nearby[0][1] <= 200  # 200m以内
