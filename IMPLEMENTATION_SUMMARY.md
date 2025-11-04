# imane Week 3-4 実装完了サマリー

## 実装完了機能

### 1. ジオフェンシング機能（`app/services/geofencing.py`）

**主要機能:**
- Haversine formulaを使用した高精度な距離計算
- ジオフェンス侵入検出（到着判定）- 50m半径
- ジオフェンス退出検出（退出判定）
- スケジュールステータスの自動更新（active → arrived → completed）
- 複数スケジュールの同時処理対応

**エンドポイント:**
- 位置情報更新時に自動的に呼び出される（`/api/v1/location/update`）

### 2. 自動通知機能（`app/services/auto_notification.py`）

**通知タイプ:**
1. **到着通知** - ジオフェンス侵入時
   ```
   今ね、{ユーザー名}さんが{目的地名}へ到着したよ
   到着時刻: {HH:MM}
   ここにいるよ → [Google Maps リンク]
   ```

2. **滞在通知** - 60分滞在後
   ```
   今ね、{ユーザー名}さんは{目的地名}に{X時間Y分}滞在しているよ
   ここにいるよ → [Google Maps リンク]
   ```

3. **退出通知** - ジオフェンス退出時
   ```
   今ね、{ユーザー名}さんが{目的地名}から出発したよ
   出発時刻: {HH:MM}
   ```

**特徴:**
- Firebase Cloud Messaging（FCM）でプッシュ通知送信
- 通知履歴を24時間TTL付きでFirestoreに保存
- 重複送信防止機能

### 3. バッチ処理機能（`app/services/cleanup.py`、`app/api/v1/batch.py`）

**実装されたバッチ処理:**

#### a. 滞在通知の自動送信
- **エンドポイント**: `POST /api/v1/batch/stay-notifications`
- **実行頻度**: 5分毎（推奨）
- **処理内容**:
  - arrived状態のスケジュールを全て取得
  - 滞在時間が60分に達したものに通知を送信
  - 重複送信を防止（通知履歴チェック）

#### b. 期限切れデータの自動削除
- **エンドポイント**: `POST /api/v1/batch/cleanup`
- **実行頻度**: 1時間毎（推奨）
- **削除対象**:
  - 24時間以上経過した位置情報履歴
  - 24時間以上経過した通知履歴
  - 終了から24時間以上経過したスケジュール
  - 関連データも連鎖削除

#### c. 期限切れスケジュールのステータス更新
- **エンドポイント**: `POST /api/v1/batch/update-expired-schedules`
- **実行頻度**: 10分毎（推奨）
- **処理内容**: 終了時刻を過ぎたスケジュールのステータスをEXPIREDに更新

#### d. クリーンアップ統計情報
- **エンドポイント**: `GET /api/v1/batch/cleanup-stats`
- **処理内容**: 削除対象データの件数を確認

#### e. 全バッチ処理の一括実行
- **エンドポイント**: `POST /api/v1/batch/run-all`
- **用途**: 開発・テスト用（本番では個別にスケジュール推奨）

### 4. データ構造

#### 通知履歴（notification_history コレクション）
```json
{
  "id": "auto-generated",
  "from_user_id": "user_123",
  "to_user_id": "friend_1",
  "schedule_id": "schedule_123",
  "type": "arrival|stay|departure",
  "message": "今ね、田中さんが渋谷駅へ到着したよ",
  "map_link": "https://www.google.com/maps?q=35.658,139.7016",
  "sent_at": "2025-01-15T14:00:00Z",
  "auto_delete_at": "2025-01-16T14:00:00Z"
}
```

## テストコード

### ユニットテスト
1. **test_geofencing.py** - ジオフェンシングロジック（13テストケース）
2. **test_auto_notification.py** - 自動通知機能（14テストケース）
3. **test_batch_processing.py** - バッチ処理機能（10テストケース）

### 統合テスト
1. **test_location_tracking_integration.py** - 位置情報トラッキングの統合テスト
   - 位置情報記録
   - ジオフェンス検出
   - 自動通知送信
   - 複数スケジュール処理

### テスト実行方法
```bash
cd backend

# 全テスト実行
uv run pytest

# 特定のテストファイルのみ実行
uv run pytest tests/test_geofencing.py -v
uv run pytest tests/test_auto_notification.py -v
uv run pytest tests/test_batch_processing.py -v
uv run pytest tests/test_location_tracking_integration.py -v
```

## API仕様

### 位置情報更新（既存APIを拡張）
**エンドポイント**: `POST /api/v1/location/update`

**リクエスト**:
```json
{
  "coords": {
    "lat": 35.6580,
    "lng": 139.7016
  },
  "accuracy": 10.0,
  "recorded_at": "2025-01-15T14:00:00Z"
}
```

**レスポンス**:
```json
{
  "message": "位置情報を記録しました。2件のジオフェンスイベントを処理しました。",
  "location_recorded": true,
  "triggered_notifications": [
    {
      "type": "arrival",
      "schedule_id": "schedule_123"
    }
  ],
  "schedule_updates": [
    {
      "schedule_id": "schedule_123",
      "destination_name": "渋谷駅",
      "event_type": "entry",
      "distance": 25.3,
      "status": "arrived",
      "notification_ids": ["notif_1", "notif_2"]
    }
  ]
}
```

## 設定ファイル（.env）

新しく追加された設定項目：

```env
# 位置情報設定
GEOFENCE_RADIUS_METERS=50
LOCATION_UPDATE_INTERVAL_MINUTES=10
DATA_RETENTION_HOURS=24

# 通知設定
NOTIFICATION_STAY_DURATION_MINUTES=60

# バッチ処理設定（本番環境では必須）
BATCH_TOKEN=your-secure-batch-token-here
```

