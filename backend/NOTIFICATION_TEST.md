# 通知配信テストガイド

このドキュメントでは、imaneアプリの通知配信機能をテストする方法を説明します。

## 前提条件

- バックエンドサーバーが起動していること (`uvicorn app.main:app --reload`)
- 少なくとも2人のユーザーがログインしていること
- FCMトークンが登録されていること

## テスト方法

### 方法1: Pythonスクリプトを使う（推奨）

最も簡単な方法は、用意したテストスクリプトを実行することです：

```bash
cd backend
uv run python test_notification_delivery.py
```

このスクリプトは以下のことを行います：
1. ユーザーとFCMトークンの確認
2. アクティブなスケジュールの検索
3. テスト通知の送信
4. 到着通知のシミュレート
5. 通知履歴の確認

### 方法2: APIエンドポイントを使う

#### ステップ1: ログインしてトークンを取得

```bash
# ユーザー1でログイン
curl -X POST http://localhost:8000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user1@example.com",
    "password": "password123"
  }'
```

レスポンスからアクセストークンを取得：
```json
{
  "access_token": "eyJ...",
  "token_type": "bearer",
  "user": {...}
}
```

#### ステップ2: FCMトークンを登録（モバイルアプリの代わり）

```bash
# テスト用のダミーFCMトークンを登録
TOKEN="eyJ..."  # 上記で取得したアクセストークン

curl -X POST http://localhost:8000/api/v1/notifications/fcm-token \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "fcm_token": "dummy-fcm-token-user1-device1"
  }'
```

#### ステップ3: スケジュールを作成

```bash
# ユーザー1がスケジュールを作成し、ユーザー2を通知先に設定
curl -X POST http://localhost:8000/api/v1/schedules \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "destination_name": "東京駅",
    "destination_address": "東京都千代田区丸の内1丁目",
    "destination_coords": {
      "lat": 35.681236,
      "lng": 139.767125
    },
    "notify_to_user_ids": ["<ユーザー2のUID>"],
    "start_time": "2025-11-10T10:00:00Z",
    "end_time": "2025-11-10T18:00:00Z",
    "notify_on_arrival": true,
    "notify_after_minutes": 60,
    "notify_on_departure": true
  }'
```

#### ステップ4: 位置情報を更新して通知をトリガー

```bash
# 目的地に到着（ジオフェンス内に位置情報を送信）
curl -X POST http://localhost:8000/api/v1/location/update \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "coords": {
      "lat": 35.681236,
      "lng": 139.767125
    },
    "accuracy": 10.0,
    "timestamp": "2025-11-10T12:00:00Z"
  }'
```

レスポンス例：
```json
{
  "message": "位置情報を記録しました。1件のジオフェンスイベントを処理しました。",
  "location_recorded": true,
  "triggered_notifications": [
    {
      "type": "arrival",
      "schedule_id": "xxx"
    }
  ],
  "schedule_updates": [...]
}
```

#### ステップ5: テスト通知を送信

最も簡単な方法は、テスト通知エンドポイントを使うことです：

```bash
# ユーザー2にテスト通知を送信
curl -X POST http://localhost:8000/api/v1/notifications/send-test \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "user_id": "<ユーザー2のUID>",
    "title": "テスト通知",
    "body": "これはimaneからのテスト通知です",
    "data": {
      "test": "true"
    }
  }'
```

#### ステップ6: 通知履歴を確認

```bash
# ユーザー2でログインして通知履歴を確認
TOKEN2="<ユーザー2のアクセストークン>"

# 通常の通知履歴
curl -X GET http://localhost:8000/api/v1/notifications/history \
  -H "Authorization: Bearer $TOKEN2"

# 未読通知数
curl -X GET http://localhost:8000/api/v1/notifications/unread-count \
  -H "Authorization: Bearer $TOKEN2"
```

### 方法3: モバイルアプリで確認

1. モバイルアプリでログイン
2. フレンドを追加
3. フレンドがスケジュールを作成し、自分を通知先に設定
4. フレンドが目的地に到着（位置情報を送信）
5. プッシュ通知が届くことを確認

## トラブルシューティング

### 通知が届かない場合

#### 1. FCMトークンが登録されているか確認

```bash
# Firestoreでユーザードキュメントを確認
# fcm_tokensフィールドに値があるか確認
```

#### 2. ログを確認

バックエンドのログで以下のメッセージを確認：
- `FCM送信完了: X/Y 成功, Z 失敗`
- `到着通知を送信: user_id -> user_id`
- `ユーザー XXX にFCMトークンが登録されていません`

