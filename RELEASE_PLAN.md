# imane リリース計画

**最終更新日**: 2025-11-04

---

## 🎯 リリース戦略

**段階的リリース → 継続的改善**

- Phase 1でMVP（最小限の自動通知機能）をリリース
- ユーザーフィードバックを受けながら機能拡張（Phase 2, 3）
- iOS優先、Android対応は Phase 3

---

## 📅 フェーズ別リリーススケジュール

### Phase 1: MVP版 🚀
**リリース予定**: 2025年1月中旬 - 2月中旬（10週間）
**ステータス**: 🔄 準備中

#### 実装する機能
- ✅ ユーザー認証（Firebase Auth + JWT）
- ✅ フレンド管理
- 🆕 位置情報スケジュール作成・編集・一覧
- 🆕 お気に入り場所管理
- 🆕 バックグラウンド位置情報トラッキング（10分間隔）
- 🆕 ジオフェンシング（50m圏内判定）
- 🆕 自動通知（到着・滞在・退出）
- 🆕 通知履歴表示（24時間）
- 🆕 24時間データ自動削除

#### 実装しない機能（後回し）
- ❌ スケジュール削除・キャンセル機能
- ❌ 繰り返しスケジュール
- ❌ 通知グループ設定
- ❌ LINE Messaging API統合
- ❌ Android対応
- ❌ 統計・ダッシュボード

#### 目的
「今ね、ここにいるよ」を自動で伝える最小限の機能を提供し、TestFlightでベータテスト実施

---

### Phase 2: 機能拡張
**リリース予定**: 2025年3月 - 4月（1〜2ヶ月）
**ステータス**: ⏳ 未着手

#### 追加機能
- スケジュールのキャンセル・一時停止
- 繰り返しスケジュール（毎日・平日・週末）
- 通知先グループ管理（「家族」「パートナー」など）
- LINE Messaging API統合
- 統計・ダッシュボード機能

---

### Phase 3: プラットフォーム拡大
**リリース予定**: 2025年5月 - 7月（2〜3ヶ月）
**ステータス**: ⏳ 未着手

#### 追加機能
- Android対応
- Apple Watch対応（オプション）
- PWA対応（オプション）

---

## 📋 Phase 1 詳細タスク（10週間）

### Week 1-2: バックエンド基盤構築

#### Week 1: Day 1-3 - クリーンアップ
**タスク:**
- [x] 不要ファイル削除
  - `backend/app/api/v1/pops.py`
  - `backend/app/api/v1/reactions.py`
  - `backend/app/schemas/pop.py`
  - `backend/app/schemas/reaction.py`
  - `backend/app/services/pops.py`
  - `backend/app/services/reactions.py`
- [x] `main.py` から pops, reactions ルーター削除
- [x] ドキュメント更新（README, CLAUDE.md）

**成果物:**
- ✅ クリーンなコードベース
- ✅ imane用に更新されたドキュメント

---

#### Week 1: Day 4-5 - スケジュール管理API
**タスク:**
- [x] `backend/app/schemas/schedule.py` 作成
  - LocationScheduleRequest
  - LocationScheduleResponse
  - ScheduleStatus enum
- [x] `backend/app/api/v1/schedules.py` 作成
  - POST /schedules - スケジュール作成
  - GET /schedules - 一覧取得
  - GET /schedules/{id} - 詳細取得
  - PUT /schedules/{id} - 更新
- [x] `backend/app/services/schedules.py` 作成
- [x] `main.py` にルーター追加

**成果物:**
- ✅ スケジュールCRUD API

---

#### Week 2: Day 1-2 - お気に入り場所API
**タスク:**
- [x] `backend/app/schemas/favorite.py` 作成
- [x] `backend/app/services/favorites.py` 作成
- [x] `backend/app/api/v1/favorites.py` 作成
  - POST /favorites - お気に入り追加
  - GET /favorites - 一覧取得
  - DELETE /favorites/{id} - 削除
- [x] `main.py` にルーター追加

**成果物:**
- ✅ お気に入り場所管理API

---

#### Week 2: Day 3-5 - 位置情報トラッキングAPI
**タスク:**
- [x] `backend/app/schemas/location.py` 作成
- [x] `backend/app/services/location.py` 作成
  - Haversine formula（距離計算）実装
  - 位置情報履歴記録・取得
  - 24時間自動削除機能
