"""
日本標準時（JST）タイムゾーン関連のユーティリティ
"""

from datetime import datetime, timedelta, timezone

# 日本標準時（JST = UTC+9）
JST = timezone(timedelta(hours=9), "JST")


def now_jst() -> datetime:
    """
    現在の日本時刻を返す

    Returns:
        datetime: JST（UTC+9）でタイムゾーン付きのdatetimeオブジェクト
    """
    return datetime.now(JST)


def to_jst(dt: datetime) -> datetime:
    """
    datetimeオブジェクトをJSTに変換する

    Args:
        dt: 変換元のdatetimeオブジェクト

    Returns:
        datetime: JSTに変換されたdatetimeオブジェクト
    """
    if dt.tzinfo is None:
        # タイムゾーン未指定の場合はJSTと見なす（システム全体がJST統一のため）
        return dt.replace(tzinfo=JST)
    return dt.astimezone(JST)


def jst_now_plus(hours: int = 0, minutes: int = 0, days: int = 0) -> datetime:
    """
    現在のJST時刻から指定時間後の時刻を返す

    Args:
        hours: 加算する時間数
        minutes: 加算する分数
        days: 加算する日数

    Returns:
        datetime: 現在時刻 + 指定時間のJSTタイムゾーン付きdatetime
    """
    return now_jst() + timedelta(hours=hours, minutes=minutes, days=days)