#### 3. Firestore Indexを確認

通知履歴の検索には以下のインデックスが必要です：

**notificationsコレクション**:
- `user_id` (ASC) + `created_at` (DESC)
- `user_id` (ASC) + `is_read` (ASC)

**notification_historyコレクション**:
- `to_user_id` (ASC) + `sent_at` (DESC)
- `schedule_id` (ASC) + `type` (ASC)

インデックスがない場合、Firestoreのログに表示されるURLからインデックスを作成してください。

#### 4. 通知設定を確認

スケジュールの設定を確認：
- `notify_on_arrival`: true（到着通知を有効にする）
- `notify_on_departure`: true（退出通知を有効にする）
- `notify_to_user_ids`: 通知先ユーザーIDが正しく設定されているか

#### 5. ジオフェンスの範囲を確認

デフォルトのジオフェンス半径は50メートルです。位置情報が目的地から50m以内にあるか確認してください。

```python
# 2点間の距離を計算（Haversine formula）
from math import radians, sin, cos, sqrt, asin

def calculate_distance(lat1, lng1, lat2, lng2):
    EARTH_RADIUS = 6371000  # メートル

    lat1, lng1 = radians(lat1), radians(lng1)
    lat2, lng2 = radians(lat2), radians(lng2)

    dlat = lat2 - lat1
    dlng = lng2 - lng1

    a = sin(dlat / 2) ** 2 + cos(lat1) * cos(lat2) * sin(dlng / 2) ** 2
    c = 2 * asin(sqrt(a))

    return EARTH_RADIUS * c

# 使用例
distance = calculate_distance(35.681236, 139.767125, 35.681300, 139.767200)
print(f"距離: {distance:.1f}m")  # 50m以内ならOK
```

## 通知の仕組み

### 通知配信の流れ

1. **位置情報更新** (`/api/v1/location/update`)
   - ユーザーがバックグラウンドで10分ごとに位置情報を送信
   - `LocationService`が位置情報を記録

2. **ジオフェンスチェック** (`GeofencingService`)
   - アクティブなスケジュールを取得
   - 現在地と目的地の距離を計算
   - 50m以内なら「到着」、50m以上なら「退出」と判定

3. **自動通知送信** (`AutoNotificationService`)
   - 到着イベント → `send_arrival_notification()`
   - 滞在イベント → `send_stay_notification()`（バッチ処理）
   - 退出イベント → `send_departure_notification()`

4. **プッシュ通知** (`NotificationService`)
   - FCMでプッシュ通知を送信
   - Firestoreに通知履歴を保存（2箇所）
     - `notifications`: 通常の通知履歴
     - `notification_history`: 自動通知履歴（24時間TTL）

### 通知メッセージフォーマット

**到着通知**:
```
今ね、{ユーザー名}さんが{目的地名}へ到着したよ
到着時刻: {HH:MM}
ここにいるよ → [地図リンク]
```

**滞在通知**:
```
今ね、{ユーザー名}さんは{目的地名}に{X時間Y分}滞在しているよ
ここにいるよ → [地図リンク]
```

**退出通知**:
```
今ね、{ユーザー名}さんが{目的地名}から出発したよ
出発時刻: {HH:MM}
```

## デバッグのヒント

### ログレベルを上げる

```python
# app/main.py
import logging
logging.basicConfig(level=logging.DEBUG)
```

### Firestoreのデータを直接確認

Firebase Consoleで以下のコレクションを確認：
- `users`: FCMトークンが登録されているか
- `schedules`: スケジュールが正しく作成されているか
- `location_history`: 位置情報が記録されているか
- `notifications`: 通知が保存されているか
- `notification_history`: 自動通知履歴が保存されているか

### FCMの送信状況を確認

Firebase Console > Cloud Messaging で送信状況を確認できます。

## まとめ

通知が正しく配信されるためには、以下の条件を満たす必要があります：

1. ✅ FCMトークンが登録されている
2. ✅ スケジュールの`notify_to_user_ids`に通知先ユーザーIDが含まれている
3. ✅ スケジュールの通知設定が有効（`notify_on_arrival`など）
4. ✅ 位置情報が正しく送信されている
5. ✅ ジオフェンス内（目的地から50m以内）に位置している
6. ✅ スケジュールの時間枠内（`start_time`と`end_time`の間）
7. ✅ Firestoreのインデックスが作成されている

テストスクリプト（`test_notification_delivery.py`）を使うと、これらの条件を自動的にチェックできます。