- [x] `backend/app/api/v1/location.py` 作成
  - POST /location/update - 位置情報送信
  - GET /location/status - 現在のステータス取得
- [x] `main.py` にルーター追加

**成果物:**
- ✅ 位置情報トラッキングAPI

---

### Week 3-4: ジオフェンシング・自動通知

#### Week 3: Day 1-3 - ジオフェンシングロジック
**タスク:**
- [x] `backend/app/services/geofencing.py` 作成
  - `calculate_distance()` - Haversine formula実装
  - `check_geofence_entry()` - 到着判定
  - `check_geofence_exit()` - 退出判定
  - `get_active_schedules()` - アクティブな予定取得
- [x] ユニットテスト作成

**成果物:**
- ✅ ジオフェンシングサービス

---

#### Week 3: Day 4-5 - 自動通知トリガー（到着・退出）
**タスク:**
- [x] `backend/app/services/auto_notification.py` 作成
  - `send_arrival_notification()` - 到着通知送信
  - `send_departure_notification()` - 退出通知送信
  - `send_fcm_notification()` - FCM送信ヘルパー（既存NotificationService活用）
- [x] 通知メッセージテンプレート作成（「今ね、」形式）

**成果物:**
- ✅ 到着・退出通知機能

---

#### Week 4: Day 1-2 - 滞在通知ロジック
**タスク:**
- [x] `send_stay_notification()` 実装
  - 1時間滞在判定
  - 滞在時間計算
- [x] バッチ処理用の `check_and_send_stay_notifications()` 実装

**成果物:**
- ✅ 滞在通知機能

---

#### Week 4: Day 3-5 - 位置情報更新処理統合
**タスク:**
- [x] POST /location/update エンドポイント拡張
  - 受信した位置情報でジオフェンス判定
  - ステータス更新（active → arrived → completed）
  - 自動通知トリガー呼び出し
- [x] 統合フロー実装

**成果物:**
- ✅ 位置情報更新時の自動通知フロー

---

### Week 5-6: iOS位置情報トラッキング

#### Week 5: Day 1-2 - iOS Background Location基盤
**タスク:**
- [x] `Info.plist` に権限設定追加
  - NSLocationAlwaysAndWhenInUseUsageDescription
  - NSLocationWhenInUseUsageDescription
  - UIBackgroundModes: location
- [x] `mobile/lib/services/location_service.dart` 作成
  - background_location パッケージ統合
  - 10分間隔の位置情報取得設定

**成果物:**
- ✅ バックグラウンド位置情報取得基盤

---

#### Week 5: Day 3-5 - 位置情報アップロード実装
**タスク:**
- [x] バックグラウンドで取得した位置情報をAPIに送信
- [x] エラーハンドリング（ネットワーク切断時のリトライ）
- [x] ローカルキャッシュ実装（オフライン対応）

**成果物:**
- ✅ 位置情報自動送信機能

---

#### Week 6: Day 1-3 - 権限リクエスト実装
**タスク:**
- [x] 初回起動時の権限リクエストフロー
- [x] 「Always Allow」への誘導UI
- [x] 権限拒否時のフォールバック処理

**成果物:**
- ✅ 位置情報権限管理UI

---

#### Week 6: Day 4-5 - 実機テスト
**タスク:**
- [ ] 実機でバックグラウンド動作確認
- [ ] バッテリー消費測定
- [ ] 位置情報精度確認

**成果物:**
- バックグラウンド位置情報トラッキング動作確認

---

### Week 7-8: Flutter UI実装

#### Week 7: Day 1-2 - スケジュール作成画面
**タスク:**
- [x] `mobile/lib/screens/schedule/create_schedule_screen.dart` 作成
  - 目的地入力フォーム
  - 地図選択（imane流用）
  - 時間範囲選択
  - お気に入りから選択機能

**成果物:**
- ✅ スケジュール作成画面

---

#### Week 7: Day 3-5 - フレンド選択・スケジュール一覧
**タスク:**
- [x] 通知先フレンド選択UI（TODO実装）
- [x] `mobile/lib/screens/schedule/schedule_list_screen.dart`
  - アクティブな予定一覧
  - ステータス表示（active/arrived/completed）
- [x] `mobile/lib/screens/schedule/schedule_detail_screen.dart`
  - スケジュール詳細表示
  - 地図表示・ジオフェンス可視化

**成果物:**
- ✅ スケジュール一覧・詳細画面

---

