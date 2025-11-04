# 統合テスト実行ガイド

実際のFirestoreに接続してデータの読み書きをテストする統合テストの実行方法。

## 前提条件

### 1. Firebaseプロジェクトのセットアップ

統合テストを実行する前に、必ず以下を完了してください:

1. **Firebaseプロジェクトの作成**
   - [Firebase Console](https://console.firebase.google.com/)でプロジェクトを作成
   - プロジェクト名: `poplink-dev` (推奨)

2. **Firestoreデータベースの作成**
   - Firebase Console > Firestore Database
   - 「データベースを作成」
   - ロケーション: `asia-northeast1` (東京)
   - セキュリティルール: テストモードで開始

3. **サービスアカウントキーの生成**
   - Firebase Console > プロジェクト設定 > サービスアカウント
   - 「新しい秘密鍵を生成」をクリック
   - ダウンロードしたJSONファイルを`backend/serviceAccountKey.json`に配置

### 2. 環境変数の設定

`backend/.env`ファイルを作成（`.env.example`を参考に）:

```bash
# Firebase設定
FIREBASE_PROJECT_ID=poplink-dev  # 実際のプロジェクトID
FIREBASE_CREDENTIALS_PATH=./serviceAccountKey.json

# JWT設定
SECRET_KEY=test-secret-key-for-integration-tests
ACCESS_TOKEN_EXPIRE_MINUTES=30

# 暗号化キー
ENCRYPTION_KEY=test-encryption-key-change-this

# デバッグモード
DEBUG=True
```

**重要**: `FIREBASE_PROJECT_ID`は実際に作成したFirebaseプロジェクトのIDに変更してください。

## 統合テストの実行

### 全ての統合テストを実行

```bash
cd backend
uv run pytest tests/test_pops_integration.py -v
```

### 特定のテストのみ実行

```bash
# Firestore接続テストのみ
uv run pytest tests/test_pops_integration.py::test_firestore_connection -v

# ポップ作成・読み取りテストのみ
uv run pytest tests/test_pops_integration.py::TestPopIntegration::test_create_and_read_pop -v

# 検索テストのみ
uv run pytest tests/test_pops_integration.py::TestPopIntegration::test_search_nearby_pops -v
```

### 詳細なログを表示

```bash
uv run pytest tests/test_pops_integration.py -v -s
```

## テスト内容

### 1. `test_firestore_connection`
Firestoreへの基本的な接続と読み書きをテスト。

**検証内容**:
- Firestoreクライアントの初期化
- テストドキュメントの書き込み
- ドキュメントの読み取り
- ドキュメントの削除

### 2. `test_create_and_read_pop`
ポップの作成と読み取り機能をテスト。

**検証内容**:
- ポップサービス経由でのポップ作成
- 作成されたポップのフィールド検証
- Firestoreから直接ドキュメントを読み取り
- IDによるポップ取得

### 3. `test_search_nearby_pops`
位置情報ベースの周辺ポップ検索をテスト。

**検証内容**:
- 異なる位置に複数のポップを作成
- 指定位置から半径5km以内のポップを検索
- 検索結果にカテゴリフィルターが適用されるか確認

### 4. `test_update_pop`
ポップの更新機能をテスト。

**検証内容**:
- ポップの内容とカテゴリを更新
- 更新後のデータがサービス経由で正しく取得できるか
- Firestoreに更新が反映されているか確認

### 5. `test_delete_pop`
ポップの論理削除機能をテスト。

**検証内容**:
- ポップの削除（論理削除）
- `is_active`が`False`に設定されるか
- `deleted_at`が記録されるか
- サービス経由では取得できなくなるか

### 6. `test_get_user_pops`
特定ユーザーのポップ一覧取得をテスト。

**検証内容**:
- 同一ユーザーが複数のポップを作成
- ユーザーIDでフィルタリングされたポップ一覧を取得
- 作成したポップが全て含まれるか確認

### 7. `test_expired_pop_not_in_search`
期限切れポップが検索結果に含まれないことをテスト。

**検証内容**:
- 期限切れのポップを手動作成
- 有効なポップも作成
- 検索結果に有効なポップのみが含まれるか確認

## テストデータのクリーンアップ

各テストは`setup_and_teardown`フィクスチャで自動的にクリーンアップされます:

```python
@pytest.fixture(autouse=True)
async def setup_and_teardown(self):
    # テスト前: セットアップ
    self.pop_service = PopService()
    self.test_user_id = "test_user_integration_123"
    self.created_pop_ids = []

    yield

    # テスト後: クリーンアップ
    # 作成したポップを全て削除
    batch = db.batch()
    for pop_id in self.created_pop_ids:
        pop_ref = db.collection("pops").document(pop_id)
        batch.delete(pop_ref)
    batch.commit()
```

## トラブルシューティング

### エラー: "Could not automatically determine credentials"

**原因**: サービスアカウントキーが見つからない

**解決策**:
1. `backend/serviceAccountKey.json`が存在するか確認
2. `.env`の`FIREBASE_CREDENTIALS_PATH`を確認
3. パスが正しいか確認（相対パスまたは絶対パス）

### エラー: "Permission denied"

**原因**: Firestoreセキュリティルールが厳しすぎる

**解決策**:
1. Firebase Console > Firestore Database > ルール を確認
2. テスト用にルールを緩和:
   ```javascript
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       match /{document=**} {
         allow read, write: if true;  // テストのみ
       }
     }
   }
   ```
   **注意**: 本番環境では絶対に使用しないでください

### テストが遅い

**原因**: Firestoreへのネットワークアクセス

**対策**:
- ローカルFirestoreエミュレータを使用（推奨）
- テストを並列実行しない（データ競合を避けるため）

## ローカルFirestoreエミュレータの使用（推奨）

統合テストを本番Firestoreではなくローカルエミュレータで実行:

### 1. Firebaseエミュレータのインストール

```bash
# Firebase CLIをインストール
npm install -g firebase-tools

# Firebaseにログイン
firebase login

# プロジェクトを初期化
firebase init emulators
```

### 2. エミュレータの起動

```bash
firebase emulators:start
```

### 3. テスト実行時にエミュレータを使用

環境変数で設定:

```bash
export FIRESTORE_EMULATOR_HOST="localhost:8080"
uv run pytest tests/test_pops_integration.py -v
```

## CI/CDでの統合テスト

GitHub Actionsなどで統合テストを実行する場合:

```yaml
name: Integration Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v3

      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.11'

      - name: Install uv
        run: curl -LsSf https://astral.sh/uv/install.sh | sh

      - name: Install dependencies
        run: |
          cd backend
          uv sync

      - name: Start Firestore Emulator
        run: |
          npm install -g firebase-tools
          firebase emulators:start --only firestore &
          sleep 5

      - name: Run integration tests
        env:
          FIRESTORE_EMULATOR_HOST: localhost:8080
        run: |
          cd backend
          uv run pytest tests/test_pops_integration.py -v
```

## ベストプラクティス

1. **テスト用プロジェクトを使用**
   - 本番Firebaseプロジェクトでテストを実行しない
   - `poplink-dev`や`poplink-test`など専用プロジェクトを作成

2. **ローカルエミュレータを優先**
   - コストゼロ
   - 高速
   - データ汚染のリスクなし

3. **テストデータのクリーンアップ**
   - 必ず`teardown`でテストデータを削除
   - テスト失敗時でもクリーンアップされるように実装

4. **並列実行を避ける**
   - Firestoreの整合性を保つため、統合テストは順次実行

5. **適切なタイムアウト設定**
   - ネットワーク遅延を考慮してタイムアウトを設定
   - `pytest.ini`で設定可能
