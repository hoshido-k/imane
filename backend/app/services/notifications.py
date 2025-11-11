"""
通知サービス

Firebase Cloud Messaging (FCM) を使用したプッシュ通知の送信と、
Firestoreでの通知履歴管理を行います。
"""

import logging
from datetime import datetime
from typing import Any, List, Optional

from firebase_admin import messaging
from google.cloud.firestore_v1 import FieldFilter

from app.core.firebase import get_firestore_client
from app.utils.timezone import now_jst
from app.schemas.notification import (
    NotificationResponse,
    NotificationType,
)
from app.services.users import UserService

logger = logging.getLogger(__name__)


class NotificationService:
    """通知サービスクラス"""

    def __init__(self):
        self.db = get_firestore_client()
        self.user_service = UserService()

    async def send_push_notification(
        self,
        user_id: str,
        title: str,
        body: str,
        notification_type: NotificationType,
        data: Optional[dict[str, Any]] = None,
        save_to_db: bool = True,
    ) -> Optional[NotificationResponse]:
        """
        プッシュ通知を送信

        Args:
            user_id: 送信先ユーザID
            title: 通知タイトル
            body: 通知本文
            notification_type: 通知タイプ
            data: 追加データ（オプション）
            save_to_db: Firestoreに通知履歴を保存するかどうか

        Returns:
            保存された通知データ（save_to_db=Trueの場合）

        Raises:
            ValueError: ユーザーが見つからない、FCMトークンがない場合
        """
        if data is None:
            data = {}

        logger.info(
            f"[通知送信] 送信先: {user_id}, タイプ: {notification_type.value}, "
            f"タイトル: {title}, DB保存: {save_to_db}"
        )

        # ユーザーを取得
        user = await self.user_service.get_user_by_uid(user_id)
        if not user:
            logger.error(f"[通知送信] ユーザーが見つかりません: {user_id}")
            raise ValueError(f"ユーザーが見つかりません: {user_id}")

        # FCMトークンが登録されているか確認
        if not user.fcm_tokens or len(user.fcm_tokens) == 0:
            logger.warning(
                f"[通知送信] ユーザー {user_id} にFCMトークンが登録されていません。"
                f"FCM送信はスキップしますが、DB保存は実行します。"
            )
            # トークンがなくてもDB保存は行う（後で通知一覧で確認できるように）
            if save_to_db:
                result = await self._save_notification_to_db(
                    user_id=user_id,
                    title=title,
                    body=body,
                    notification_type=notification_type,
                    data=data,
                )
                logger.info(f"[通知送信] DB保存完了: notification_id={result.notification_id}")
                return result
            return None

        logger.info(f"[通知送信] FCMトークン数: {len(user.fcm_tokens)}")

        # FCMメッセージを構築
        # 複数のトークンに送信する場合はMulticastMessageを使用
        tokens = user.fcm_tokens

        # データペイロードに通知タイプを追加
        data_payload = {
            "type": notification_type.value,
            **data,
        }

        # 文字列型に変換（FCMのdataフィールドは文字列のみ受け付ける）
        data_payload_str = {k: str(v) for k, v in data_payload.items()}

        multicast_message = messaging.MulticastMessage(
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            data=data_payload_str,
            tokens=tokens,
            # Android固有の設定
            android=messaging.AndroidConfig(
                priority="high",
                notification=messaging.AndroidNotification(
                    channel_id="bubble_notifications",
                    sound="default",
                ),
            ),
            # iOS固有の設定
            apns=messaging.APNSConfig(
                payload=messaging.APNSPayload(
                    aps=messaging.Aps(
                        sound="default",
                        badge=1,
                    ),
                ),
            ),
        )

        # FCMで送信（個別送信に変更）
        try:
            # send_multicast の代わりに send_each を使用
            messages = []
            for token in tokens:
                messages.append(
                    messaging.Message(
                        notification=messaging.Notification(
                            title=title,
                            body=body,
                        ),
                        data={k: str(v) for k, v in data.items()} if data else None,
                        token=token,
                        apns=messaging.APNSConfig(
                            payload=messaging.APNSPayload(
                                aps=messaging.Aps(
                                    alert=messaging.ApsAlert(title=title, body=body),
                                    sound="default",
                                    badge=1,
                                )
                            )
                        ),
                    )
                )

            response = messaging.send_each(messages)
            logger.info(
                f"[通知送信] FCM送信完了: {response.success_count}/{len(tokens)} 成功, "
                f"{response.failure_count} 失敗"
            )

            # 失敗したトークンを削除
            if response.failure_count > 0:
                failed_tokens = []
                for idx, result in enumerate(response.responses):
                    if not result.success:
                        failed_tokens.append(tokens[idx])
                        logger.warning(
                            f"[通知送信] FCM送信失敗: トークン={tokens[idx][:20]}..., "
                            f"エラー: {result.exception}"
                        )

                # 無効なトークンを削除
                await self._remove_invalid_fcm_tokens(user_id, failed_tokens)

        except Exception as e:
            logger.error(f"[通知送信] FCM送信エラー: {type(e).__name__}: {str(e)}", exc_info=True)
            # エラーが発生してもDB保存は続行

        # Firestoreに通知を保存
        if save_to_db:
            result = await self._save_notification_to_db(
                user_id=user_id,
                title=title,
                body=body,
                notification_type=notification_type,
                data=data,
            )
            logger.info(f"[通知送信] DB保存完了: notification_id={result.notification_id}")
            return result

        return None

    async def _save_notification_to_db(
        self,
        user_id: str,
        title: str,
        body: str,
        notification_type: NotificationType,
        data: dict[str, Any],
    ) -> NotificationResponse:
        """
        通知をFirestoreに保存（内部メソッド）

        Args:
            user_id: ユーザID
            title: タイトル
            body: 本文
            notification_type: 通知タイプ
            data: 追加データ

        Returns:
            保存された通知データ
        """
        notification_ref = self.db.collection("notifications").document()
        notification_dict = {
            "notification_id": notification_ref.id,
            "user_id": user_id,
            "type": notification_type.value,
            "title": title,
            "body": body,
            "data": data,
            "is_read": False,
            "created_at": now_jst(),
            "read_at": None,
        }

        logger.info(
            f"[DB保存] notificationsコレクションに保存中: "
            f"notification_id={notification_ref.id}, user_id={user_id}, type={notification_type.value}"
        )

        notification_ref.set(notification_dict)

        logger.info(f"[DB保存] 保存完了: notification_id={notification_ref.id}")

        return NotificationResponse(**notification_dict)

    async def _remove_invalid_fcm_tokens(self, user_id: str, invalid_tokens: List[str]) -> None:
        """
        無効なFCMトークンを削除（内部メソッド）

        Args:
            user_id: ユーザID
            invalid_tokens: 削除するトークンのリスト
        """
        user_ref = self.db.collection("users").document(user_id)
        user_doc = user_ref.get()

        if not user_doc.exists:
            return

        user_data = user_doc.to_dict()
        current_tokens = user_data.get("fcm_tokens", [])

        # 無効なトークンを除外
        updated_tokens = [token for token in current_tokens if token not in invalid_tokens]

        user_ref.update({"fcm_tokens": updated_tokens, "updated_at": now_jst()})
        logger.info(f"ユーザー {user_id} の無効なFCMトークンを削除しました: {invalid_tokens}")

    async def register_fcm_token(self, user_id: str, fcm_token: str) -> None:
        """
        FCMトークンを登録

        Args:
            user_id: ユーザID
            fcm_token: FCMトークン

        Raises:
            ValueError: ユーザーが見つからない場合
        """
        user_ref = self.db.collection("users").document(user_id)
        user_doc = user_ref.get()

        if not user_doc.exists:
            raise ValueError(f"ユーザーが見つかりません: {user_id}")

        user_data = user_doc.to_dict()
        current_tokens = user_data.get("fcm_tokens", [])

        # トークンが既に登録されている場合はスキップ
        if fcm_token in current_tokens:
            logger.info(f"FCMトークンは既に登録されています: {user_id}")
            return

        # トークンを追加
        current_tokens.append(fcm_token)
        user_ref.update({"fcm_tokens": current_tokens, "updated_at": now_jst()})
        logger.info(f"FCMトークンを登録しました: {user_id}")

    async def remove_fcm_token(self, user_id: str, fcm_token: str) -> None:
        """
        FCMトークンを削除

        Args:
            user_id: ユーザID
            fcm_token: 削除するFCMトークン

        Raises:
            ValueError: ユーザーが見つからない場合
        """
        user_ref = self.db.collection("users").document(user_id)
        user_doc = user_ref.get()

        if not user_doc.exists:
            raise ValueError(f"ユーザーが見つかりません: {user_id}")

        user_data = user_doc.to_dict()
        current_tokens = user_data.get("fcm_tokens", [])

        # トークンを削除
        if fcm_token in current_tokens:
            current_tokens.remove(fcm_token)
            user_ref.update({"fcm_tokens": current_tokens, "updated_at": now_jst()})
            logger.info(f"FCMトークンを削除しました: {user_id}")
        else:
            logger.warning(f"削除対象のFCMトークンが見つかりません: {user_id}")

    async def get_user_notifications(
        self, user_id: str, limit: int = 50, unread_only: bool = False
    ) -> List[NotificationResponse]:
        """
        ユーザーの通知一覧を取得

        Args:
            user_id: ユーザID
            limit: 取得件数（デフォルト50件）
            unread_only: 未読のみ取得するかどうか

        Returns:
            通知一覧
        """
        try:
            query = (
                self.db.collection("notifications")
                .where(filter=FieldFilter("user_id", "==", user_id))
                .order_by("created_at", direction="DESCENDING")
                .limit(limit)
            )

            # 未読のみフィルタ
            if unread_only:
                query = query.where(filter=FieldFilter("is_read", "==", False))

            notifications = query.get()

            result = []
            for notif in notifications:
                notif_data = notif.to_dict()
                result.append(NotificationResponse(**notif_data))

            return result
        except Exception as e:
            # インデックスがない場合や通知がない場合は空のリストを返す
            print(f"[NotificationService] Error getting notifications: {e}")
            return []

    async def get_unread_count(self, user_id: str) -> int:
        """
        未読通知数を取得

        Args:
            user_id: ユーザID

        Returns:
            未読通知数
        """
        try:
            unread_notifications = (
                self.db.collection("notifications")
                .where(filter=FieldFilter("user_id", "==", user_id))
                .where(filter=FieldFilter("is_read", "==", False))
                .get()
            )

            return len(list(unread_notifications))
        except Exception as e:
            # インデックスがない場合は0を返す
            print(f"[NotificationService] Error getting unread count: {e}")
            return 0

    async def mark_notifications_as_read(self, user_id: str, notification_ids: List[str]) -> int:
        """
        通知を既読にする

        Args:
            user_id: ユーザID
            notification_ids: 既読にする通知IDのリスト

        Returns:
            更新された通知数

        Raises:
            ValueError: 権限がない場合
        """
        updated_count = 0
        now = now_jst()

        for notification_id in notification_ids:
            notification_ref = self.db.collection("notifications").document(notification_id)
            notification_doc = notification_ref.get()

            if not notification_doc.exists:
                continue

            notification_data = notification_doc.to_dict()

            # ユーザIDが一致するかチェック
            if notification_data["user_id"] != user_id:
                raise ValueError("この通知を既読にする権限がありません")

            # 既に既読の場合はスキップ
            if notification_data.get("is_read", False):
                continue

            # 通知を既読にする
            notification_ref.update({"is_read": True, "read_at": now})
            updated_count += 1

        return updated_count

    async def delete_notification(self, user_id: str, notification_id: str) -> None:
        """
        通知を削除

        Args:
            user_id: ユーザID
            notification_id: 削除する通知ID

        Raises:
            ValueError: 通知が見つからない、権限がない場合
        """
        notification_ref = self.db.collection("notifications").document(notification_id)
        notification_doc = notification_ref.get()

        if not notification_doc.exists:
            raise ValueError("通知が見つかりません")

        notification_data = notification_doc.to_dict()

        # ユーザIDが一致するかチェック
        if notification_data["user_id"] != user_id:
            raise ValueError("この通知を削除する権限がありません")

        # 通知を削除
        notification_ref.delete()
        logger.info(f"通知を削除しました: {notification_id}")