#### Week 8: Day 1-2 - お気に入り場所管理
**タスク:**
- [x] `mobile/lib/screens/favorites/favorites_screen.dart`
  - お気に入り一覧
  - 追加・削除機能

**成果物:**
- ✅ お気に入り場所管理画面

---

#### Week 8: Day 3-5 - 通知履歴画面
**タスク:**
- [x] `mobile/lib/screens/notification/notification_history_screen.dart`
  - 過去24時間の通知表示
  - 地図リンククリック対応

**成果物:**
- ✅ 通知履歴画面

---

### Week 9-10: テスト・デバッグ・リリース

#### Week 9: 統合テスト
**タスク:**
- [ ] エンドツーエンドテストシナリオ実行
  - スケジュール作成 → 到着 → 滞在 → 退出の全フロー
- [ ] エッジケーステスト
  - GPS精度が低い場所
  - 複数スケジュール同時アクティブ
  - ネットワーク切断時の動作
  - バックグラウンド位置情報取得の精度

**成果物:**
- テスト結果レポート

---

#### Week 10: Day 1-3 - バグ修正・最適化
**タスク:**
- [ ] Week 9 で発見されたバグ修正
- [ ] パフォーマンス最適化
- [ ] バッテリー消費の最適化

---

#### Week 10: Day 4-5 - リリース準備
**タスク:**
- [ ] App Store用スクリーンショット作成
- [ ] プライバシーポリシー作成
- [ ] App Store説明文作成
- [ ] TestFlight配信
- [ ] ベータテスター募集（5名）

**成果物:**
- TestFlightでのベータ版リリース

---

## 📊 工数見積もり

| フェーズ | 機能 | 工数 | リリース時期 | ステータス |
|---------|------|------|------------|-----------|
| Phase 1 | MVP | 10週間 | 2025年1-2月 | 🔄 準備中 |
| Phase 2 | 機能拡張 | 1-2ヶ月 | 2025年3-4月 | ⏳ 未着手 |
| Phase 3 | プラットフォーム拡大 | 2-3ヶ月 | 2025年5-7月 | ⏳ 未着手 |

**個人開発で完全に実現可能！**

---

## 🚨 Phase 1 での制限事項

App Store説明文またはアプリ内に以下を記載予定:

```
【現在の機能】
✅ 目的地を設定して自動通知
✅ 到着・滞在・退出の3種類の通知
✅ お気に入り場所の登録
✅ 通知履歴の確認（24時間）
✅ フレンドへの自動通知

【近日追加予定】
🔜 繰り返しスケジュール (Phase 2)
🔜 通知先グループ設定 (Phase 2)
🔜 LINE統合 (Phase 2)
🔜 Android対応 (Phase 3)
```

---

## 🎯 成功基準

### Phase 1 (MVP)
- [ ] TestFlightでベータ版公開
- [ ] 最低5名のテストユーザーが使用可能
- [ ] クリティカルなバグなし
- [ ] スケジュール作成・編集が正常に動作
- [ ] バックグラウンド位置情報トラッキングが動作
- [ ] 到着・滞在・退出の自動通知が正常に送信される
- [ ] 24時間データ自動削除が動作
- [ ] バッテリー消費が1日10%以内

### Phase 2
- [ ] 繰り返しスケジュールが正常に動作
- [ ] 通知先グループ設定が使いやすい
- [ ] LINE統合が動作（オプション）
- [ ] 既存機能に影響なし

### Phase 3
- [ ] Android版リリース
- [ ] iOS/Android間でデータ同期
- [ ] 全機能が統合された状態で安定動作

---

## 📝 進捗メモ

### 2025-11-04
- プロジェクト開始
- imaneコードベースからimane用にフォーク
- REQUIREMENTS.md作成完了
- RELEASE_PLAN.md作成完了
- Phase 1 (MVP) の開発計画策定
- 10週間でTestFlightリリース目標設定

**Week 1-2完了:**
- ✅ Week 1: Day 1-3 - クリーンアップ完了（不要ファイル削除、ドキュメント更新）
- ✅ Week 1: Day 4-5 - スケジュール管理API完了（CRUD実装）
- ✅ Week 2: Day 1-2 - お気に入り場所API完了
- ✅ Week 2: Day 3-5 - 位置情報トラッキングAPI完了（距離計算、24時間TTL実装）
- ✅ FIREBASE_SETUP.md を imane 用に更新（TTLポリシー設定追加）

