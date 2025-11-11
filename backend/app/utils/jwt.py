"""
JWT トークン生成・検証ユーティリティ
"""

from datetime import datetime, timedelta
from typing import Optional, Dict, Any
from jose import jwt, JWTError
from app.config import settings
from app.utils.timezone import now_jst


def create_access_token(data: Dict[str, Any], expires_delta: Optional[timedelta] = None) -> str:
    """
    JWTアクセストークンを生成

    Args:
        data: トークンに含めるデータ（uid, emailなど）
        expires_delta: 有効期限（Noneの場合はデフォルト30分）

    Returns:
        JWT トークン文字列
    """
    to_encode = data.copy()

    if expires_delta:
        expire = now_jst() + expires_delta
    else:
        expire = now_jst() + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)

    to_encode.update({"exp": expire, "iat": now_jst()})

    encoded_jwt = jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.ALGORITHM)
    return encoded_jwt


def verify_token(token: str) -> Optional[Dict[str, Any]]:
    """
    JWTトークンを検証してペイロードを取得

    Args:
        token: JWT トークン文字列

    Returns:
        検証成功時はペイロード、失敗時はNone
    """
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        return payload
    except JWTError:
        return None


def get_token_expire_time() -> int:
    """
    トークンの有効期限を秒で取得

    Returns:
        有効期限（秒）
    """
    return settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60
