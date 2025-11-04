"""
共通のPydanticスキーマ定義
"""

from pydantic import BaseModel, Field


class Coordinates(BaseModel):
    """座標情報"""

    lat: float = Field(..., ge=-90, le=90, description="緯度")
    lng: float = Field(..., ge=-180, le=180, description="経度")
