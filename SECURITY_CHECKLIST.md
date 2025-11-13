# セキュリティチェックリスト

**最終更新日**: 2025年11月13日

このチェックリストは、imaneアプリのリリース前に確認すべきセキュリティ項目をまとめたものです。

---

## 1. 認証・認可

### 1.1 Firebase Authentication

- [ ] **本番Firebase Authenticationが有効化されている**
  - Firebase Console > Authentication > Sign-in method
  - Email/Passwordが有効になっていることを確認

- [ ] **メール確認が適切に設定されている**
  - 必要に応じてメール確認を有効化
  - メールテンプレートのカスタマイズ

- [ ] **パスワードポリシーが適切**
  - 最小8文字以上
  - Firebase Authenticationのデフォルトポリシーを確認

- [ ] **アカウントロックアウト設定**
  - 不正ログイン試行への対策が設定されている
  - Firebase Identity Platformの不正使用防止機能を確認

### 1.2 JWT トークン

- [ ] **ACCESS_TOKEN_EXPIRE_MINUTES が適切**
  - `backend/app/config.py` で30分に設定されていることを確認
  - 本番環境で適切な有効期限を設定

- [ ] **SECRET_KEY が強力なランダム文字列**
  ```bash
  # 確認コマンド
  grep "SECRET_KEY" backend/.env.production
  ```
  - 最低32文字以上のランダム文字列
  - 開発環境と本番環境で異なる値を使用

- [ ] **ENCRYPTION_KEY が強力なランダム文字列**
  ```bash
  # 確認コマンド
  grep "ENCRYPTION_KEY" backend/.env.production
  ```
  - 最低32文字以上のランダム文字列
  - 開発環境と本番環境で異なる値を使用

---

## 2. Firestore セキュリティルール

### 2.1 セキュリティルール基本

- [ ] **Firestore Rulesがデプロイされている**
  ```bash
  firebase deploy --only firestore:rules
  ```

- [ ] **全てのコレクションにアクセス制御が設定されている**
  - users
  - schedules
  - favorites
  - friendships
  - friend_requests
  - notification_history
  - location_history
  - notifications

- [ ] **認証必須のルールが設定されている**
  ```javascript
  allow read, write: if request.auth != null;
  ```

- [ ] **所有権チェックが実装されている**
  ```javascript
  allow read, write: if request.auth.uid == resource.data.user_id;
  ```

### 2.2 コレクション別チェック

- [ ] **users コレクション**
  - 自分のドキュメントのみ読み書き可能
  - 他ユーザーの基本情報は読み取り可能（プロフィール表示用）

- [ ] **schedules コレクション**
  - 自分のスケジュールのみ作成・編集・削除可能
  - フレンドのスケジュールは読み取りのみ可能

- [ ] **friendships コレクション**
  - 自分が関わるフレンド関係のみアクセス可能
  - 不正なフレンド関係の作成を防止

- [ ] **location_history コレクション**
  - 自分の位置情報のみアクセス可能
  - 他ユーザーの位置情報は読み取り不可

- [ ] **notification_history コレクション**
  - 自分が送信または受信した通知のみアクセス可能

### 2.3 セキュリティルールのテスト

- [ ] **Firestore Rulesのユニットテストを実施**
  ```bash
  # backend/tests/firestore_rules_test.ts を作成（推奨）
  firebase emulators:exec --only firestore "npm test"
  ```

- [ ] **Firebase Consoleでルールシミュレーターを実行**
  - Firebase Console > Firestore Database > Rules > Simulate

---

## 3. Firebase Storage セキュリティ

### 3.1 Storage Rules

- [ ] **Storage Rulesがデプロイされている**
  ```bash
  firebase deploy --only storage
  ```

- [ ] **プロフィール画像のアップロード制限**
  - ファイルサイズ: 最大5MB
  - ファイル形式: image/jpeg, image/png のみ許可
  - 認証済みユーザーのみアップロード可能

- [ ] **ファイルパスに user_id が含まれている**
  ```javascript
  match /users/{userId}/profile/{filename} {
    allow write: if request.auth.uid == userId;
  }
  ```

