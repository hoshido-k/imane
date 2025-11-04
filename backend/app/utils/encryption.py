"""
位置情報暗号化ユーティリティ
"""

import base64
import json
from typing import Any

from cryptography.fernet import Fernet

from app.config import settings


def _get_cipher() -> Fernet:
    """
    暗号化キーからFernetオブジェクトを取得

    Returns:
        Fernet: 暗号化/復号化オブジェクト
    """
    # ENCRYPTION_KEYが既にFernet形式の場合はそのまま使用
    # そうでない場合はbase64エンコード（初回セットアップ時）
    try:
        return Fernet(settings.ENCRYPTION_KEY.encode())
    except Exception:
        # キーが正しくない場合は、キーから新しいFernetキーを生成
        key = base64.urlsafe_b64encode(settings.ENCRYPTION_KEY.encode().ljust(32)[:32])
        return Fernet(key)


def encrypt_location_data(latitude: float, longitude: float, **extra_data: Any) -> str:
    """
    位置情報データを暗号化

    Args:
        latitude: 緯度
        longitude: 経度
        **extra_data: 追加データ（timestamp, accuracy, speedなど）

    Returns:
        str: 暗号化されたデータ（base64文字列）
    """
    cipher = _get_cipher()

    # JSONとして結合
    data = {
        "lat": latitude,
        "lng": longitude,
        **extra_data
    }

    # JSON文字列化して暗号化
    json_data = json.dumps(data)
    encrypted = cipher.encrypt(json_data.encode())

    return encrypted.decode()


def decrypt_location_data(encrypted_data: str) -> dict[str, Any]:
    """
    暗号化された位置情報データを復号化

    Args:
        encrypted_data: 暗号化されたデータ（base64文字列）

    Returns:
        dict: 復号化されたデータ（lat, lng, その他のフィールド）

    Raises:
        ValueError: 復号化に失敗した場合
    """
    try:
        cipher = _get_cipher()
        decrypted = cipher.decrypt(encrypted_data.encode())
        data = json.loads(decrypted.decode())
        return data
    except Exception as e:
        raise ValueError(f"Failed to decrypt location data: {str(e)}")


def encrypt_string(text: str) -> str:
    """
    文字列を暗号化

    Args:
        text: 暗号化する文字列

    Returns:
        str: 暗号化された文字列（base64）
    """
    cipher = _get_cipher()
    encrypted = cipher.encrypt(text.encode())
    return encrypted.decode()


def decrypt_string(encrypted_text: str) -> str:
    """
    暗号化された文字列を復号化

    Args:
        encrypted_text: 暗号化された文字列（base64）

    Returns:
        str: 復号化された文字列

    Raises:
        ValueError: 復号化に失敗した場合
    """
    try:
        cipher = _get_cipher()
        decrypted = cipher.decrypt(encrypted_text.encode())
        return decrypted.decode()
    except Exception as e:
        raise ValueError(f"Failed to decrypt string: {str(e)}")
