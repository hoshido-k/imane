from pydantic_settings import BaseSettings
from typing import Optional

class Settings(BaseSettings):
    # アプリケーション設定
    APP_NAME: str = "Generic API"
    DEBUG: bool = False

    # Firebase設定
    FIREBASE_PROJECT_ID: str
    FIREBASE_CREDENTIALS_PATH: Optional[str] = None

    # JWT設定
    SECRET_KEY: str
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30

    # 暗号化設定
    ENCRYPTION_KEY: str

    class Config:
        env_file = ".env"
        case_sensitive = True

settings = Settings()