- [ ] **悪意のあるファイルアップロードを防止**
  - ファイル拡張子のチェック
  - Content-Typeのチェック

### 3.2 CORS設定

- [ ] **CORS設定がデプロイされている**
  ```bash
  gsutil cors set backend/storage-cors.json gs://imane-production.appspot.com
  ```

- [ ] **許可するオリジンが適切**
  - 開発環境: `http://localhost:*`
  - 本番環境: アプリのドメインのみ

---

## 4. API セキュリティ

### 4.1 CORS設定

- [ ] **ALLOWED_ORIGINS が適切に設定されている**
  ```python
  # backend/app/config.py
  ALLOWED_ORIGINS = [
      "https://your-production-domain.com",
      # 開発環境は含めない
  ]
  ```

- [ ] **ワイルドカード（*）を使用していない**
  - 本番環境で `origins=["*"]` は使用しない
  - 特定のドメインのみ許可

### 4.2 レート制限

- [ ] **APIレート制限が実装されている**
  - `slowapi` または `fastapi-limiter` の導入を検討
  - 例: 1分間に60リクエストまで

- [ ] **認証エンドポイントの制限**
  - `/api/v1/auth/login`: 1分間に5回まで
  - `/api/v1/auth/signup`: 1時間に3回まで

### 4.3 入力検証

- [ ] **全てのエンドポイントでPydanticスキーマ検証**
  - `backend/app/schemas/` 内のスキーマを確認
  - 必須フィールド、型チェック、バリデーションが適切

- [ ] **SQLインジェクション対策**
  - Firestoreを使用しているため基本的に安全
  - 動的クエリの構築時は注意

- [ ] **XSS（クロスサイトスクリプティング）対策**
  - ユーザー入力のサニタイズ
  - HTMLエスケープ処理

### 4.4 機密情報の保護

- [ ] **ログに機密情報を出力していない**
  - パスワード
  - JWTトークン
  - APIキー
  - 位置情報の詳細（緯度経度）

- [ ] **エラーメッセージに機密情報が含まれていない**
  - スタックトレースを本番環境で非表示
  - `DEBUG=False` に設定

---

## 5. 環境変数・シークレット管理

### 5.1 環境変数ファイル

- [ ] **.env ファイルが .gitignore に含まれている**
  ```bash
  grep ".env" .gitignore
  ```

- [ ] **本番環境の .env.production が安全に管理されている**
  - ローカルマシンのみに保存
  - GitHubにプッシュされていない
  - パスワード管理ツールで保管（1Password、Bitwarden等）

- [ ] **開発環境と本番環境の環境変数が分離されている**
  - `.env.example` と `.env.production.example` が存在
  - 実際の値は含まれていない

### 5.2 Firebase サービスアカウントキー

- [ ] **サービスアカウントキーが .gitignore に含まれている**
  ```bash
  grep "serviceAccountKey" .gitignore
  ```

- [ ] **サービスアカウントキーのアクセス権限が最小限**
  - Firebase Console > Project Settings > Service Accounts
  - 必要最低限のロールのみ付与

- [ ] **開発用と本番用でサービスアカウントが分離されている**
  - `serviceAccountKey-dev.json`
  - `serviceAccountKey-prod.json`

### 5.3 Google Maps API Key

- [ ] **API Key が制限されている**
  - Google Cloud Console > APIs & Services > Credentials
  - アプリケーションの制限: iOS apps
  - Bundle Identifier を設定

- [ ] **API Key がコードにハードコードされていない**
  - `mobile/lib/core/config/api_keys.dart` が .gitignore に含まれている
  - 環境変数または設定ファイルで管理

---

## 6. 位置情報のプライバシー

### 6.1 データ保存期間

- [ ] **24時間自動削除が実装されている**
  - Cloud Functions（`cleanupExpiredData`）が1時間ごとに実行
  - `location_history.auto_delete_at` が正しく設定
  - `notification_history.auto_delete_at` が正しく設定

- [ ] **自動削除機能のテスト**
  - テストデータを作成し、24時間後に削除されることを確認
  - Cloud Functionsのログで削除実行を確認
  ```bash
  firebase functions:log --only cleanupExpiredData
  ```

