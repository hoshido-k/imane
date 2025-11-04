"""
バッチ処理APIエンドポイント

定期的に実行される処理（Cloud Functions、Cronジョブから呼び出される）
セキュリティ: 本番環境では認証トークンやIP制限が必要
"""

from fastapi import APIRouter, Header, HTTPException, status
from pydantic import BaseModel

from app.config import settings
from app.services.auto_notification import AutoNotificationService
from app.services.cleanup import CleanupService

router = APIRouter()


class BatchResponse(BaseModel):
    """バッチ処理のレスポンス"""

    success: bool
    message: str
    details: dict


def verify_batch_token(x_batch_token: str = Header(None)):
    """
    バッチ処理用トークンの検証

    Args:
        x_batch_token: リクエストヘッダーのバッチトークン

    Raises:
        HTTPException: トークンが無効な場合
    """
    # 本番環境では環境変数からトークンを読み込む
    # 開発環境ではトークンチェックをスキップ（DEBUGモード）
    if settings.DEBUG:
        return

    expected_token = getattr(settings, "BATCH_TOKEN", None)
    if not expected_token:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="バッチトークンが設定されていません",
        )

    if x_batch_token != expected_token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="無効なバッチトークンです",
        )


@router.post("/stay-notifications", response_model=BatchResponse)
async def send_stay_notifications_batch():
    """
    滞在通知のバッチ送信

    到着済みのスケジュールをチェックし、滞在時間に達したものに通知を送信します。
    推奨実行頻度: 5分毎

    Returns:
        処理結果
    """
    auto_notification_service = AutoNotificationService()

    sent_count = await auto_notification_service.check_and_send_stay_notifications()

    return BatchResponse(
        success=True,
        message=f"滞在通知を{sent_count}件送信しました",
        details={"sent_count": sent_count},
    )


@router.post("/cleanup", response_model=BatchResponse)
async def cleanup_expired_data_batch():
    """
    期限切れデータの削除

    24時間以上経過した位置情報履歴、通知履歴、スケジュールを削除します。
    推奨実行頻度: 1時間毎

    Returns:
        処理結果
    """
    cleanup_service = CleanupService()

    results = await cleanup_service.cleanup_expired_data()

    total = sum(results.values())

    return BatchResponse(
        success=True,
        message=f"期限切れデータを{total}件削除しました",
        details=results,
    )


@router.post("/update-expired-schedules", response_model=BatchResponse)
async def update_expired_schedules_batch():
    """
    期限切れスケジュールのステータス更新

    終了時刻を過ぎたスケジュールのステータスをEXPIREDに更新します。
    推奨実行頻度: 10分毎

    Returns:
        処理結果
    """
    cleanup_service = CleanupService()

    updated_count = await cleanup_service.update_expired_schedules_status()

    return BatchResponse(
        success=True,
        message=f"{updated_count}件のスケジュールをEXPIREDに更新しました",
        details={"updated_count": updated_count},
    )


@router.get("/cleanup-stats", response_model=BatchResponse)
async def get_cleanup_stats():
    """
    クリーンアップ対象データの統計情報を取得

    削除対象となるデータの件数を確認します。

    Returns:
        統計情報
    """
    cleanup_service = CleanupService()

    stats = await cleanup_service.get_cleanup_stats()

    return BatchResponse(
        success=True, message="統計情報を取得しました", details=stats
    )


@router.post("/run-all", response_model=BatchResponse)
async def run_all_batch_jobs():
    """
    全てのバッチ処理を一括実行

    開発・テスト用のエンドポイント。
    本番環境では各バッチ処理を個別にスケジュールすることを推奨。

    Returns:
        処理結果
    """
    auto_notification_service = AutoNotificationService()
    cleanup_service = CleanupService()

    # 1. 期限切れスケジュールのステータス更新
    updated_count = await cleanup_service.update_expired_schedules_status()

    # 2. 滞在通知の送信
    sent_count = await auto_notification_service.check_and_send_stay_notifications()

    # 3. 期限切れデータの削除
    cleanup_results = await cleanup_service.cleanup_expired_data()

    total_cleaned = sum(cleanup_results.values())

    return BatchResponse(
        success=True,
        message="全てのバッチ処理を完了しました",
        details={
            "expired_schedules_updated": updated_count,
            "stay_notifications_sent": sent_count,
            "data_cleaned": total_cleaned,
            "cleanup_breakdown": cleanup_results,
        },
    )
