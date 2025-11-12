"""
ユーザー管理サービス
"""

import uuid
from typing import List, Optional

from google.cloud.firestore_v1 import FieldFilter

from app.core.firebase import get_firestore_client, get_storage_bucket
from app.schemas.user import UserInDB, UserUpdate
from app.utils.timezone import now_jst


class UserService:
    """ユーザー管理サービスクラス"""

    def __init__(self):
        self.db = get_firestore_client()

    async def check_username_availability(self, username: str) -> bool:
        """
        ユーザIDの利用可否をチェック

        Args:
            username: チェックするユーザID

        Returns:
            True: 利用可能、False: 既に使用されている
        """
        from google.cloud.firestore_v1 import FieldFilter

        existing_users = self.db.collection("users").where(
            filter=FieldFilter("username", "==", username)
        ).limit(1).get()

        # ユーザーが存在しない場合は利用可能
        return len(existing_users) == 0

    async def check_email_availability(self, email: str) -> bool:
        """
        メールアドレスの利用可否をチェック

        Args:
            email: チェックするメールアドレス

        Returns:
            True: 利用可能、False: 既に使用されている
        """
        from google.cloud.firestore_v1 import FieldFilter

        existing_users = self.db.collection("users").where(
            filter=FieldFilter("email", "==", email)
        ).limit(1).get()

        # ユーザーが存在しない場合は利用可能
        return len(existing_users) == 0

    async def search_users(
        self, query: str, current_user_id: str, limit: int = 20
    ) -> List[UserInDB]:
        """
        ユーザーをusernameで検索

        Args:
            query: 検索クエリ（username）
            current_user_id: 現在のユーザID（自分自身は除外）
            limit: 取得件数の上限

        Returns:
            検索結果のユーザーリスト
        """
        if not query or len(query.strip()) == 0:
            return []

        query = query.strip().lower()
        results = []

        # usernameで検索（部分一致）
        # Firestoreは部分一致検索をサポートしていないため、全件取得してフィルタリング
        # 本番環境ではAlgoliaやElasticsearchの使用を推奨
        try:
            users_ref = self.db.collection("users").limit(100)
            users = users_ref.get()

            for user_doc in users:
                try:
                    user_data = user_doc.to_dict()

                    # デバッグログ
                    print(f"[UserService] Processing user: {user_doc.id}")
                    print(f"[UserService] User data keys: {user_data.keys() if user_data else 'None'}")

                    # FirestoreのTimestampをdatetimeに変換
                    if "created_at" in user_data and hasattr(user_data["created_at"], "timestamp"):
                        from datetime import datetime
                        user_data["created_at"] = datetime.fromtimestamp(user_data["created_at"].timestamp())

                    if "updated_at" in user_data and hasattr(user_data["updated_at"], "timestamp"):
                        from datetime import datetime
                        user_data["updated_at"] = datetime.fromtimestamp(user_data["updated_at"].timestamp())

                    # UserInDBに変換
                    user = UserInDB(**user_data)

                    # 自分自身は除外
                    if user.uid == current_user_id:
                        continue

                    # usernameに検索クエリが含まれるか
                    username_match = query in user.username.lower() if user.username else False

                    if username_match:
                        results.append(user)

                    if len(results) >= limit:
                        break

                except Exception as e:
                    # 個別のユーザーデータのエラーはスキップ
                    print(f"[UserService] Error parsing user {user_doc.id}: {e}")
                    print(f"[UserService] User data: {user_data}")
                    continue

            return results

        except Exception as e:
            print(f"[UserService] Error in search_users: {e}")
            raise

    async def get_user_by_uid(self, uid: str) -> Optional[UserInDB]:
        """
        UIDからユーザー情報を取得

        Args:
            uid: ユーザID

        Returns:
            ユーザー情報、存在しない場合はNone
        """
        user_ref = self.db.collection("users").document(uid)
        user_doc = user_ref.get()

        if not user_doc.exists:
            return None

        user_data = user_doc.to_dict()

        # FirestoreのTimestampをdatetimeに変換
        if "created_at" in user_data and hasattr(user_data["created_at"], "timestamp"):
            from datetime import datetime
            user_data["created_at"] = datetime.fromtimestamp(user_data["created_at"].timestamp())

        if "updated_at" in user_data and hasattr(user_data["updated_at"], "timestamp"):
            from datetime import datetime
            user_data["updated_at"] = datetime.fromtimestamp(user_data["updated_at"].timestamp())

        # usernameが存在しない場合はエラー
        if "username" not in user_data or not user_data["username"]:
            print(f"[UserService] Error: User {uid} has no username")
            print(f"[UserService] User data: {user_data}")
            raise ValueError(
                f"User {uid} has incomplete data (missing username). "
                "Please delete this user from Firebase Console and re-register."
            )

        return UserInDB(**user_data)

    async def update_profile(self, uid: str, update_data: UserUpdate) -> UserInDB:
        """
        プロフィール情報を更新

        Args:
            uid: ユーザID
            update_data: 更新データ

        Returns:
            更新後のユーザー情報

        Raises:
            ValueError: ユーザーが見つからない場合、またはusernameが重複している場合
        """
        user_ref = self.db.collection("users").document(uid)
        user_doc = user_ref.get()

        if not user_doc.exists:
            raise ValueError("ユーザーが見つかりません")

        # username変更の場合は重複チェック
        if update_data.username is not None:
            from google.cloud.firestore_v1 import FieldFilter
            existing_users = self.db.collection("users").where(
                filter=FieldFilter("username", "==", update_data.username)
            ).limit(1).get()

            # 自分以外のユーザーが同じusernameを持っている場合はエラー
            for existing_user in existing_users:
                if existing_user.id != uid:
                    raise ValueError("このユーザIDは既に使用されています")

        # 更新データの準備（Noneでない値のみ）
        update_dict = update_data.model_dump(exclude_unset=True, exclude_none=True)
        update_dict["updated_at"] = now_jst()

        # Firestoreを更新
        user_ref.update(update_dict)

        # 更新後のユーザー情報を取得
        return await self.get_user_by_uid(uid)

    async def upload_profile_image(
        self, uid: str, image_data: bytes, content_type: str
    ) -> str:
        """
        プロフィール画像をFirebase Storageにアップロード

        Args:
            uid: ユーザID
            image_data: 画像データ（バイト列）
            content_type: ファイルのMIMEタイプ

        Returns:
            アップロードされた画像の公開URL

        Raises:
            ValueError: ユーザーが見つからない場合
        """
        # ユーザーの存在確認
        user = await self.get_user_by_uid(uid)
        if not user:
            raise ValueError("ユーザーが見つかりません")

        # ファイル拡張子の決定
        extension_map = {
            "image/jpeg": "jpg",
            "image/jpg": "jpg",
            "image/png": "png",
            "image/gif": "gif",
            "image/webp": "webp",
        }
        extension = extension_map.get(content_type, "jpg")

        # ファイル名を生成（ユーザIDとUUIDを使用）
        filename = f"profile_images/{uid}/{uuid.uuid4()}.{extension}"

        try:
            # Firebase Storageにアップロード
            bucket = get_storage_bucket()
            blob = bucket.blob(filename)

            # メタデータを設定
            blob.metadata = {
                "user_id": uid,
                "uploaded_at": now_jst().isoformat(),
            }

            # アップロード
            blob.upload_from_string(image_data, content_type=content_type)

            # 公開URLを取得するために公開設定
            blob.make_public()

            # 公開URLを取得
            public_url = blob.public_url

            # ユーザーのprofile_image_urlを更新
            user_ref = self.db.collection("users").document(uid)
            user_ref.update({
                "profile_image_url": public_url,
                "updated_at": now_jst()
            })

            return public_url

        except Exception as e:
            print(f"[UserService] Error uploading profile image: {e}")
            raise ValueError(f"画像のアップロードに失敗しました: {str(e)}")

    async def delete_profile_image(self, uid: str) -> None:
        """
        プロフィール画像を削除

        Args:
            uid: ユーザID

        Raises:
            ValueError: ユーザーが見つからない場合
        """
        # ユーザーの存在確認
        user = await self.get_user_by_uid(uid)
        if not user:
            raise ValueError("ユーザーが見つかりません")

        try:
            # Firebase Storageから画像を削除
            bucket = get_storage_bucket()
            blobs = bucket.list_blobs(prefix=f"profile_images/{uid}/")
            for blob in blobs:
                blob.delete()
                print(f"[UserService] Deleted profile image: {blob.name}")

            # ユーザーのprofile_image_urlをNullに設定
            user_ref = self.db.collection("users").document(uid)
            user_ref.update({
                "profile_image_url": None,
                "updated_at": now_jst()
            })

            print(f"[UserService] Profile image deleted for user: {uid}")

        except Exception as e:
            print(f"[UserService] Error deleting profile image: {e}")
            raise ValueError(f"プロフィール画像の削除に失敗しました: {str(e)}")

    async def delete_user(self, uid: str) -> None:
        """
        ユーザーアカウントとすべての関連データを削除

        Args:
            uid: ユーザID

        Raises:
            ValueError: ユーザーが見つからない場合
        """
        # ユーザーの存在確認
        user_ref = self.db.collection("users").document(uid)
        user_doc = user_ref.get()

        if not user_doc.exists:
            raise ValueError("ユーザーが見つかりません")

        try:
            print(f"[UserService] Deleting user account: {uid}")

            # 1. フレンド関係の削除
            # 自分から送ったフレンドリクエスト
            from_friends = self.db.collection("friends").where(
                filter=FieldFilter("from_user_id", "==", uid)
            ).stream()
            for friend_doc in from_friends:
                friend_doc.reference.delete()
                print(f"[UserService] Deleted friend relationship (from): {friend_doc.id}")

            # 自分宛に送られたフレンドリクエスト
            to_friends = self.db.collection("friends").where(
                filter=FieldFilter("to_user_id", "==", uid)
            ).stream()
            for friend_doc in to_friends:
                friend_doc.reference.delete()
                print(f"[UserService] Deleted friend relationship (to): {friend_doc.id}")

            # 2. スケジュールの削除
            schedules = self.db.collection("schedules").where(
                filter=FieldFilter("user_id", "==", uid)
            ).stream()
            for schedule_doc in schedules:
                schedule_doc.reference.delete()
                print(f"[UserService] Deleted schedule: {schedule_doc.id}")

            # 3. お気に入り位置の削除
            favorites = self.db.collection("favorites").where(
                filter=FieldFilter("user_id", "==", uid)
            ).stream()
            for favorite_doc in favorites:
                favorite_doc.reference.delete()
                print(f"[UserService] Deleted favorite: {favorite_doc.id}")

            # 4. 位置情報履歴の削除
            location_history = self.db.collection("location_history").where(
                filter=FieldFilter("user_id", "==", uid)
            ).stream()
            for location_doc in location_history:
                location_doc.reference.delete()
                print(f"[UserService] Deleted location history: {location_doc.id}")

            # 5. 通知履歴の削除（送信元）
            from_notifications = self.db.collection("notification_history").where(
                filter=FieldFilter("from_user_id", "==", uid)
            ).stream()
            for notification_doc in from_notifications:
                notification_doc.reference.delete()
                print(f"[UserService] Deleted notification (from): {notification_doc.id}")

            # 6. 通知履歴の削除（送信先）
            to_notifications = self.db.collection("notification_history").where(
                filter=FieldFilter("to_user_id", "==", uid)
            ).stream()
            for notification_doc in to_notifications:
                notification_doc.reference.delete()
                print(f"[UserService] Deleted notification (to): {notification_doc.id}")

            # 7. FCMトークンの削除
            fcm_tokens = self.db.collection("fcm_tokens").where(
                filter=FieldFilter("user_id", "==", uid)
            ).stream()
            for token_doc in fcm_tokens:
                token_doc.reference.delete()
                print(f"[UserService] Deleted FCM token: {token_doc.id}")

            # 8. ユーザードキュメントの削除
            user_ref.delete()
            print(f"[UserService] Deleted user document: {uid}")

            # 9. プロフィール画像の削除（Storage）
            try:
                bucket = get_storage_bucket()
                blobs = bucket.list_blobs(prefix=f"profile_images/{uid}/")
                for blob in blobs:
                    blob.delete()
                    print(f"[UserService] Deleted profile image: {blob.name}")
            except Exception as e:
                # ストレージの削除エラーは無視（ファイルが存在しない場合など）
                print(f"[UserService] Error deleting profile images: {e}")

            print(f"[UserService] User account deletion completed: {uid}")

        except Exception as e:
            print(f"[UserService] Error deleting user account: {e}")
            raise ValueError(f"アカウントの削除に失敗しました: {str(e)}")