### 6.2 位置情報の暗号化

- [ ] **位置情報が暗号化されている（オプション）**
  - `backend/app/utils/encryption.py` で暗号化関数を実装
  - Firestoreに保存する前に暗号化

- [ ] **HTTPS通信の強制**
  - APIサーバーがHTTPSを使用
  - HTTP通信を自動的にHTTPSにリダイレクト

### 6.3 位置情報の共有範囲

- [ ] **フレンドのみに共有される**
  - Firestore Rulesでフレンド関係を確認
  - 未承認ユーザーには共有されない

- [ ] **位置情報の詳細度が適切**
  - 小数点以下5桁程度（約1m精度）
  - 必要以上に高精度にしない

---

## 7. プッシュ通知のセキュリティ

### 7.1 FCM設定

- [ ] **APNs認証キーが安全に管理されている**
  - Firebase Console > Project Settings > Cloud Messaging
  - APNs認証キー（.p8ファイル）がアップロード済み

- [ ] **FCMトークンが安全に管理されている**
  - トークンの定期的な更新
  - 無効なトークンの削除

### 7.2 通知内容

- [ ] **通知に機密情報が含まれていない**
  - 位置情報の詳細（緯度経度）を含めない
  - 「今ね、〇〇さんが△△へ到着したよ」程度の情報のみ

- [ ] **通知がフレンドにのみ送信される**
  - `notify_to_user_ids` がフレンドリストと一致
  - 未承認ユーザーには送信されない

---

## 8. コード品質・セキュリティ

### 8.1 依存関係の脆弱性チェック

- [ ] **バックエンドの依存関係を確認**
  ```bash
  cd backend
  uv pip list --outdated
  pip-audit  # 脆弱性チェックツール（インストール必要）
  ```

- [ ] **フロントエンドの依存関係を確認**
  ```bash
  cd mobile
  flutter pub outdated
  ```

- [ ] **Cloud Functionsの依存関係を確認**
  ```bash
  cd backend/functions
  npm audit
  npm audit fix  # 自動修正可能な場合
  ```

### 8.2 ソースコード監査

- [ ] **ハードコードされたシークレットがない**
  ```bash
  # パスワード、APIキー、トークンをコード内で検索
  grep -r "password.*=.*\"" backend/ mobile/
  grep -r "api_key.*=.*\"" backend/ mobile/
  grep -r "secret.*=.*\"" backend/ mobile/
  ```

- [ ] **DEBUG設定が本番環境で無効**
  ```python
  # backend/app/config.py
  DEBUG = False  # 本番環境では必ずFalse
  ```

- [ ] **エラーハンドリングが適切**
  - try-exceptブロックで例外をキャッチ
  - 機密情報を含まないエラーメッセージ

### 8.3 Gitリポジトリのクリーン化

- [ ] **.gitignore が正しく設定されている**
  - `.env`, `.env.production`
  - `serviceAccountKey*.json`
  - `GoogleService-Info.plist`（テンプレート以外）
  - `mobile/lib/core/config/api_keys.dart`

- [ ] **過去のコミットに機密情報が含まれていない**
  ```bash
  # Git履歴から機密情報を検索
  git log -S "password" --all
  git log -S "api_key" --all
  ```
  - 含まれている場合は `git-filter-branch` または `BFG Repo-Cleaner` で削除

---

## 9. インフラ・デプロイ

### 9.1 本番環境の分離

- [ ] **開発環境と本番環境が完全に分離されている**
  - Firebase プロジェクト: `imane-dev` と `imane-production`
  - `.firebaserc` で明確に定義

- [ ] **本番環境への誤デプロイ防止**
  ```bash
  # デプロイ前に確認
  firebase use  # 現在のプロジェクトを確認
  firebase use production  # 本番環境に切り替え
  ```

### 9.2 アクセス制御

- [ ] **Firebase プロジェクトのIAM設定が適切**
  - Firebase Console > Project Settings > Users and permissions
  - 必要最低限のメンバーのみアクセス可能

- [ ] **Google Cloud プロジェクトのIAM設定が適切**
  - Google Cloud Console > IAM & Admin > IAM
  - サービスアカウントの権限が最小限

