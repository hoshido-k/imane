"""
通知配信のテストスクリプト

このスクリプトは、フレンドが作成したスケジュールに基づいて、
通知が正しく配信されるかをテストします。

使い方:
1. Firebaseの認証情報を設定
2. スクリプトを実行して、テスト通知を送信
3. 通知履歴を確認

python backend/test_notification_delivery.py
"""

import asyncio
import sys
from pathlib import Path

# プロジェクトルートをPythonパスに追加
sys.path.insert(0, str(Path(__file__).parent))

from datetime import UTC, datetime, timedelta

from app.core.firebase import get_firestore_client, initialize_firebase
from app.schemas.common import Coordinates
from app.schemas.notification import NotificationType
from app.schemas.schedule import LocationScheduleInDB, ScheduleStatus
from app.services.auto_notification import AutoNotificationService
from app.services.notifications import NotificationService


async def test_notification_delivery():
    """通知配信をテストする"""
    print("=" * 60)
    print("通知配信テストを開始します")
    print("=" * 60)

    # Firebaseを初期化
    initialize_firebase()
    db = get_firestore_client()

    # テストユーザーを検索（実際のユーザーを使用）
    print("\n[1] ユーザーを検索しています...")
    users_ref = db.collection("users").limit(2)
    users = list(users_ref.stream())

    if len(users) < 2:
        print("❌ テストには2人以上のユーザーが必要です")
        return

    user1 = users[0].to_dict()
    user2 = users[1].to_dict()

    print(f"✓ ユーザー1: {user1['username']} (ID: {user1['uid']})")
    print(f"✓ ユーザー2: {user2['username']} (ID: {user2['uid']})")

    # FCMトークンの確認
    print("\n[2] FCMトークンを確認しています...")
    user1_tokens = user1.get("fcm_tokens", [])
    user2_tokens = user2.get("fcm_tokens", [])

    if user1_tokens:
        print(f"✓ ユーザー1のFCMトークン: {len(user1_tokens)}個")
    else:
        print(f"⚠ ユーザー1のFCMトークンが登録されていません")

    if user2_tokens:
        print(f"✓ ユーザー2のFCMトークン: {len(user2_tokens)}個")
    else:
        print(f"⚠ ユーザー2のFCMトークンが登録されていません")

    # テストスケジュールを検索
    print("\n[3] アクティブなスケジュールを検索しています...")
    schedules_ref = (
        db.collection("schedules")
        .where("status", "in", ["active", "arrived"])
        .limit(5)
    )
    schedules = list(schedules_ref.stream())

    if not schedules:
        print("⚠ アクティブなスケジュールが見つかりません")
        print("\nテストスケジュールを作成しますか？ (y/n): ", end="")
        # 自動的にテストスケジュールを作成
        print("y")
        schedule = await create_test_schedule(user1["uid"], user2["uid"])
    else:
        schedule_data = schedules[0].to_dict()
        schedule = LocationScheduleInDB(**schedule_data)
        print(f"✓ スケジュールを見つけました: {schedule.destination_name}")
        print(f"  作成者: {schedule.user_id}")
        print(f"  通知先: {schedule.notify_to_user_ids}")
        print(f"  ステータス: {schedule.status}")

    # 通知サービスを初期化
    notification_service = NotificationService()
    auto_notification_service = AutoNotificationService()

    # テスト1: 直接プッシュ通知を送信
    print("\n[4] テスト通知を送信しています...")
    test_user_id = schedule.notify_to_user_ids[0] if schedule.notify_to_user_ids else user2["uid"]

    try:
        await notification_service.send_push_notification(
            user_id=test_user_id,
            title="テスト通知",
            body="これはimaneからのテスト通知です。\n通知が正しく届いているか確認してください。",
            notification_type=NotificationType.MESSAGE,
            data={"test": "true"},
            save_to_db=True,
        )
        print(f"✓ テスト通知を送信しました (宛先: {test_user_id})")
    except Exception as e:
        print(f"❌ テスト通知の送信に失敗: {e}")

    # テスト2: 到着通知をシミュレート
    print("\n[5] 到着通知をシミュレートしています...")
    try:
        # スケジュールの目的地座標を使用
        test_coords = schedule.destination_coords

        notification_ids = await auto_notification_service.send_arrival_notification(
            schedule=schedule,
            current_coords=test_coords,
        )

        if notification_ids:
            print(f"✓ 到着通知を送信しました ({len(notification_ids)}件)")
            print(f"  通知ID: {notification_ids}")
        else:
            print(f"⚠ 到着通知が送信されませんでした")
            print(f"  原因: notify_on_arrival={schedule.notify_on_arrival}")

    except Exception as e:
        print(f"❌ 到着通知の送信に失敗: {e}")

    # 通知履歴を確認
    print("\n[6] 通知履歴を確認しています...")

    # notificationsコレクション
    print("\n  - notificationsコレクション:")
    notifications = await notification_service.get_user_notifications(
        test_user_id, limit=5
    )
    if notifications:
        for notif in notifications:
            print(f"    • {notif.title}: {notif.body[:50]}...")
            print(f"      作成日時: {notif.created_at}")
    else:
        print("    (通知なし)")

    # notification_historyコレクション
    print("\n  - notification_historyコレクション:")
    history_ref = (
        db.collection("notification_history")
        .where("to_user_id", "==", test_user_id)
        .order_by("sent_at", direction="DESCENDING")
        .limit(5)
    )
    histories = list(history_ref.stream())
    if histories:
        for hist in histories:
            hist_data = hist.to_dict()
            print(f"    • {hist_data['type']}: {hist_data['message'][:50]}...")
            print(f"      送信日時: {hist_data['sent_at']}")
    else:
        print("    (通知履歴なし)")

    print("\n" + "=" * 60)
    print("テスト完了")
    print("=" * 60)
    print("\n【確認事項】")
    print("1. FCMトークンが登録されているか")
    print("2. モバイルアプリで通知を受信できたか")
    print("3. 通知履歴が保存されているか")
    print("\n【トラブルシューティング】")
    print("• FCMトークンが未登録の場合:")
    print("  → モバイルアプリでログインして、FCMトークンを登録してください")
    print("• 通知が届かない場合:")
    print("  → FCMの設定、iOS通知許可、バックグラウンド実行を確認してください")


