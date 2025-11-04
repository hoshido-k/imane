import firebase_admin
from firebase_admin import credentials, firestore, auth, storage
from app.config import settings

def initialize_firebase():
    """Firebase初期化"""
    if not firebase_admin._apps:
        if settings.FIREBASE_CREDENTIALS_PATH:
            cred = credentials.Certificate(settings.FIREBASE_CREDENTIALS_PATH)
        else:
            # Cloud Runの場合、デフォルト認証情報を使用
            cred = credentials.ApplicationDefault()

        firebase_admin.initialize_app(cred, {
            'projectId': settings.FIREBASE_PROJECT_ID,
        })

def get_firestore_client():
    """Firestoreクライアント取得"""
    return firestore.client()

def get_auth_client():
    """Firebase Auth クライアント取得"""
    return auth

def get_storage_client():
    """Firebase Storage クライアント取得"""
    return storage

# グローバルインスタンス（アプリ起動時に初期化）
initialize_firebase()
db = get_firestore_client()
