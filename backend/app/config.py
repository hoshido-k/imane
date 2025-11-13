from pydantic_settings import BaseSettings
from typing import Optional
import os

class Settings(BaseSettings):
    # 環境設定
    ENV: str = os.getenv("ENV", "development")  # "development" or "production"

    # アプリケーション設定
    APP_NAME: str = "imane API"
    DEBUG: bool = True  # 開発時はTrue、本番時はFalse

    # Firebase設定
    FIREBASE_PROJECT_ID: str
    FIREBASE_CREDENTIALS_PATH: Optional[str] = None
    STORAGE_BUCKET: Optional[str] = None  # カスタムバケット名（省略時は自動生成）

    # JWT設定
    SECRET_KEY: str
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30

    # 暗号化設定
    ENCRYPTION_KEY: str

    # 位置情報設定
    GEOFENCE_RADIUS_METERS: int = 50
    LOCATION_UPDATE_INTERVAL_MINUTES: int = 5
    DATA_RETENTION_HOURS: int = 24

    # 通知設定
    NOTIFICATION_STAY_DURATION_MINUTES: int = 60

    # バッチ処理設定
    BATCH_TOKEN: Optional[str] = None  # 本番環境では必須

    # CORS設定
    ALLOWED_ORIGINS: str = "*"  # カンマ区切りで複数指定可能（例: "https://app.example.com,https://admin.example.com"）

    class Config:
        env_file = ".env"
        case_sensitive = True

    @property
    def is_production(self) -> bool:
        """本番環境かどうかを返す"""
        return self.ENV == "production"

    @property
    def is_development(self) -> bool:
        """開発環境かどうかを返す"""
        return self.ENV == "development"

settings = Settings()