async def create_test_schedule(user_id: str, notify_to_user_id: str) -> LocationScheduleInDB:
    """テスト用のスケジュールを作成"""
    print("\n  テストスケジュールを作成しています...")

    db = get_firestore_client()

    # 東京駅を目的地として設定
    tokyo_station = Coordinates(lat=35.681236, lng=139.767125)

    now = datetime.now(UTC)
    schedule_data = {
        "id": f"test-schedule-{now.timestamp()}",
        "user_id": user_id,
        "destination_name": "東京駅（テスト）",
        "destination_address": "東京都千代田区丸の内1丁目",
        "destination_coords": {"lat": tokyo_station.lat, "lng": tokyo_station.lng},
        "geofence_radius": 50,
        "notify_to_user_ids": [notify_to_user_id],
        "start_time": now - timedelta(hours=1),
        "end_time": now + timedelta(hours=2),
        "recurrence": None,
        "notify_on_arrival": True,
        "notify_after_minutes": 60,
        "notify_on_departure": True,
        "status": ScheduleStatus.ACTIVE.value,
        "arrived_at": None,
        "departed_at": None,
        "favorite": False,
        "created_at": now,
        "updated_at": now,
    }

    # Firestoreに保存
    schedule_ref = db.collection("schedules").document(schedule_data["id"])
    schedule_ref.set(schedule_data)

    print(f"  ✓ テストスケジュールを作成しました: {schedule_data['id']}")

    # LocationScheduleInDBオブジェクトに変換
    schedule_data["destination_coords"] = tokyo_station
    schedule_data["status"] = ScheduleStatus.ACTIVE

    return LocationScheduleInDB(**schedule_data)


if __name__ == "__main__":
    asyncio.run(test_notification_delivery())