**実装済みAPI:**
- `/api/v1/schedules` - スケジュール管理
- `/api/v1/favorites` - お気に入り場所管理
- `/api/v1/location` - 位置情報トラッキング
- `/api/v1/notifications` - 通知管理

**Week 3-4完了:**
- ✅ Week 3: Day 1-3 - ジオフェンシングロジック完了（geofencing.py実装）
- ✅ Week 3: Day 4-5 - 自動通知トリガー完了（auto_notification.py実装）
- ✅ Week 4: Day 1-2 - 滞在通知ロジック完了（バッチ処理実装）
- ✅ Week 4: Day 3-5 - 位置情報更新処理統合完了（location.py統合）

**実装済み機能:**
- ジオフェンシング判定（50m圏内検出）
- 到着・滞在・退出の3種類の自動通知
- 「今ね、」形式の通知メッセージ
- FCMプッシュ通知送信
- 通知履歴保存（24時間TTL）
- 位置情報更新時の自動通知フロー

**Week 5-6完了:**
- ✅ Week 5: Day 1-2 - iOS Background Location基盤完了
- ✅ Week 5: Day 3-5 - 位置情報アップロード実装完了
- ✅ Week 6: Day 1-3 - 権限リクエスト実装完了

**実装済み機能:**
- バックグラウンド位置情報トラッキング（10分間隔）
- Info.plistに位置情報権限設定追加
- location_service.dart作成（background_location統合）
- API送信機能（POST /location/update）
- ネットワーク切断時のリトライ処理
- オフライン対応ローカルキャッシュ（LocationCacheService）
- 初回起動時の権限リクエストフロー
- 「Always Allow」への誘導UI
- 権限拒否時のフォールバック処理

**Week 7-8完了:**
- ✅ Week 7: Day 1-2 - スケジュール作成画面完了
- ✅ Week 7: Day 3-5 - スケジュール一覧・詳細画面完了
- ✅ Week 8: Day 1-2 - お気に入り場所管理画面完了
- ✅ Week 8: Day 3-5 - 通知履歴画面完了

**実装済み画面:**
- スケジュール作成画面（create_schedule_screen.dart）
- スケジュール一覧画面（schedule_list_screen.dart）
- スケジュール詳細画面（schedule_detail_screen.dart）
- お気に入り場所管理画面（favorites_screen.dart）
- 通知履歴画面（notification_history_screen.dart）
- デバッグ画面（location_debug_screen.dart）
- main_screen.dart更新（imane用画面構成）

**実装済みモデル:**
- LocationSchedule（schedule.dart）
- FavoriteLocation（favorite_location.dart）
- NotificationHistory（notification_history.dart）

**次のステップ:** Week 9-10 テスト・デバッグ・リリース

---

## 🔧 開発環境セットアップ

Phase 1の開発を始める前に、以下のセットアップが必要:

### 必須ツール
- Python 3.11+（バックエンド）
- uv（Pythonパッケージマネージャー）
- Flutter 3.x（iOS開発）
- Xcode（iOS simulator & build）
- Firebase プロジェクト

### セットアップ手順
1. Firebaseプロジェクト作成 → [FIREBASE_SETUP.md](./FIREBASE_SETUP.md)（更新予定）
2. バックエンド依存関係インストール: `cd backend && uv sync`
3. フロントエンド依存関係インストール: `cd mobile && flutter pub get`
4. 環境変数設定: `backend/.env` ファイル作成
5. バックエンド起動: `uv run uvicorn app.main:app --reload`
6. Flutter起動: `flutter run`

---

## 📊 コスト見積もり（個人開発規模）

| サービス | 使用量（Phase 1） | 月額コスト |
|---------|-----------------|-----------|
| Firestore | 読取: 50,000 / 書込: 10,000 | **$0**（無料枠内） |
| Cloud Functions | 10,000回/月 | **$0** |
| Firebase Auth | 1,000ユーザー | **$0** |
| FCM | 無制限 | **$0** |
| Maps API | 5,000リクエスト | **$0** |

> ✅ **Phase 1は実質無料運用可能**

---

## 🔗 関連ドキュメント

- [プロジェクト概要](./README.md)
- [要件定義書](./REQUIREMENTS.md)
- [開発ガイドライン](./CLAUDE.md)
- [Firebase設定手順](./FIREBASE_SETUP.md)

---

**最終更新**: 2025-11-04
**Version**: 1.0.0
