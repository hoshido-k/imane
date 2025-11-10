#!/bin/bash

# シミュレーター用の簡単な通知テストスクリプト

set -e

# 色の定義
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=================================================="
echo "  imane 通知テスト（シミュレーター用）"
echo "=================================================="

# 設定（環境変数で上書き可能）
API_URL=${API_URL:-"http://localhost:8000"}
TEST2_EMAIL=${TEST2_EMAIL:-"test2@example.com"}
TEST2_PASSWORD=${TEST2_PASSWORD:-"password123"}
TEST3_EMAIL=${TEST3_EMAIL:-"test3@example.com"}
TEST3_PASSWORD=${TEST3_PASSWORD:-"password123"}

echo ""
echo "${YELLOW}[1] FCMトークンとスケジュールを確認中...${NC}"
cd "$(dirname "$0")"

if command -v uv &> /dev/null; then
  echo ""
  echo "--- FCMトークン確認 ---"
  uv run python check_user_fcm.py

  echo ""
  echo "--- スケジュール確認 ---"
  uv run python check_schedules.py
fi

echo ""
echo "${YELLOW}[2] test2ユーザーでログイン中...${NC}"

LOGIN_RESPONSE=$(curl -s -X POST "$API_URL/api/v1/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"email\": \"$TEST2_EMAIL\", \"password\": \"$TEST2_PASSWORD\"}")

TOKEN2=$(echo "$LOGIN_RESPONSE" | jq -r '.access_token')

if [ "$TOKEN2" = "null" ] || [ -z "$TOKEN2" ]; then
  echo "${RED}❌ test2のログインに失敗しました${NC}"
  echo "レスポンス: $LOGIN_RESPONSE"
  exit 1
fi

echo "${GREEN}✅ ログイン成功${NC}"
USER2_ID=$(echo "$LOGIN_RESPONSE" | jq -r '.user.uid')
echo "   UID: $USER2_ID"

echo ""
echo "${YELLOW}[3] test3ユーザーでログイン中...${NC}"

LOGIN_RESPONSE3=$(curl -s -X POST "$API_URL/api/v1/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"email\": \"$TEST3_EMAIL\", \"password\": \"$TEST3_PASSWORD\"}")

TOKEN3=$(echo "$LOGIN_RESPONSE3" | jq -r '.access_token')

if [ "$TOKEN3" = "null" ] || [ -z "$TOKEN3" ]; then
  echo "${RED}❌ test3のログインに失敗しました${NC}"
  echo "レスポンス: $LOGIN_RESPONSE3"
  exit 1
fi

echo "${GREEN}✅ ログイン成功${NC}"
USER3_ID=$(echo "$LOGIN_RESPONSE3" | jq -r '.user.uid')
echo "   UID: $USER3_ID"

echo ""
echo "${YELLOW}[4] test3のFCMトークンを確認中...${NC}"

# test3にダミーのFCMトークンを登録（まだ登録されていない場合）
FCM_RESPONSE=$(curl -s -X POST "$API_URL/api/v1/notifications/fcm-token" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN3" \
  -d '{"fcm_token": "simulator-test3-dummy-token"}')

echo "   レスポンス: $FCM_RESPONSE"

echo ""
echo "${YELLOW}[5] test2のスケジュールを取得中...${NC}"

SCHEDULES=$(curl -s -X GET "$API_URL/api/v1/schedules" \
  -H "Authorization: Bearer $TOKEN2")

SCHEDULE_COUNT=$(echo "$SCHEDULES" | jq '.schedules | length')
echo "   スケジュール数: $SCHEDULE_COUNT"

if [ "$SCHEDULE_COUNT" -eq 0 ]; then
  echo "${RED}❌ test2のスケジュールが見つかりません${NC}"
  echo ""
  echo "先にモバイルアプリで以下を行ってください："
  echo "1. test2ユーザーでログイン"
  echo "2. スケジュールを作成"
  echo "3. test3ユーザーを通知先に追加"
  exit 1
fi

# 最初のスケジュールを使用
SCHEDULE_ID=$(echo "$SCHEDULES" | jq -r '.schedules[0].id')
DESTINATION_NAME=$(echo "$SCHEDULES" | jq -r '.schedules[0].destination_name')
NOTIFY_TO=$(echo "$SCHEDULES" | jq -r '.schedules[0].notify_to_user_ids[]')

echo "${GREEN}✅ スケジュールを見つけました${NC}"
echo "   ID: $SCHEDULE_ID"
echo "   目的地: $DESTINATION_NAME"
echo "   通知先: $NOTIFY_TO"

# test3が通知先に含まれているか確認
if echo "$NOTIFY_TO" | grep -q "$USER3_ID"; then
  echo "${GREEN}   ✅ test3が通知先に含まれています${NC}"
else
  echo "${RED}   ❌ test3が通知先に含まれていません${NC}"
  echo ""
  echo "モバイルアプリでスケジュールを編集し、test3を通知先に追加してください。"
  exit 1
fi

echo ""
echo "${YELLOW}[6] テスト通知を送信中...${NC}"

NOTIFICATION_RESPONSE=$(curl -s -X POST "$API_URL/api/v1/schedules/$SCHEDULE_ID/test-arrival" \
  -H "Authorization: Bearer $TOKEN2")

echo "$NOTIFICATION_RESPONSE" | jq

NOTIFICATION_COUNT=$(echo "$NOTIFICATION_RESPONSE" | jq -r '.count')

if [ "$NOTIFICATION_COUNT" -gt 0 ]; then
  echo "${GREEN}✅ 通知を${NOTIFICATION_COUNT}件送信しました${NC}"
else
  echo "${RED}❌ 通知の送信に失敗しました${NC}"
  exit 1
fi

echo ""
echo "${YELLOW}[7] test3の通知履歴を確認中...${NC}"

sleep 1  # 少し待つ

HISTORY=$(curl -s -X GET "$API_URL/api/v1/notifications/history" \
  -H "Authorization: Bearer $TOKEN3")

HISTORY_COUNT=$(echo "$HISTORY" | jq '.notifications | length')
echo "   通知履歴: ${HISTORY_COUNT}件"

if [ "$HISTORY_COUNT" -gt 0 ]; then
  echo "${GREEN}✅ 通知履歴に記録されています${NC}"
  echo ""
  echo "最新の通知:"
  echo "$HISTORY" | jq '.notifications[0] | {title, body, created_at}'
else
  echo "${RED}❌ 通知履歴が見つかりません${NC}"
fi

echo ""
echo "=================================================="
echo "  テスト完了"
echo "=================================================="
echo ""
echo "${YELLOW}【重要】シミュレーターの制限${NC}"
echo "✅ 通知履歴には保存されます"
echo "✅ APIは正常に動作します"
echo "❌ 実際のプッシュ通知は届きません（シミュレーターの制限）"
echo ""
echo "実際のプッシュ通知を確認するには、実機でテストしてください。"
echo ""
