"""
スケジュールの登録状況を確認するスクリプト
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from datetime import UTC, datetime

from app.core.firebase import get_firestore_client, initialize_firebase


def check_schedules():
    """全スケジュールの登録状況を確認"""
    print("=" * 60)
    print("スケジュール登録状況の確認")
    print("=" * 60)

    initialize_firebase()
    db = get_firestore_client()

    # 全スケジュールを取得
    schedules_ref = db.collection("schedules")
    schedules = list(schedules_ref.stream())

    if not schedules:
        print("\n❌ スケジュールが見つかりません")
        return

    print(f"\n見つかったスケジュール数: {len(schedules)}\n")

    now = datetime.now(UTC)

    for schedule_doc in schedules:
        schedule_data = schedule_doc.to_dict()
        schedule_id = schedule_data.get("id", "不明")
        user_id = schedule_data.get("user_id", "不明")
        destination_name = schedule_data.get("destination_name", "不明")
        status = schedule_data.get("status", "不明")
        notify_to_user_ids = schedule_data.get("notify_to_user_ids", [])
        notify_on_arrival = schedule_data.get("notify_on_arrival", False)
        start_time = schedule_data.get("start_time")
        end_time = schedule_data.get("end_time")

        print(f"📍 スケジュール: {destination_name}")
        print(f"   ID: {schedule_id}")
        print(f"   作成者: {user_id}")
        print(f"   ステータス: {status}")
        print(f"   到着通知: {'✅ 有効' if notify_on_arrival else '❌ 無効'}")
        print(f"   通知先: {len(notify_to_user_ids)}人")
        for uid in notify_to_user_ids:
            print(f"      - {uid}")

        if start_time and end_time:
            print(f"   予定時刻: {start_time} 〜 {end_time}")
            if end_time < now:
                print(f"   ⚠️  予定は終了しています（目安なので通知は送られます）")
        else:
            print(f"   予定時刻: 未設定")

        print()

    print("=" * 60)


if __name__ == "__main__":
    check_schedules()
