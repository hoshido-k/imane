# シミュレーターでの通知テストガイド

シミュレーター端末では実際の位置情報が取得できないため、通知のテストには特別な手順が必要です。

## 問題の原因

シミュレーターで通知が届かない主な原因：

1. **位置情報が取得できない**
   - シミュレーターでは実際のGPS位置情報が取得できません
   - デフォルトの位置情報（例：Apple本社）が返される場合があります

2. **FCMトークンの問題**
   - シミュレーターではFCMプッシュ通知が届きません
   - ただし、通知履歴には保存されます

3. **バックグラウンド実行の制限**
   - シミュレーターではバックグラウンドでの位置情報更新が制限される場合があります

## 解決方法

### 方法1: テストAPIを使う（推奨）

実際の位置情報を送らずに通知をテストできます。

#### ステップ1: ユーザー情報を確認

```bash
cd backend

# FCMトークンの登録状況を確認
uv run python check_user_fcm.py

# スケジュールの登録状況を確認
uv run python check_schedules.py
```

#### ステップ2: test2ユーザーでログイン（モバイルアプリ）

モバイルアプリでtest2ユーザーでログインします。

#### ステップ3: test3ユーザーを通知先にしたスケジュールを作成

モバイルアプリでスケジュールを作成し、test3ユーザーを通知先に追加します。

#### ステップ4: スケジュールIDを取得

モバイルアプリで作成したスケジュールのIDをメモするか、APIで取得：

```bash
# test2ユーザーのアクセストークンを取得
curl -X POST http://localhost:8000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test2@example.com",
    "password": "password"
  }' | jq -r '.access_token'

# アクセストークンをコピーして環境変数に設定
TOKEN="<test2のアクセストークン>"

# スケジュール一覧を取得
curl -X GET http://localhost:8000/api/v1/schedules \
  -H "Authorization: Bearer $TOKEN" | jq

# スケジュールIDをメモ
SCHEDULE_ID="<スケジュールID>"
```

#### ステップ5: テスト通知を送信

```bash
# 到着通知をテスト送信
curl -X POST "http://localhost:8000/api/v1/schedules/$SCHEDULE_ID/test-arrival" \
  -H "Authorization: Bearer $TOKEN"
```

レスポンス例：
```json
{
  "message": "到着通知をテスト送信しました",
  "schedule_id": "xxx",
  "destination_name": "渋谷駅",
  "notify_to_user_ids": ["test3のUID"],
  "notification_ids": ["notif-id-1"],
  "count": 1
}
```

#### ステップ6: test3ユーザーで通知を確認

```bash
# test3ユーザーでログイン
curl -X POST http://localhost:8000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test3@example.com",
    "password": "password"
  }' | jq -r '.access_token'

TOKEN3="<test3のアクセストークン>"

# 通知履歴を確認
curl -X GET http://localhost:8000/api/v1/notifications/history \
  -H "Authorization: Bearer $TOKEN3" | jq
```

### 方法2: Xcodeでシミュレーターの位置情報を設定

1. **Xcodeでシミュレーターを起動**

2. **シミュレーターのメニューから位置情報を設定**
   - メニュー: `Features` > `Location` > `Custom Location...`
   - 目的地の緯度経度を入力

3. **モバイルアプリで位置情報更新を実行**
   - ただし、シミュレーターではバックグラウンド実行が制限されます
   - フォアグラウンドで手動更新が必要な場合があります

### 方法3: 実機でテスト

最も確実な方法は実機でテストすることです：

1. **iPhoneをMacに接続**
2. **Xcodeでビルド先を実機に変更**
3. **アプリをビルド・実行**
4. **実際に目的地に移動（または近くまで移動）**
5. **通知が届くことを確認**

## シミュレーターでFCMトークンが登録されない場合

シミュレーターでは実際のプッシュ通知は届きませんが、通知履歴には保存されます。

### FCMトークンを手動で登録（ダミー）

```bash
# test3ユーザーでログイン
TOKEN3="<test3のアクセストークン>"

# ダミーのFCMトークンを登録
curl -X POST http://localhost:8000/api/v1/notifications/fcm-token \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN3" \
  -d '{
    "fcm_token": "simulator-test3-dummy-token"
  }'
```

**注意**: ダミートークンでは実際のプッシュ通知は届きませんが、以下は確認できます：
- 通知履歴に保存されるか
- 通知APIが正しく動作するか
- 通知メッセージの内容

## トラブルシューティング

### Q: test-arrivalエンドポイントで通知が送信されない

**A**: 以下を確認してください：

1. **スケジュールの通知設定**
   ```bash
   curl -X GET "http://localhost:8000/api/v1/schedules/$SCHEDULE_ID" \
     -H "Authorization: Bearer $TOKEN" | jq
   ```
   - `notify_on_arrival` が `true` になっているか
   - `notify_to_user_ids` に test3のUIDが含まれているか

