"""
ユーザーのFCMトークン登録状況を確認するスクリプト
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from app.core.firebase import get_firestore_client, initialize_firebase


def check_fcm_tokens():
    """全ユーザーのFCMトークン登録状況を確認"""
    print("=" * 60)
    print("FCMトークン登録状況の確認")
    print("=" * 60)

    initialize_firebase()
    db = get_firestore_client()

    # 全ユーザーを取得
    users_ref = db.collection("users")
    users = list(users_ref.stream())

    if not users:
        print("\n❌ ユーザーが見つかりません")
        return

    print(f"\n見つかったユーザー数: {len(users)}\n")

    for user_doc in users:
        user_data = user_doc.to_dict()
        user_id = user_data.get("uid", "不明")
        username = user_data.get("username", "不明")
        email = user_data.get("email", "不明")
        fcm_tokens = user_data.get("fcm_tokens", [])

        print(f"📱 ユーザー: {username} ({email})")
        print(f"   UID: {user_id}")

        if fcm_tokens and len(fcm_tokens) > 0:
            print(f"   ✅ FCMトークン: {len(fcm_tokens)}個登録済み")
            for i, token in enumerate(fcm_tokens, 1):
                print(f"      {i}. {token[:50]}...")
        else:
            print(f"   ❌ FCMトークン: 未登録")

        print()

    print("=" * 60)
    print("\n【対処方法】")
    print("FCMトークンが未登録の場合:")
    print("1. モバイルアプリでログインしてください")
    print("2. または、以下のAPIで手動登録:")
    print("   POST /api/v1/notifications/fcm-token")
    print("   Body: {\"fcm_token\": \"your-token\"}")


if __name__ == "__main__":
    check_fcm_tokens()