### 9.3 バックアップ

- [ ] **Firestoreの自動バックアップが設定されている**
  - Google Cloud Console > Firestore > Import/Export
  - 定期的な自動バックアップのスケジュール設定

- [ ] **Storage の自動バックアップが設定されている（オプション）**
  - Google Cloud Storage のバックアップ設定

---

## 10. 監視・ロギング

### 10.1 Cloud Logging

- [ ] **重要なイベントがログに記録されている**
  - ユーザー登録
  - ログイン試行（成功・失敗）
  - アカウント削除
  - 不正なアクセス試行

- [ ] **ログに機密情報が含まれていない**
  - パスワード
  - JWTトークン
  - APIキー
  - 詳細な位置情報

### 10.2 Cloud Monitoring

- [ ] **アラートが設定されている**
  - API エラー率が高い場合
  - Cloud Functions の実行失敗
  - Firestore の読み書き回数が異常に多い場合

- [ ] **ダッシュボードが作成されている**
  - ユーザー数の推移
  - API リクエスト数
  - エラー率

---

## 11. ペネトレーションテスト（推奨）

### 11.1 手動テスト

- [ ] **不正ログイン試行のテスト**
  - 存在しないアカウントでログイン
  - 間違ったパスワードで複数回ログイン

- [ ] **権限昇格の試行**
  - 他ユーザーのデータにアクセス
  - 管理者権限が必要な操作を試行

- [ ] **APIエンドポイントの直接アクセス**
  - 認証なしでAPIを呼び出し
  - 不正なパラメータを送信

### 11.2 自動化ツール（オプション）

- [ ] **OWASP ZAP でスキャン**
  - APIエンドポイントの脆弱性スキャン

- [ ] **Burp Suite でテスト**
  - 手動ペネトレーションテスト

---

## 12. コンプライアンス

### 12.1 プライバシーポリシー・利用規約

- [ ] **プライバシーポリシーが公開されている**
  - URL: `https://hoshido-k.github.io/imane/privacy-policy.html`
  - App Store Connect に登録済み

- [ ] **利用規約が公開されている**
  - URL: `https://hoshido-k.github.io/imane/terms-of-service.html`
  - アプリ内で同意を取得

- [ ] **データ削除ポリシーが明記されている**
  - 24時間自動削除
  - アカウント削除時の即座削除

### 12.2 日本の個人情報保護法

- [ ] **個人情報の取得に同意を取得**
  - 初回起動時に同意画面を表示
  - プライバシーポリシーと利用規約へのリンク

- [ ] **ユーザーの権利を尊重**
  - データの閲覧・訂正・削除が可能
  - アカウント削除機能が実装されている

---

## 13. App Store セキュリティ要件

### 13.1 App Transport Security (ATS)

- [ ] **ATS が有効**
  - Info.plist で ATS 例外を最小限に
  - 全ての通信がHTTPSであることを確認

### 13.2 暗号化エクスポート

- [ ] **App Store Connect で暗号化情報を提出**
  - App StoreのExport Compliance設定
  - HTTPS通信のみの場合は「No」でOK

---

## 14. 最終チェックリスト

リリース前に以下を確認してください。

- [ ] **全ての環境変数が本番用に設定されている**
- [ ] **DEBUG=False に設定されている**
- [ ] **SECRET_KEY、ENCRYPTION_KEY が強力なランダム文字列**
- [ ] **Firestore Rules、Storage Rules がデプロイされている**
- [ ] **Cloud Functions がデプロイされている**
- [ ] **24時間自動削除が正常に動作している**
- [ ] **本番Firebaseプロジェクトが使用されている**
- [ ] **APIキーが制限されている**
- [ ] **プライバシーポリシー・利用規約が公開されている**
- [ ] **ログに機密情報が含まれていない**
- [ ] **.gitignore が正しく設定されている**
- [ ] **依存関係の脆弱性がない**
- [ ] **TestFlightでベータテストを実施済み**

---

**セキュリティは継続的なプロセスです。リリース後も定期的にこのチェックリストを見直し、新たな脅威に対応してください。**
