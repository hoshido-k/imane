"""
Firebaseに登録されている全ユーザーを確認するデバッグスクリプト
"""
import sys
import os

# プロジェクトルートをパスに追加
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app.core.firebase import get_firestore_client
from datetime import datetime

def list_all_users():
    """Firestoreに登録されている全ユーザーを表示"""
    db = get_firestore_client()

    users_ref = db.collection("users")
    users = users_ref.get()

    print("=" * 80)
    print("Firebaseに登録されているユーザー一覧")
    print("=" * 80)

    user_count = 0
    for user_doc in users:
        user_count += 1
        user_data = user_doc.to_dict()

        print(f"\n[ユーザー #{user_count}]")
        print(f"  UID: {user_data.get('uid')}")
        print(f"  Email: {user_data.get('email')}")
        print(f"  Display Name: {user_data.get('display_name')}")
        print(f"  Profile Image: {user_data.get('profile_image_url', 'なし')}")
        print(f"  作成日時: {user_data.get('created_at')}")
        print(f"  FCM Tokens: {len(user_data.get('fcm_tokens', []))}個")

        # 追加のフィールドを確認
        print(f"\n  全フィールド:")
        for key, value in user_data.items():
            if key not in ['uid', 'email', 'display_name', 'profile_image_url', 'created_at', 'fcm_tokens']:
                print(f"    - {key}: {value}")

    print("\n" + "=" * 80)
    print(f"合計: {user_count}人のユーザーが登録されています")
    print("=" * 80)

if __name__ == "__main__":
    list_all_users()
