"""
認証サービス - Firebase Authentication + Firestore連携
"""

from datetime import datetime
from typing import Optional

from firebase_admin import auth, firestore
from firebase_admin.exceptions import FirebaseError

from app.core.firebase import get_auth_client, get_firestore_client
from app.utils.timezone import now_jst
from app.schemas.auth import SignupRequest, TokenResponse
from app.schemas.user import UserInDB
from app.utils.jwt import create_access_token, get_token_expire_time


class AuthService:
    """認証サービスクラス"""

    def __init__(self):
        self.db = get_firestore_client()
        self.auth_client = get_auth_client()

    async def signup(self, request: SignupRequest) -> TokenResponse:
        """
        新規ユーザー登録

        Args:
            request: 登録リクエスト

        Returns:
            アクセストークンとユーザー情報

        Raises:
            ValueError: メールアドレスまたはユーザIDが既に使用されている場合
            FirebaseError: Firebase関連のエラー
        """
        try:
            # 1. ユーザID（username）の重複チェック
            from google.cloud.firestore_v1 import FieldFilter
            existing_users = self.db.collection('users').where(
                filter=FieldFilter("username", "==", request.username)
            ).limit(1).get()

            if len(existing_users) > 0:
                raise ValueError("このユーザIDは既に使用されています")

            # 2. Firebase Authenticationでユーザー作成
            user_record = self.auth_client.create_user(
                email=request.email,
                password=request.password,
                display_name=request.display_name
            )

            # 3. Firestoreにユーザー情報を保存
            user_data = UserInDB(
                uid=user_record.uid,
                username=request.username,
                email=request.email,
                display_name=request.display_name,
                created_at=now_jst(),
                updated_at=now_jst()
            )

            user_ref = self.db.collection('users').document(user_record.uid)
            user_ref.set(user_data.model_dump(mode='json'))

            # 4. JWTトークンを生成
            access_token = create_access_token(
                data={"uid": user_record.uid, "email": request.email}
            )

            return TokenResponse(
                access_token=access_token,
                token_type="bearer",
                expires_in=get_token_expire_time(),
                uid=user_record.uid
            )

        except auth.EmailAlreadyExistsError:
            raise ValueError("このメールアドレスは既に使用されています")
        except FirebaseError as e:
            raise ValueError(f"ユーザー登録に失敗しました: {str(e)}")

    async def login_with_firebase_token(self, id_token: str) -> TokenResponse:
        """
        Firebase IDトークンでログイン

        Args:
            id_token: Firebase ID Token

        Returns:
            アクセストークン

        Raises:
            ValueError: トークンが無効な場合
        """
        try:
            # Firebase IDトークンを検証
            decoded_token = self.auth_client.verify_id_token(id_token)
            uid = decoded_token['uid']
            email = decoded_token.get('email')

            # Firestoreからユーザー情報を取得
            user_ref = self.db.collection('users').document(uid)
            user_doc = user_ref.get()

            if not user_doc.exists:
                raise ValueError("ユーザーが見つかりません")

            # JWTトークンを生成
            access_token = create_access_token(
                data={"uid": uid, "email": email}
            )

            return TokenResponse(
                access_token=access_token,
                token_type="bearer",
                expires_in=get_token_expire_time(),
                uid=uid
            )

        except auth.InvalidIdTokenError:
            raise ValueError("無効なIDトークンです")
        except FirebaseError as e:
            raise ValueError(f"認証に失敗しました: {str(e)}")

    async def get_user_by_uid(self, uid: str) -> Optional[UserInDB]:
        """
        UIDからユーザー情報を取得

        Args:
            uid: ユーザID

        Returns:
            ユーザー情報、存在しない場合はNone
        """
        user_ref = self.db.collection('users').document(uid)
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
            print(f"[AuthService] Error: User {uid} has no username")
            print(f"[AuthService] User data: {user_data}")
            raise ValueError(
                f"User {uid} has incomplete data (missing username). "
                "Please delete this user from Firebase Console and re-register."
            )

        return UserInDB(**user_data)

    async def delete_user(self, uid: str) -> bool:
        """
        ユーザーを削除

        Args:
            uid: ユーザID

        Returns:
            削除成功時True
        """
        try:
            # Firebase Authenticationからユーザー削除
            self.auth_client.delete_user(uid)

            # Firestoreからユーザー情報削除
            self.db.collection('users').document(uid).delete()

            return True

        except FirebaseError:
            return False

    async def update_fcm_token(self, uid: str, fcm_token: str) -> bool:
        """
        FCMトークンを追加・更新

        Args:
            uid: ユーザID
            fcm_token: FCMトークン

        Returns:
            更新成功時True
        """
        try:
            user_ref = self.db.collection('users').document(uid)

            # fcm_tokensに追加（重複を避ける）
            user_ref.update({
                'fcm_tokens': firestore.ArrayUnion([fcm_token])
            })

            return True

        except Exception:
            return False

    async def remove_fcm_token(self, uid: str, fcm_token: str) -> bool:
        """
        FCMトークンを削除

        Args:
            uid: ユーザID
            fcm_token: FCMトークン

        Returns:
            削除成功時True
        """
        try:
            user_ref = self.db.collection('users').document(uid)

            user_ref.update({
                'fcm_tokens': firestore.ArrayRemove([fcm_token])
            })

            return True

        except Exception:
            return False
