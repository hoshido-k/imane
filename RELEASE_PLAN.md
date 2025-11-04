# PopLink リリース計画

**最終更新日**: 2025-11-02

---

## 🎯 リリース戦略

**早期リリース → 継続的アップデート**

- 最小限の機能で早くリリースし、実績を作る
- ユーザーフィードバックを受けながら段階的に機能追加
- 2週間ごとのリリースサイクルで継続的に価値提供

---

## 📅 バージョン別リリーススケジュール

### v1.0.0 - 超MVP版 🚀
**リリース予定**: 2025/11/11 - 11/15
**ステータス**: 🔄 準備中

#### 実装する機能
- ✅ 簡易ログイン（メールアドレスのみ）
- ✅ 地図表示 + 現在位置
- ✅ ポップ投稿（テキスト + カテゴリ + 有効期限）
- ✅ ポップ一覧表示・詳細表示
- ✅ カテゴリフィルター

#### 実装しない機能（後回し）
- ❌ リアクション機能
- ❌ チャット機能
- ❌ フレンド機能
- ❌ Google認証
- ❌ プロフィール編集
- ❌ プッシュ通知

#### 目的
「地図上にポップを投稿・閲覧できる」という最小限の価値提供で、リリース実績を作る

---

### v1.1.0 - リアクション機能追加
**リリース予定**: 2025/11/25 - 11/29
**ステータス**: ⏳ 未着手

#### 追加機能
- リアクション送信・受信
- リアクション一覧画面
- 未読バッジ表示
- リアクション承認・拒否

---

### v1.2.0 - チャット機能追加
**リリース予定**: 2025/12/09 - 12/13
**ステータス**: ⏳ 未着手

#### 追加機能
- 1対1チャット
- メッセージ送受信
- チャット一覧
- 未読メッセージ表示

---

### v1.3.0 - ソーシャル機能追加
**リリース予定**: 2025/12/16 - 12/27
**ステータス**: ⏳ 未着手

#### 追加機能
- フレンド機能
- プロフィール編集
- Google認証
- プッシュ通知

---

## 📋 v1.0.0 詳細タスク

### Week 1: 11/5(火) - 11/8(金) - 基盤構築
**※11/3(日)文化の日、11/4(月)振替休日のため、11/5(火)スタート**

#### 11/5(火): 簡易認証の実装 ✅ **完了**
- [x] Firebase基盤セットアップ（10/29完了済み）
- [x] .env設定、serviceAccountKey.json配置（10/29完了済み）
- [x] Firestore有効化（10/29完了済み）
- [x] backend/app/main.py:22 のFirebase初期化有効化済み
- [x] バックエンドのFirebase接続確認（11/2完了）
- [x] 簡易認証の実装（メール + パスワード）（11/2完了）
- [x] トークン保存・自動ログイン機能（11/2完了）
- [x] 新規登録・ログイン・ログアウト動作確認（11/2完了）

**🎉 11/2に完了！予定より3日前倒し！**

---

#### 11/6(水): 簡易認証完成 & API連携基盤
- [ ] メールアドレスのみの簡易ログイン実装完了
  - パスワードは自動生成 or 固定値でOK
- [ ] トークン保存・自動ログイン機能
- [ ] `mobile/lib/services/api_service.dart` 作成開始

**担当**:
- Backend: `backend/app/api/v1/auth.py`
- Frontend: `mobile/lib/screens/auth/login_screen.dart:26`

---

#### 11/7(木): API連携基盤完成 & 認証フロー統合
- [ ] `mobile/lib/services/auth_service.dart` 作成
- [ ] Provider状態管理セットアップ
- [ ] HTTP通信の基本エラーハンドリング
- [ ] 認証APIとFlutterの連携確認

**新規作成ファイル**:
- `mobile/lib/services/api_service.dart`
- `mobile/lib/services/auth_service.dart`
- `mobile/lib/providers/auth_provider.dart`

---

#### 11/8(金): 位置情報 & Week 1 統合テスト
- [ ] 実際の位置情報取得実装（東京駅固定から変更）
- [ ] 位置情報権限処理（iOS/Android）
- [ ] 地図の現在位置表示
- [ ] 位置情報エラーハンドリング
- [ ] Week 1 統合確認

**担当**: `mobile/lib/screens/map/map_screen.dart:487-534`

---

### Week 2: 11/11(月) - 11/15(金) - ポップ機能

#### 11/11(月): ポップ投稿画面
- [ ] ポップ投稿画面UI作成
- [ ] カテゴリ選択UI
- [ ] 有効期限選択UI（15分/30分/60分）
- [ ] 投稿ボタンとバリデーション

**新規作成ファイル**:
- `mobile/lib/screens/pop/create_pop_screen.dart`

---

#### 11/12(火): ポップAPI連携
- [ ] `mobile/lib/services/pop_service.dart` 作成
- [ ] ポップ作成APIとの連携
- [ ] ポップ検索APIとの連携（位置情報ベース）
- [ ] ポップ詳細取得APIとの連携

**新規作成ファイル**:
- `mobile/lib/services/pop_service.dart`
- `mobile/lib/providers/pop_provider.dart`

