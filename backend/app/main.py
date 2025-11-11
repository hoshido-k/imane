import logging

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.v1 import (
    auth,
    batch,
    favorites,
    friends,
    location,
    notifications,
    schedules,
    users,
)
from app.core.firebase import initialize_firebase

# ロギング設定
logging.basicConfig(
    level=logging.INFO,
    format="%(levelname)s:     %(name)s - %(message)s",
)

# アプリケーションロガーを取得
logger = logging.getLogger(__name__)

app = FastAPI(
    title="imane API",
    description="imane - 位置情報ベース自動通知アプリのバックエンドAPI",
    version="1.0.0",
    redirect_slashes=False  # 307リダイレクトを無効化
)

# CORS設定
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 本番環境では適切に制限
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.on_event("startup")
async def startup_event():
    """アプリケーション起動時の処理"""
    logger.info("=" * 50)
    logger.info("imane API サーバー起動中...")
    logger.info("=" * 50)
    initialize_firebase()
    logger.info("Firebase初期化完了")
    logger.info("=" * 50)

# ルーター登録
app.include_router(auth.router, prefix="/api/v1/auth", tags=["認証"])
app.include_router(users.router, prefix="/api/v1/users", tags=["ユーザー"])
app.include_router(friends.router, prefix="/api/v1/friends", tags=["フレンド"])
app.include_router(schedules.router, prefix="/api/v1/schedules", tags=["スケジュール"])
app.include_router(favorites.router, prefix="/api/v1/favorites", tags=["お気に入り"])
app.include_router(location.router, prefix="/api/v1/location", tags=["位置情報"])
app.include_router(notifications.router, prefix="/api/v1/notifications", tags=["通知"])
app.include_router(batch.router, prefix="/api/v1/batch", tags=["バッチ処理"])

@app.get("/")
async def root():
    return {"message": "imane API", "status": "running", "version": "1.0.0"}

@app.get("/health")
async def health_check():
    return {"status": "healthy"}
