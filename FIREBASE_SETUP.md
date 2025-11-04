# Firebase セットアップガイド

imane（イマネ）アプリケーションでFirebaseを使用するための完全セットアップ手順。

## 前提条件

- Googleアカウント
- Node.js 18以上（Firebase CLI用）
- プロジェクトがクローン済み

## 1. Firebaseプロジェクトの作成

### 1.1 Firebase Consoleでプロジェクト作成

1. [Firebase Console](https://console.firebase.google.com/)にアクセス
2. 「プロジェクトを追加」をクリック
3. プロジェクト名を入力（例: `imane-dev`）
4. Google Analyticsを有効化（推奨）
5. プロジェクトを作成

### 1.2 Firebaseアプリの追加

Firebase Console > プロジェクト設定 > 全般タブ

**iOSアプリを追加** (Flutter iOS用)
1. 「アプリを追加」 > 「iOS」を選択
2. iOSバンドルIDを入力: `com.yourcompany.imane`
   - 既存のバンドルIDを確認する場合: `mobile/ios/Runner.xcodeproj/project.pbxproj`内を検索
3. アプリのニックネーム: `imane iOS` (任意)
4. App Store ID: 空欄のまま（リリース後に追加可能）
5. 「アプリを登録」をクリック
6. **`GoogleService-Info.plist`をダウンロード**（重要！）
7. 「次へ」 > 「次へ」 > 「コンソールに進む」

**注意**: 将来Androidアプリも作成する場合は、同様の手順で「Androidアプリを追加」してください。

## 2. Firebase Authentication設定

### 2.1 認証方法の有効化

Firebase Console > Authentication > Sign-in method

1. **メール/パスワード認証を有効化**
   - 「メール/パスワード」を選択
   - 有効にする
   - 保存

2. **（オプション）Google認証を有効化**
   - 「Google」を選択
   - 有効にする
   - プロジェクトのサポートメールを設定
   - 保存

## 3. Cloud Firestore設定

### 3.1 Firestoreデータベースの作成

Firebase Console > Firestore Database

1. 「データベースを作成」をクリック
2. ロケーションを選択（例: `asia-northeast1` - 東京）
3. セキュリティルールを設定:
   - 開発中: **テストモードで開始**（誰でも読み書き可能 - 30日間のみ）
   - 本番環境: **本番モードで開始**（後でルールを設定）

### 3.2 セキュリティルールの設定

Firestore Database > ルール タブ

以下のルールを設定（開発用 - 認証済みユーザーのみアクセス可能）:

```javascript
rules_version = '2';

service cloud.firestore {
  match /databases/{database}/documents {
    // ユーザー認証済みかチェック
    function isAuthenticated() {
      return request.auth != null;
    }

    // 自分のユーザードキュメントかチェック
    function isOwner(userId) {
      return request.auth.uid == userId;
    }

    // ユーザーコレクション
    match /users/{userId} {
      allow read: if isAuthenticated();
      allow write: if isOwner(userId);
    }

    // フレンドコレクション
    match /friends/{friendId} {
      allow read: if isAuthenticated();
      allow write: if isAuthenticated();
    }

    // 位置情報スケジュールコレクション
    match /schedules/{scheduleId} {
      allow read: if isAuthenticated();
      allow create: if isAuthenticated();
      allow update, delete: if isAuthenticated() &&
                              resource.data.user_id == request.auth.uid;
    }

    // お気に入り場所コレクション
    match /favorites/{favoriteId} {
      allow read: if isAuthenticated();
      allow create: if isAuthenticated();
      allow delete: if isAuthenticated() &&
                     resource.data.user_id == request.auth.uid;
    }

    // 位置情報履歴コレクション（24時間TTL）
    match /location_history/{historyId} {
      allow read: if isAuthenticated() &&
                    resource.data.user_id == request.auth.uid;
      allow create: if isAuthenticated();
      allow delete: if isAuthenticated() &&
                     resource.data.user_id == request.auth.uid;
    }

    // 通知履歴コレクション（24時間TTL）
    match /notification_history/{notificationId} {
      allow read: if isAuthenticated() &&
                    (resource.data.from_user_id == request.auth.uid ||
                     resource.data.to_user_id == request.auth.uid);
      allow create: if isAuthenticated();
    }
  }
}
```

### 3.3 インデックスの作成

Firestore Database > インデックス タブ

以下の複合インデックスを作成:

1. **アクティブなスケジュール検索用インデックス**
   - コレクション: `schedules`
   - フィールド:
     - `user_id` (昇順)
     - `status` (昇順)
     - `start_time` (昇順)
   - クエリスコープ: コレクション

2. **期限切れスケジュールクリーンアップ用インデックス**
   - コレクション: `schedules`
   - フィールド:
     - `status` (昇順)
     - `end_time` (昇順)
   - クエリスコープ: コレクション

3. **通知履歴取得用インデックス**
   - コレクション: `notification_history`
   - フィールド:
     - `to_user_id` (昇順)
     - `sent_at` (降順)
   - クエリスコープ: コレクション

**注意**: インデックスは実際にクエリを実行してエラーが出た際に、Firebaseが提供するリンクから自動作成することも可能です。

### 3.4 TTL（Time To Live）ポリシーの設定

24時間後の自動削除を実現するため、FirestoreのTTLポリシーを設定します。

Firestore Database > Time-to-live タブ > 「ポリシーを作成」

以下のTTLポリシーを作成:

1. **位置情報履歴の自動削除**
   - Collection group: `location_history`
   - Timestamp field: `auto_delete_at`
   - 「作成」をクリック

2. **通知履歴の自動削除**
   - Collection group: `notification_history`
   - Timestamp field: `auto_delete_at`
   - 「作成」をクリック

**TTLポリシーの仕組み**:
- `auto_delete_at`フィールドに設定された日時を過ぎると、Firestoreが自動的にドキュメントを削除
- バックエンドで`auto_delete_at = now + 24時間`を設定すれば、24時間後に自動削除される
- Cloud Functionsを使った手動クリーンアップは不要
- 削除処理は通常72時間以内に完了（即座ではない点に注意）

## 4. サービスアカウントキーの生成

### 4.1 サービスアカウントの作成

Firebase Console > プロジェクト設定 > サービスアカウント タブ

1. 「新しい秘密鍵を生成」をクリック
2. 警告を確認して「キーを生成」
3. JSONファイルがダウンロードされる

### 4.2 サービスアカウントキーの配置

```bash
# バックエンド用
cp ~/Downloads/imane-xxxxx-firebase-adminsdk-xxxxx.json backend/serviceAccountKey.json

# 注意: このファイルは.gitignoreに含まれており、Gitにコミットされません
```

## 5. 環境変数の設定

### 5.1 バックエンドの環境変数

`backend/.env`ファイルを作成:

```bash
# Firebase設定
FIREBASE_PROJECT_ID=imane-dev  # 実際のプロジェクトID
FIREBASE_CREDENTIALS_PATH=./serviceAccountKey.json

# JWT設定
SECRET_KEY=your-super-secret-jwt-key-change-this-in-production
ACCESS_TOKEN_EXPIRE_MINUTES=30

# 暗号化キー（32バイトのランダム文字列）
ENCRYPTION_KEY=your-32-byte-encryption-key-change-this

# デバッグモード
DEBUG=True

# 位置情報設定
GEOFENCE_RADIUS_METERS=50
LOCATION_UPDATE_INTERVAL_MINUTES=10
DATA_RETENTION_HOURS=24

# 通知設定
NOTIFICATION_STAY_DURATION_MINUTES=60
```

**暗号化キーの生成方法**:

```bash
python3 -c "import secrets; print(secrets.token_urlsafe(32))"
```

### 5.2 フロントエンドの設定（Flutter iOS）

#### 方法1: 手動で配置（シンプル）

ダウンロードした`GoogleService-Info.plist`を配置:

```bash
# Firebase Consoleからダウンロードしたファイルを配置
cp ~/Downloads/GoogleService-Info.plist mobile/ios/Runner/GoogleService-Info.plist
```

**配置場所**: `mobile/ios/Runner/GoogleService-Info.plist`

#### 方法2: FlutterFire CLI（推奨 - 自動設定）

FlutterFire CLIを使用すると、設定ファイルの配置と`firebase_options.dart`の生成を自動で行えます:

```bash
# FlutterFire CLIをインストール（初回のみ）
dart pub global activate flutterfire_cli

# プロジェクトディレクトリで実行
cd mobile
flutterfire configure
```

プロンプトで:
1. Firebaseプロジェクトを選択: `imane-dev`
2. プラットフォームを選択: `iOS` のみ選択（スペースキーで選択、Enterで確定）
3. 自動的に以下が生成されます:
   - `ios/Runner/GoogleService-Info.plist`（自動配置）
   - `lib/firebase_options.dart`（Firebase初期化用コード）

#### 確認

ファイルが正しく配置されたか確認:

```bash
# iOSの設定ファイル
ls -la mobile/ios/Runner/GoogleService-Info.plist

# Firebase初期化コード（FlutterFire CLI使用時のみ）
ls -la mobile/lib/firebase_options.dart
```

## 6. Cloud Messaging設定（プッシュ通知 - iOS）

### 6.1 APNs認証キーの取得（iOS用）

iOS向けプッシュ通知にはAPNs（Apple Push Notification service）の設定が必要です。

#### Apple Developer Consoleでの設定

1. [Apple Developer](https://developer.apple.com/)にログイン
2. 「Certificates, Identifiers & Profiles」を選択
3. 「Keys」 > 「+」ボタンをクリック
4. キー名を入力（例: `imane APNs Key`）
5. 「Apple Push Notifications service (APNs)」にチェック
6. 「Continue」 > 「Register」
7. **`.p8`ファイルをダウンロード**（重要: 一度しかダウンロードできません）
8. **Key ID**をメモ
9. **Team ID**をメモ（Apple Developer画面右上に表示）

#### Firebase Consoleでの設定

1. Firebase Console > プロジェクト設定 > Cloud Messaging タブ
2. 「Apple アプリの構成」セクションで「APNs 認証キー」を選択
3. ダウンロードした`.p8`ファイルをアップロード
4. Key IDとTeam IDを入力
5. 「アップロード」をクリック

### 6.2 Cloud Messagingの有効化

Firebase Console > Cloud Messaging

1. Cloud Messagingが自動的に有効化されます
2. サーバーキー（レガシーAPI用）は必要に応じてメモ
   - バックエンドからプッシュ通知を送信する際に使用

**注意**: TTLポリシーを使用するため、Cloud Functionsでの自動削除機能は不要です。

## 7. 動作確認

### 7.1 バックエンドの起動

```bash
cd backend
uv run uvicorn app.main:app --reload
```

### 7.2 API動作確認

```bash
# ヘルスチェック
curl http://localhost:8000/health

# API docs
open http://localhost:8000/docs
```

### 7.3 Firestore接続確認

FastAPI Docsから:
1. `/api/v1/auth/signup` でユーザー登録
2. Firebase Console > Authentication でユーザーが作成されたか確認
3. Firebase Console > Firestore Databaseでドキュメントが作成されたか確認

## 8. 本番環境への移行

### 8.1 セキュリティルールの厳格化

Firestoreルールを見直し、本番環境用に調整。

### 8.2 環境変数の更新

```bash
# 本番用の環境変数
DEBUG=False
SECRET_KEY=<強力なランダムキー>
ENCRYPTION_KEY=<強力なランダムキー>
```

### 8.3 CORSの制限

`backend/app/main.py`でCORS設定を更新:

```python
origins = [
    "https://yourdomain.com",
    "https://www.yourdomain.com",
]
```

## トラブルシューティング

### エラー: "Permission denied"

**原因**: Firestoreセキュリティルールが厳しすぎる

**解決策**:
1. Firebase Console > Firestore Database > ルール を確認
2. 開発中は一時的にテストモードに変更

### エラー: "firebase-admin could not be initialized"

**原因**: サービスアカウントキーが正しく配置されていない

**解決策**:
1. `serviceAccountKey.json`のパスを確認
2. `.env`の`FIREBASE_CREDENTIALS_PATH`を確認

## 参考リンク

- [Firebase Documentation](https://firebase.google.com/docs)
- [Firestore Security Rules](https://firebase.google.com/docs/firestore/security/get-started)
- [Firestore TTL Policy](https://firebase.google.com/docs/firestore/ttl)
- [Firebase Admin Python SDK](https://firebase.google.com/docs/reference/admin/python)