---

#### 11/13(水): 地図表示統合
- [ ] モックデータから実データへ切り替え
- [ ] カテゴリフィルター動作確認
- [ ] ポップ詳細表示の実データ連携
- [ ] ポップのリアルタイム更新（最小限）

**担当**: `mobile/lib/screens/map/map_screen.dart:38-117` のモックデータ削除

---

#### 11/14(木): テスト & デバッグ
- [ ] エラーハンドリング追加
- [ ] ローディング表示実装
- [ ] UI/UX調整
- [ ] エッジケース対応
- [ ] 統合テスト

---

#### 11/15(金): v1.0.0 リリース準備
- [ ] 最終テスト
- [ ] リリースノート作成
- [ ] ストア申請準備（iOS/Android）
- [ ] **🚀 v1.0.0 リリース**

---

## 📊 工数見積もり

| バージョン | 機能 | 工数 | リリース週 | ステータス |
|-----------|------|------|-----------|-----------|
| v1.0.0 | 超MVP | 8-10日 | 11/11-11/15 | 🔄 準備中 |
| v1.1.0 | リアクション | 4-5日 | 11/25-11/29 | ⏳ 未着手 |
| v1.2.0 | チャット | 4-5日 | 12/9-12/13 | ⏳ 未着手 |
| v1.3.0 | ソーシャル | 6-8日 | 12/16-12/27 | ⏳ 未着手 |

**平日のみ稼働で完全に実現可能！**

---

## 🚨 v1.0.0での制限事項

アプリ内またはストア説明文に以下を記載予定:

```
【現在の機能】
✅ 地図上でポップ（募集投稿）を見る
✅ 自分でポップを投稿する
✅ カテゴリでフィルタリング
✅ ポップの詳細表示

【近日追加予定】
🔜 リアクション機能 (11月末)
🔜 チャット機能 (12月中旬)
🔜 フレンド機能 (12月下旬)
🔜 プッシュ通知 (12月下旬)
```

---

## 🎯 成功基準

### v1.0.0
- [ ] App Store / Google Playに公開
- [ ] 最低5名のテストユーザーが使用可能
- [ ] クリティカルなバグなし
- [ ] ポップの投稿・閲覧が正常に動作

### v1.1.0
- [ ] リアクション送受信が正常に動作
- [ ] 既存機能に影響なし

### v1.2.0
- [ ] チャット送受信が正常に動作
- [ ] リアルタイム性の確保

### v1.3.0
- [ ] 全機能が統合された状態で安定動作
- [ ] ユーザーフィードバックを反映

---

## 📝 進捗メモ

### 2025-11-02
- リリース計画策定
- 早期リリース戦略決定
- v1.0.0を超MVP版として11/11-11/15にリリース目標設定
- 祝日考慮でスケジュール調整（11/3-11/4は休み、11/5スタート）
- **Firebase基盤セットアップが10/29に完了済みと判明！**
  - ✅ serviceAccountKey.json配置済み
  - ✅ .env設定完了済み
  - ✅ Firestore有効化済み
  - ✅ `initialize_firebase()` 有効化済み
  - ✅ バックエンドサーバー正常起動確認
- **認証機能の実装完了！**
  - ✅ API連携サービスレイヤー作成（api_service.dart, auth_service.dart）
  - ✅ ログイン/新規登録画面実装
  - ✅ Firebase iOS設定完了（GoogleService-Info.plist, firebase_options.dart）
  - ✅ FlutterFire CLI設定完了
  - ✅ 新規登録・ログイン・ログアウト動作確認完了
  - ✅ frontendディレクトリ削除（mobileのみに統一）
- **🎉 11/5の予定タスクを11/2に完了！3日前倒し！**

---

## 🔧 Firebase基盤セットアップ手順（11/5実施）

### ステップ1: Firebaseプロジェクトの作成

1. **Firebase Consoleにアクセス**
   - https://console.firebase.google.com/ にアクセス
   - Googleアカウントでログイン

2. **新規プロジェクト作成**
   - 「プロジェクトを追加」をクリック
   - プロジェクト名: `poplink` (または任意の名前)
   - Google Analyticsは「今は設定しない」でOK
   - 「プロジェクトを作成」をクリック

3. **Firebaseプロジェクトの準備完了を待つ**
   - 約30秒〜1分で完了

---

### ステップ2: Firestoreの有効化

1. **Firestore Databaseを作成**
   - 左メニューから「Firestore Database」を選択
   - 「データベースの作成」をクリック
   - **ロケーション**: `asia-northeast1` (東京) を選択
   - **セキュリティルール**: 「テストモードで開始」を選択
     - ⚠️ 後で本番用ルールに変更必要
   - 「有効にする」をクリック

2. **Firestoreの初期化完了を待つ**
   - 約1分で完了

---

### ステップ3: サービスアカウントキーの取得

1. **プロジェクト設定を開く**
   - 左上の⚙️（歯車アイコン）→「プロジェクトの設定」をクリック