2. **test3ユーザーのFCMトークン**
   ```bash
   uv run python check_user_fcm.py
   ```
   - FCMトークンが登録されているか（未登録でもDBには保存される）

3. **バックエンドのログを確認**
   ```
   [INFO] 到着通知を送信: test2-uid -> test3-uid
   [INFO] FCM送信完了: 1/1 成功, 0 失敗
   ```
   または
   ```
   [WARNING] ユーザー test3-uid にFCMトークンが登録されていません
   ```

4. **Firestoreで直接確認**
   - Firebase Console > Firestore Database
   - `notifications` コレクション: 通知が保存されているか
   - `notification_history` コレクション: 通知履歴が保存されているか

### Q: バックグラウンドで位置情報が更新されない

**A**: シミュレーターではバックグラウンド実行に制限があります。以下を試してください：

1. **フォアグラウンドで手動更新**
   - アプリを開いた状態で位置情報更新ボタンをタップ

2. **テストAPIを使用**
   - `POST /api/v1/schedules/{schedule_id}/test-arrival`

3. **実機でテスト**
   - 最も確実です

### Q: 通知履歴には表示されるがプッシュ通知が届かない

**A**: これは正常です。シミュレーターでは以下の理由でプッシュ通知が届きません：

1. **FCMのシミュレーターサポート**
   - iOS シミュレーターではプッシュ通知がサポートされていません
   - 実機でテストする必要があります

2. **確認できること**
   - 通知がFirestoreに保存されるか
   - 通知メッセージの内容が正しいか
   - APIが正しく動作するか

3. **実際のプッシュ通知を確認するには**
   - 実機でテストしてください

## まとめ

### シミュレーターでできること
✅ 通知がFirestoreに保存されることを確認
✅ 通知履歴APIで通知を取得
✅ テストAPIで通知送信ロジックを確認
✅ 通知メッセージの内容を確認

### シミュレーターでできないこと
❌ 実際のプッシュ通知を受信
❌ バックグラウンドでの位置情報更新（制限あり）
❌ 実際の位置情報に基づくジオフェンス判定

### 推奨テスト方法

**開発中（デスク作業）**:
- テストAPI（`test-arrival`）を使用
- 通知履歴APIで確認

**実機テスト（外出時）**:
- 実際に目的地に移動
- プッシュ通知を確認
- バックグラウンド動作を確認

## クイックテストコマンド

全てを一度に確認するスクリプト：

```bash
#!/bin/bash

# 設定
TEST2_EMAIL="test2@example.com"
TEST2_PASSWORD="password"
TEST3_EMAIL="test3@example.com"
TEST3_PASSWORD="password"

echo "=== 1. FCMトークン確認 ==="
cd backend
uv run python check_user_fcm.py

echo -e "\n=== 2. スケジュール確認 ==="
uv run python check_schedules.py

echo -e "\n=== 3. test2でログイン ==="
TOKEN2=$(curl -s -X POST http://localhost:8000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d "{\"email\": \"$TEST2_EMAIL\", \"password\": \"$TEST2_PASSWORD\"}" \
  | jq -r '.access_token')

echo "Token: $TOKEN2"

echo -e "\n=== 4. test2のスケジュール取得 ==="
SCHEDULES=$(curl -s -X GET http://localhost:8000/api/v1/schedules \
  -H "Authorization: Bearer $TOKEN2")

echo "$SCHEDULES" | jq

SCHEDULE_ID=$(echo "$SCHEDULES" | jq -r '.schedules[0].id')
echo "最初のスケジュールID: $SCHEDULE_ID"

if [ "$SCHEDULE_ID" != "null" ] && [ -n "$SCHEDULE_ID" ]; then
  echo -e "\n=== 5. テスト通知送信 ==="
  curl -X POST "http://localhost:8000/api/v1/schedules/$SCHEDULE_ID/test-arrival" \
    -H "Authorization: Bearer $TOKEN2" | jq

  echo -e "\n=== 6. test3でログイン ==="
  TOKEN3=$(curl -s -X POST http://localhost:8000/api/v1/auth/login \
    -H "Content-Type: application/json" \
    -d "{\"email\": \"$TEST3_EMAIL\", \"password\": \"$TEST3_PASSWORD\"}" \
    | jq -r '.access_token')

  echo -e "\n=== 7. test3の通知履歴確認 ==="
  curl -X GET http://localhost:8000/api/v1/notifications/history \
    -H "Authorization: Bearer $TOKEN3" | jq
else
  echo "スケジュールが見つかりません。先にスケジュールを作成してください。"
fi
```

このスクリプトを `test_notification.sh` として保存して実行：
```bash
chmod +x test_notification.sh
./test_notification.sh
```
