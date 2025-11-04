"""
ポップAPIの統合テスト - Firestore実接続テスト

実際のFirestoreに接続してデータの読み書きをテストします。
テスト実行前に以下を確認してください:
1. Firebase プロジェクトが作成されている
2. .env ファイルに正しい認証情報が設定されている
3. serviceAccountKey.json が配置されている
"""

import asyncio
from datetime import datetime, timedelta, timezone

import pytest
from firebase_admin import firestore

from app.core.firebase import db
from app.schemas.pop import PopCategory, Location, PopCreate, PopSearchRequest
from app.services.pops import PopService


class TestPopIntegration:
    """ポップサービスの統合テスト"""

    @pytest.fixture(autouse=True)
    def setup_and_teardown(self):
        """各テストの前後でFirestoreをクリーンアップ"""
        self.pop_service = PopService()
        self.test_user_id = "test_user_integration_123"
        self.created_pop_ids = []

        yield

        # テスト後のクリーンアップ
        batch = db.batch()
        for pop_id in self.created_pop_ids:
            pop_ref = db.collection("pops").document(pop_id)
            batch.delete(pop_ref)
        batch.commit()

    @pytest.mark.asyncio
    async def test_create_and_read_pop(self):
        """ポップの作成と読み取りテスト"""
        # ポップを作成
        pop_data = PopCreate(
            content="統合テスト: カフェで勉強しませんか？",
            category=PopCategory.STUDY,
            location=Location(latitude=35.6812, longitude=139.7671),  # 東京駅
            duration_minutes=30,
        )

        created_pop = await self.pop_service.create_pop(self.test_user_id, pop_data)
        self.created_pop_ids.append(created_pop.pop_id)

        # 作成されたポップを確認
        assert created_pop.pop_id is not None
        assert created_pop.content == pop_data.content
        assert created_pop.category == pop_data.category
        assert created_pop.author_id == self.test_user_id
        assert created_pop.is_active is True
        assert created_pop.reaction_count == 0

        # Firestoreから直接読み取り
        pop_doc = db.collection("pops").document(created_pop.pop_id).get()
        assert pop_doc.exists
        pop_dict = pop_doc.to_dict()
        assert pop_dict["content"] == pop_data.content
        assert pop_dict["author_id"] == self.test_user_id

        # IDで取得
        retrieved_pop = await self.pop_service.get_pop_by_id(created_pop.pop_id)
        assert retrieved_pop is not None
        assert retrieved_pop.id == created_pop.pop_id
        assert retrieved_pop.content == created_pop.content

    @pytest.mark.asyncio
    async def test_search_nearby_pops(self):
        """周辺ポップ検索テスト"""
        # 複数のポップを異なる位置に作成
        locations = [
            Location(latitude=35.6812, longitude=139.7671),  # 東京駅
            Location(latitude=35.6895, longitude=139.6917),  # 新宿駅
            Location(latitude=35.6586, longitude=139.7454),  # 渋谷駅
        ]

        for i, location in enumerate(locations):
            pop_data = PopCreate(
                content=f"統合テスト: 場所{i+1}",
                category=PopCategory.FOOD,
                location=location,
                duration_minutes=30,
            )
            created_pop = await self.pop_service.create_pop(self.test_user_id, pop_data)
            self.created_pop_ids.append(created_pop.pop_id)

        # 少し待機（Firestoreの反映を待つ）
        await asyncio.sleep(1)

        # 東京駅周辺を検索（半径5km）
        search_request = PopSearchRequest(
            center=Location(latitude=35.6812, longitude=139.7671),
            radius_km=5.0,
            categories=[PopCategory.FOOD],
            limit=10,
        )

        results = await self.pop_service.search_nearby_pops(search_request)

        # 少なくとも作成したポップの一部が見つかるはず
        assert len(results) > 0
        assert any(pop.content.startswith("統合テスト:") for pop in results)

    @pytest.mark.asyncio
    async def test_update_pop(self):
        """ポップ更新テスト"""
        # ポップを作成
        pop_data = PopCreate(
            content="更新前のコンテンツ",
            category=PopCategory.SPORTS,
            location=Location(latitude=35.6812, longitude=139.7671),
            duration_minutes=30,
        )

        created_pop = await self.pop_service.create_pop(self.test_user_id, pop_data)
        self.created_pop_ids.append(created_pop.pop_id)

        # ポップを更新
        from app.schemas.pop import PopUpdate

        update_data = PopUpdate(
            content="更新後のコンテンツ",
            category=PopCategory.GAME,
        )

        await self.pop_service.update_pop(created_pop.pop_id, self.test_user_id, update_data)

        # 更新を確認
        updated_pop = await self.pop_service.get_pop_by_id(created_pop.pop_id)
        assert updated_pop.content == "更新後のコンテンツ"
        assert updated_pop.category == PopCategory.GAME

        # Firestoreから直接確認
        pop_doc = db.collection("pops").document(created_pop.pop_id).get()
        pop_dict = pop_doc.to_dict()
        assert pop_dict["content"] == "更新後のコンテンツ"
        assert pop_dict["category"] == PopCategory.GAME.value

    @pytest.mark.asyncio
    async def test_delete_pop(self):
        """ポップ削除テスト（論理削除）"""
        # ポップを作成
        pop_data = PopCreate(
            content="削除テスト用ポップ",
            category=PopCategory.OTHER,
            location=Location(latitude=35.6812, longitude=139.7671),
            duration_minutes=30,
        )

        created_pop = await self.pop_service.create_pop(self.test_user_id, pop_data)
        self.created_pop_ids.append(created_pop.pop_id)

        # ポップを削除
        await self.pop_service.delete_pop(created_pop.pop_id, self.test_user_id)

        # 論理削除を確認
        pop_doc = db.collection("pops").document(created_pop.pop_id).get()
        assert pop_doc.exists  # ドキュメントは存在する
        pop_dict = pop_doc.to_dict()
        assert pop_dict["is_active"] is False  # is_activeがFalseになっている
        assert pop_dict["deleted_at"] is not None  # deleted_atが設定されている

        # サービス経由では取得できない（is_active=Falseのため）
        deleted_pop = await self.pop_service.get_pop_by_id(created_pop.pop_id)
        assert deleted_pop is None

    @pytest.mark.asyncio
    async def test_get_user_pops(self):
        """ユーザーのポップ一覧取得テスト"""
        # 複数のポップを作成
        for i in range(3):
            pop_data = PopCreate(
                content=f"ユーザーポップ {i+1}",
                category=PopCategory.FOOD,
                location=Location(latitude=35.6812, longitude=139.7671),
                duration_minutes=30,
            )
            created_pop = await self.pop_service.create_pop(self.test_user_id, pop_data)
            self.created_pop_ids.append(created_pop.pop_id)

        # 少し待機
        await asyncio.sleep(1)

        # ユーザーのポップを取得
        user_pops = await self.pop_service.get_user_pops(self.test_user_id, False)

        # 作成した3つのポップが取得できるはず
        assert len(user_pops) >= 3
        assert all(pop.author_id == self.test_user_id for pop in user_pops)
        assert all("ユーザーポップ" in pop.content for pop in user_pops[:3])

    @pytest.mark.asyncio
    async def test_expired_pop_not_in_search(self):
        """期限切れポップが検索結果に含まれないことを確認"""
        # 期限切れのポップを作成（手動でFirestoreに書き込み）
        expired_time = datetime.now(timezone.utc) - timedelta(minutes=10)

        pop_ref = db.collection("pops").document()
        pop_data_dict = {
            "content": "期限切れポップ",
            "category": PopCategory.FOOD.value,
            "author_id": self.test_user_id,
            "location": firestore.GeoPoint(35.6812, 139.7671),
            "geohash": "xn76urx6",
            "is_active": True,
            "expires_at": expired_time,
            "created_at": expired_time - timedelta(minutes=30),
            "updated_at": expired_time - timedelta(minutes=30),
            "reaction_count": 0,
        }
        pop_ref.set(pop_data_dict)
        self.created_pop_ids.append(pop_ref.id)

        # 有効なポップも作成
        valid_pop_data = PopCreate(
            content="有効なポップ",
            category=PopCategory.FOOD,
            location=Location(latitude=35.6812, longitude=139.7671),
            duration_minutes=30,
        )
        valid_pop = await self.pop_service.create_pop(self.test_user_id, valid_pop_data)
        self.created_pop_ids.append(valid_pop.pop_id)

        # 少し待機
        await asyncio.sleep(1)

        # 検索
        search_request = PopSearchRequest(
            center=Location(latitude=35.6812, longitude=139.7671),
            radius_km=5.0,
            categories=[PopCategory.FOOD],
            limit=10,
        )

        results = await self.pop_service.search_nearby_pops(search_request)

        # 有効なポップのみが含まれ、期限切れポップは含まれない
        result_contents = [pop.content for pop in results]
        assert "有効なポップ" in result_contents
        assert "期限切れポップ" not in result_contents


@pytest.mark.asyncio
async def test_firestore_connection():
    """Firestore接続テスト"""
    # Firestoreクライアントが初期化されているか確認
    assert db is not None

    # テストコレクションへの書き込み
    test_ref = db.collection("_test_connection").document("test_doc")
    test_data = {
        "message": "Integration test",
        "timestamp": datetime.now(timezone.utc),
        "test": True,
    }

    test_ref.set(test_data)

    # 読み取り
    doc = test_ref.get()
    assert doc.exists
    assert doc.to_dict()["message"] == "Integration test"

    # クリーンアップ
    test_ref.delete()