2. **サービスアカウントキーを生成**
   - 「サービス アカウント」タブを選択
   - 「新しい秘密鍵の生成」をクリック
   - 「キーを生成」を確認してクリック
   - JSONファイルがダウンロードされる（例: `poplink-xxxxx.json`）

3. **JSONファイルをプロジェクトに配置**
   ```bash
   # ダウンロードしたJSONファイルを backend ディレクトリに移動
   mv ~/Downloads/poplink-xxxxx.json /Users/shoto4410/Desktop/develop/poplink/backend/serviceAccountKey.json
   ```

---

### ステップ4: .envファイルの設定

1. **.env.exampleをコピーして.envを作成**
   ```bash
   cd /Users/shoto4410/Desktop/develop/poplink/backend
   cp .env.example .env
   ```

2. **.envファイルを編集**
   ```bash
   # エディタで開く（VSCode使用の場合）
   code .env
   ```

3. **以下の項目を設定**
   ```env
   # Application
   APP_NAME=PopLink API
   DEBUG=True  # 開発中はTrue

   # Firebase設定
   FIREBASE_PROJECT_ID=あなたのプロジェクトID  # Firebase Consoleで確認
   FIREBASE_CREDENTIALS_PATH=./serviceAccountKey.json

   # JWT設定
   SECRET_KEY=ランダムな長い文字列を生成  # 例: openssl rand -hex 32 で生成
   ALGORITHM=HS256
   ACCESS_TOKEN_EXPIRE_MINUTES=30

   # 暗号化キー
   ENCRYPTION_KEY=別のランダムな長い文字列を生成  # 例: openssl rand -hex 32 で生成
   ```

4. **FIREBASE_PROJECT_IDの確認方法**
   - Firebase Console → プロジェクト設定 → 全般タブ
   - 「プロジェクトID」をコピー

5. **SECRET_KEYとENCRYPTION_KEYの生成**
   ```bash
   # ターミナルで実行してランダムな文字列を生成
   openssl rand -hex 32
   # 出力された文字列を.envに貼り付け

   # もう一度実行して別の文字列を生成（ENCRYPTION_KEY用）
   openssl rand -hex 32
   ```

---

### ステップ5: Firebase初期化コードの有効化

1. **firebase.pyのコメントを解除**
   ```bash
   # backend/app/core/firebase.py を開く
   code backend/app/core/firebase.py
   ```

2. **23行目付近のコメントを確認**
   - 現在: `# initialize_firebase()`
   - 後で有効化: `initialize_firebase()`
   - **※今は触らない。まず.envとserviceAccountKey.jsonを配置してから**

---

### ステップ6: backend/app/main.pyの修正

1. **main.pyを開く**
   ```bash
   code backend/app/main.py
   ```

2. **22-23行目のコメントを解除**
   ```python
   # 修正前:
   # Firebase初期化（一時的にコメントアウト - Firebaseセットアップ後に有効化）
   # initialize_firebase()

   # 修正後:
   # Firebase初期化
   initialize_firebase()
   ```

---

### ステップ7: 動作確認

1. **バックエンドサーバーを起動**
   ```bash
   cd /Users/shoto4410/Desktop/develop/poplink/backend
   uv run uvicorn app.main:app --reload
   ```

2. **エラーがないか確認**
   - ✅ 正常起動: `Application startup complete` と表示される
   - ❌ エラー発生: エラーメッセージを確認して修正

3. **APIにアクセスして確認**
   ```bash
   # 別のターミナルで実行
   curl http://localhost:8000/
   # 出力: {"message":"PopLink API","status":"running","version":"1.0.0"}

   curl http://localhost:8000/health
   # 出力: {"status":"healthy"}
   ```

4. **Firestoreの接続確認**
   - Firebase Console → Firestore Database
   - データベースが作成されていることを確認
   - まだデータは空でOK

---

### ✅ 完了チェックリスト

- [ ] Firebaseプロジェクト作成完了
- [ ] Firestore Database有効化完了
- [ ] serviceAccountKey.json配置完了
- [ ] .envファイル設定完了（全項目記入）
- [ ] backend/app/main.pyのFirebase初期化を有効化
- [ ] バックエンドサーバーが正常起動
- [ ] `/` と `/health` エンドポイントにアクセス可能

---

### 🚨 トラブルシューティング

#### エラー1: `FileNotFoundError: serviceAccountKey.json`
**原因**: JSONファイルのパスが間違っている
**解決策**:
```bash
# ファイルの存在確認
ls -la /Users/shoto4410/Desktop/develop/poplink/backend/serviceAccountKey.json

# なければ正しい場所に配置
```

#### エラー2: `ValueError: Project ID not found`
**原因**: FIREBASE_PROJECT_IDが設定されていない
**解決策**: .envファイルのFIREBASE_PROJECT_IDを確認

#### エラー3: `Permission denied`
**原因**: サービスアカウントの権限不足
**解決策**: Firebase Console → IAM と管理 → サービスアカウントの権限確認

---

## 🔗 関連ドキュメント

- [プロジェクト概要](./README.md)
- [開発ガイドライン](./CLAUDE.md)
- [バックエンドテスト](./backend/tests/INTEGRATION_TEST_README.md)
