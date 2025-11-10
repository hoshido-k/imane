# 通知配信クイックテストガイド

フレンドが作成したスケジュールの通知が届くかを簡単にテストする方法

## 最も簡単な方法：テスト用エンドポイントを使う

### 前提条件
- バックエンドサーバーが起動している
- スケジュールが作成済み

### ステップ1: スケジュールIDを確認

モバイルアプリの「フレンドが作成」タブで、スケジュールIDを確認します。
または、APIで取得：

```bash
# ログイン
curl -X POST http://localhost:8000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "your-email@example.com",
    "password": "your-password"
  }'

# アクセストークンを取得
# レスポンスの "access_token" をコピー

# 自分が作成したスケジュールを確認
TOKEN="<your-access-token>"
curl -X GET http://localhost:8000/api/v1/schedules \
  -H "Authorization: Bearer $TOKEN"
```

### ステップ2: テスト通知を送信

```bash
# スケジュールIDを指定して、到着通知をテスト送信
SCHEDULE_ID="<schedule-id>"
TOKEN="<your-access-token>"

curl -X POST "http://localhost:8000/api/v1/schedules/$SCHEDULE_ID/test-arrival" \
  -H "Authorization: Bearer $TOKEN"
```

レスポンス例：
```json
{
  "message": "到着通知をテスト送信しました",
  "schedule_id": "abc123",
  "destination_name": "東京駅",
  "notify_to_user_ids": ["user-id-1", "user-id-2"],
  "notification_ids": ["notif-id-1", "notif-id-2"],
  "count": 2
}
```

### ステップ3: 通知を確認

#### 方法A: モバイルアプリで確認
- プッシュ通知が届くか確認
- 通知履歴に表示されるか確認

#### 方法B: APIで確認

```bash
# 通知先ユーザーでログイン
TOKEN2="<recipient-user-access-token>"

# 通知履歴を取得
curl -X GET http://localhost:8000/api/v1/notifications/history \
  -H "Authorization: Bearer $TOKEN2"

# 未読通知数を取得
curl -X GET http://localhost:8000/api/v1/notifications/unread-count \
  -H "Authorization: Bearer $TOKEN2"
```

## 通知が届かない場合のチェックリスト

### 1. FCMトークンが登録されているか確認

モバイルアプリでログインすると、自動的にFCMトークンが登録されます。
登録されていない場合は、以下のコマンドで手動登録：

```bash
curl -X POST http://localhost:8000/api/v1/notifications/fcm-token \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "fcm_token": "your-fcm-token-from-app"
  }'
```

### 2. スケジュールの設定を確認

```bash
# スケジュールの詳細を取得
curl -X GET "http://localhost:8000/api/v1/schedules/$SCHEDULE_ID" \
  -H "Authorization: Bearer $TOKEN"
```

確認事項：
- `notify_on_arrival`: true になっているか
- `notify_to_user_ids`: 通知先ユーザーIDが含まれているか
- `status`: "active" または "arrived" になっているか

### 3. バックエンドのログを確認

```bash
# バックエンドサーバーのログを確認
# ターミナルで以下のようなログが出力されているか確認

# 成功の場合
[INFO] 到着通知を送信: user-id-1 -> user-id-2
[INFO] FCM送信完了: 1/1 成功, 0 失敗

# 失敗の場合
[WARNING] ユーザー user-id-2 にFCMトークンが登録されていません
[ERROR] FCM送信エラー: ...
```

### 4. Firestoreのデータを確認

Firebase Consoleで以下を確認：

**usersコレクション**:
- `fcm_tokens` フィールドに値があるか

**schedulesコレクション**:
- スケジュールが存在するか
- `notify_to_user_ids` に通知先ユーザーIDが含まれているか

**notificationsコレクション**:
- 通知が保存されているか
- `user_id` が通知先ユーザーIDと一致しているか

**notification_historyコレクション**:
- 自動通知履歴が保存されているか
- `to_user_id` が通知先ユーザーIDと一致しているか

## 完全なテストフロー例

### シナリオ: ユーザーAがスケジュールを作成し、ユーザーBに通知

