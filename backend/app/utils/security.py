"""
セキュリティ関連のユーティリティ（パスワードハッシュ化など）
"""

from passlib.context import CryptContext

# bcryptを使用したパスワードハッシュ化
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


def hash_password(password: str) -> str:
    """
    パスワードをハッシュ化

    Args:
        password: 平文パスワード

    Returns:
        ハッシュ化されたパスワード
    """
    return pwd_context.hash(password)


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """
    パスワードを検証

    Args:
        plain_password: 平文パスワード
        hashed_password: ハッシュ化されたパスワード

    Returns:
        パスワードが一致すればTrue
    """
    return pwd_context.verify(plain_password, hashed_password)