## 本番環境へのデプロイ推奨事項

### 1. Cloud Functionsでバッチ処理をスケジュール

**Google Cloud Scheduler + Cloud Functions の例:**

```yaml
# 滞在通知送信（5分毎）
- name: stay-notifications
  schedule: "*/5 * * * *"
  url: https://your-api.com/api/v1/batch/stay-notifications
  headers:
    X-Batch-Token: ${BATCH_TOKEN}

# データクリーンアップ（1時間毎）
- name: cleanup
  schedule: "0 * * * *"
  url: https://your-api.com/api/v1/batch/cleanup
  headers:
    X-Batch-Token: ${BATCH_TOKEN}

# 期限切れスケジュール更新（10分毎）
- name: update-expired
  schedule: "*/10 * * * *"
  url: https://your-api.com/api/v1/batch/update-expired-schedules
  headers:
    X-Batch-Token: ${BATCH_TOKEN}
```

### 2. Firestore複合インデックスの作成

以下のクエリで複合インデックスが必要：

```
schedules:
  - status, end_time
  - user_id, status, start_time

location_history:
  - user_id, recorded_at
  - schedule_id, auto_delete_at

notification_history:
  - schedule_id, type
  - auto_delete_at
```

### 3. セキュリティ設定

- `BATCH_TOKEN`を環境変数に設定
- バッチAPIエンドポイントへのアクセス制限（IP制限推奨）
- CORS設定を適切に制限

## アーキテクチャ図

```
┌─────────────────┐
│  Flutter App    │ 10分毎に位置情報送信
│   (iOS/Android) │
└────────┬────────┘
         │ POST /api/v1/location/update
         ▼
┌─────────────────────────────────────┐
│  FastAPI Backend                     │
│  ┌──────────────────────────────┐   │
│  │ LocationService              │   │
│  │ - 位置情報を記録              │   │
│  └────────┬─────────────────────┘   │
│           │                          │
│           ▼                          │
│  ┌──────────────────────────────┐   │
│  │ GeofencingService            │   │
│  │ - ジオフェンス判定            │   │
│  │ - スケジュールステータス更新   │   │
│  └────────┬─────────────────────┘   │
│           │ イベント発生             │
│           ▼                          │
│  ┌──────────────────────────────┐   │
│  │ AutoNotificationService      │   │
│  │ - FCM通知送信                 │   │
│  │ - 通知履歴保存（24h TTL）      │   │
│  └──────────────────────────────┘   │
└─────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────┐
│  Firestore                           │
│  - schedules                         │
│  - location_history (24h TTL)        │
│  - notification_history (24h TTL)    │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│  Cloud Scheduler (本番環境)           │
│  ┌──────────────────────────────┐   │
│  │ 5分毎:                        │   │
│  │ POST /api/v1/batch/           │   │
│  │      stay-notifications       │   │
│  ├──────────────────────────────┤   │
│  │ 10分毎:                       │   │
│  │ POST /api/v1/batch/           │   │
│  │      update-expired-schedules │   │
│  ├──────────────────────────────┤   │
│  │ 1時間毎:                      │   │
│  │ POST /api/v1/batch/cleanup    │   │
│  └──────────────────────────────┘   │
└─────────────────────────────────────┘
```

## パフォーマンス最適化のヒント

1. **Firestoreクエリの最適化**
   - 複合インデックスを適切に設定
   - バッチ処理では`.limit()`を使用

2. **FCM送信の最適化**
   - `MulticastMessage`で複数デバイスに一括送信
   - 無効なトークンは自動削除

3. **位置情報更新の最適化**
   - 10分間隔（バッテリー消費とリアルタイム性のバランス）
   - GPS精度が低い場合は更新をスキップ可能

4. **データクリーンアップ**
   - バッチ削除で`.limit(100)`を使用
   - 大量削除時はバッチ書き込みを使用

## 次のステップ（Phase 2）

1. **繰り返しスケジュール機能**
   - 日次、平日、週末の繰り返し
   - 次回スケジュールの自動作成

2. **LINE Messaging API統合**
   - FCMに加えてLINEでも通知送信

3. **統計ダッシュボード**
   - 位置情報トラッキング統計
   - 通知送信レポート

4. **Android対応**
   - Android Background Location API対応

5. **Apple Watch対応**
   - コンパニオンアプリ開発

## トラブルシューティング

### 通知が送信されない
1. FCMトークンが登録されているか確認
2. ジオフェンス半径内にいるか確認
3. スケジュールの時間枠内か確認
4. 通知設定（notify_on_arrival等）が有効か確認

### ジオフェンスが反応しない
1. GPS精度が50m以内か確認
2. 前回の位置情報が記録されているか確認
3. スケジュールがACTIVE状態か確認

### データが削除されない
1. バッチ処理が正しくスケジュールされているか確認
2. `auto_delete_at`フィールドが正しく設定されているか確認
3. Firestoreインデックスが作成されているか確認

## まとめ

Week 3-4の実装により、imaneアプリの核心機能であるジオフェンシングベースの自動通知システムが完成しました。

**実装された主要機能:**
- ✅ 高精度なジオフェンス検出（到着・退出）
- ✅ 「今ね、」形式の自動通知（到着・滞在・退出）
- ✅ 24時間TTL付きデータ管理
- ✅ バッチ処理システム
- ✅ 包括的なテストスイート

これらの機能により、ユーザーは位置情報を手動で送信することなく、大切な人に自動的に現在地を通知できるようになります。
