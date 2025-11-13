"""
pytest設定とフィクスチャ定義
"""

from datetime import datetime
from typing import Dict, List
from unittest.mock import MagicMock

import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.schemas.user import Address, UserInDB


@pytest.fixture
def client(sample_user1):
    """
    FastAPI TestClient with dependency overrides
    """
    from app.api.dependencies import get_current_user

    async def override_get_current_user():
        return sample_user1

    app.dependency_overrides[get_current_user] = override_get_current_user

    client = TestClient(app)
    yield client

    # クリーンアップ
    app.dependency_overrides.clear()


@pytest.fixture
def mock_firestore_client():
    """モックFirestoreクライアント"""
    mock_client = MagicMock()
    return mock_client


@pytest.fixture
def sample_user1() -> UserInDB:
    """テスト用ユーザー1"""
    return UserInDB(
        uid="test_user_1",
        username="testuser1",
        email="user1@example.com",
        display_name="テストユーザー1",
        profile_image_url=None,
        home_address=Address(
            latitude=35.6812,
            longitude=139.7671,
            registered_at=datetime(2024, 1, 1),
            last_changed_at=datetime(2024, 1, 1),
        ),
        work_address=None,
        custom_locations=[],
        fcm_tokens=[],
        created_at=datetime(2024, 1, 1),
        updated_at=datetime(2024, 1, 1),
    )


@pytest.fixture
def sample_user2() -> UserInDB:
    """テスト用ユーザー2"""
    return UserInDB(
        uid="test_user_2",
        username="testuser2",
        email="user2@example.com",
        display_name="テストユーザー2",
        profile_image_url=None,
        home_address=Address(
            latitude=35.6895,
            longitude=139.6917,
            registered_at=datetime(2024, 1, 1),
            last_changed_at=datetime(2024, 1, 1),
        ),
        work_address=None,
        custom_locations=[],
        fcm_tokens=[],
        created_at=datetime(2024, 1, 1),
        updated_at=datetime(2024, 1, 1),
    )


@pytest.fixture
def sample_user3() -> UserInDB:
    """テスト用ユーザー3"""
    return UserInDB(
        uid="test_user_3",
        username="testuser3",
        email="user3@example.com",
        display_name="テストユーザー3",
        profile_image_url=None,
        home_address=None,
        work_address=None,
        custom_locations=[],
        fcm_tokens=[],
        created_at=datetime(2024, 1, 1),
        updated_at=datetime(2024, 1, 1),
    )


class MockFirestoreDocument:
    """Firestoreドキュメントのモック"""

    def __init__(self, doc_id: str, data: Dict, exists: bool = True):
        self.id = doc_id
        self._data = data
        self.exists = exists

    def to_dict(self) -> Dict:
        return self._data

    def get(self):
        return self


class MockFirestoreQuery:
    """Firestoreクエリのモック"""

    def __init__(self, documents: List[MockFirestoreDocument]):
        self._documents = documents

    def __iter__(self):
        return iter(self._documents)

    def __len__(self):
        return len(self._documents)


class MockFirestoreDocumentReference:
    """Firestoreドキュメント参照のモック"""

    def __init__(self, doc_id: str, collection_name: str):
        self.id = doc_id
        self._collection_name = collection_name
        self._data = {}

    def set(self, data: Dict):
        self._data = data

    def update(self, data: Dict):
        self._data.update(data)

    def delete(self):
        self._data = {}

    def get(self):
        return MockFirestoreDocument(self.id, self._data, exists=bool(self._data))


class MockFirestoreCollection:
    """Firestoreコレクションのモック"""

    def __init__(self, collection_name: str):
        self._collection_name = collection_name
        self._documents: Dict[str, MockFirestoreDocumentReference] = {}
        self._query_results: List[MockFirestoreDocument] = []

    def document(self, doc_id: str = None) -> MockFirestoreDocumentReference:
        if doc_id is None:
            # 自動生成ID
            doc_id = f"auto_generated_{len(self._documents)}"
        if doc_id not in self._documents:
            self._documents[doc_id] = MockFirestoreDocumentReference(doc_id, self._collection_name)
        return self._documents[doc_id]

    def where(self, *args, **kwargs):
        # チェーン可能なクエリを返す
        return self

    def order_by(self, *args, **kwargs):
        return self

    def limit(self, count: int):
        return self

    def get(self):
        return MockFirestoreQuery(self._query_results)

    def set_query_results(self, results: List[MockFirestoreDocument]):
        """テスト用：クエリ結果を設定"""
        self._query_results = results