```bash
# ============================================
# ステップ1: ユーザーAでログイン
# ============================================
curl -X POST http://localhost:8000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "userA@example.com",
    "password": "password123"
  }' > /tmp/userA_login.json

# アクセストークンを取得
TOKEN_A=$(cat /tmp/userA_login.json | jq -r '.access_token')
USER_A_ID=$(cat /tmp/userA_login.json | jq -r '.user.uid')

echo "ユーザーA Token: $TOKEN_A"
echo "ユーザーA ID: $USER_A_ID"

# ============================================
# ステップ2: ユーザーBでログイン
# ============================================
curl -X POST http://localhost:8000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "userB@example.com",
    "password": "password123"
  }' > /tmp/userB_login.json

TOKEN_B=$(cat /tmp/userB_login.json | jq -r '.access_token')
USER_B_ID=$(cat /tmp/userB_login.json | jq -r '.user.uid')

echo "ユーザーB Token: $TOKEN_B"
echo "ユーザーB ID: $USER_B_ID"

# ============================================
# ステップ3: ユーザーBのFCMトークンを登録
# ============================================
curl -X POST http://localhost:8000/api/v1/notifications/fcm-token \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN_B" \
  -d '{
    "fcm_token": "test-fcm-token-userB"
  }'

# ============================================
# ステップ4: ユーザーAがスケジュールを作成（ユーザーBを通知先に設定）
# ============================================
curl -X POST http://localhost:8000/api/v1/schedules \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN_A" \
  -d "{
    \"destination_name\": \"渋谷駅\",
    \"destination_address\": \"東京都渋谷区道玄坂1丁目\",
    \"destination_coords\": {
      \"lat\": 35.658034,
      \"lng\": 139.701636
    },
    \"notify_to_user_ids\": [\"$USER_B_ID\"],
    \"start_time\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\",
    \"end_time\": \"$(date -u -d '+2 hours' +"%Y-%m-%dT%H:%M:%SZ")\",
    \"notify_on_arrival\": true,
    \"notify_after_minutes\": 60,
    \"notify_on_departure\": true
  }" > /tmp/schedule.json

SCHEDULE_ID=$(cat /tmp/schedule.json | jq -r '.id')
echo "スケジュールID: $SCHEDULE_ID"

# ============================================
# ステップ5: ユーザーBがフレンドのスケジュールを確認
# ============================================
curl -X GET http://localhost:8000/api/v1/schedules/friend-schedules \
  -H "Authorization: Bearer $TOKEN_B"

# ============================================
# ステップ6: テスト通知を送信
# ============================================
curl -X POST "http://localhost:8000/api/v1/schedules/$SCHEDULE_ID/test-arrival" \
  -H "Authorization: Bearer $TOKEN_A"

# ============================================
# ステップ7: ユーザーBの通知履歴を確認
# ============================================
curl -X GET http://localhost:8000/api/v1/notifications/history \
  -H "Authorization: Bearer $TOKEN_B"
```

## Pythonスクリプトでテスト

より詳細なテストが必要な場合は、Pythonスクリプトを使用：

```bash
cd backend
uv run python test_notification_delivery.py
```

このスクリプトは以下を自動実行します：
- ユーザーとFCMトークンの確認
- スケジュールの検索
- テスト通知の送信
- 通知履歴の確認
- トラブルシューティングのヒント表示

## よくある問題と解決方法

### Q: 通知が送信されたが、プッシュ通知が届かない

**A**: 以下を確認してください：
1. FCMトークンが正しく登録されているか（ダミートークンでは実際の通知は届かない）
2. モバイルアプリで通知許可が有効になっているか
3. Firebase Consoleで正しいサービスアカウントキーが設定されているか
4. iOS/Androidの通知設定が有効になっているか

### Q: 通知履歴に表示されない

**A**: 2つのコレクションを確認してください：
1. `notifications`: 通常の通知（`/api/v1/notifications/history`で取得）
2. `notification_history`: 自動通知履歴（24時間TTL）

Firestoreで直接確認することをお勧めします。

### Q: "FCMトークンが登録されていません"というエラー

**A**:
```bash
# FCMトークンを手動で登録
curl -X POST http://localhost:8000/api/v1/notifications/fcm-token \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "fcm_token": "your-fcm-token"
  }'
```

モバイルアプリでログインすると、自動的に登録されます。

### Q: "スケジュールが見つかりません"というエラー

**A**: スケジュールIDが正しいか確認してください。
自分が作成したスケジュールのみテスト通知を送信できます。

## まとめ

最も簡単な方法：
1. スケジュールを作成
2. `POST /api/v1/schedules/{schedule_id}/test-arrival` を呼び出し
3. モバイルアプリまたはAPIで通知を確認

これで、実際の位置情報を送らなくても通知の動作を確認できます！
