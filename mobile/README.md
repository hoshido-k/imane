# PopLink Mobile (Flutter)

Figmaデザインを基にしたリアルタイム位置情報ベースのモバイルアプリケーション（iOS版）

## プロジェクト構成

```
lib/
├── core/
│   ├── constants/
│   │   ├── app_colors.dart      # アプリのカラーパレット
│   │   └── app_routes.dart      # ルート定義
│   └── theme/
│       └── app_theme.dart        # ダークテーマ設定
├── screens/
│   ├── auth/
│   │   └── login_screen.dart     # ログイン画面
│   ├── map/
│   │   └── map_screen.dart       # マップ画面
│   ├── chat/
│   │   └── chat_list_screen.dart # チャット一覧画面
│   ├── reactions/
│   │   └── reactions_screen.dart # リアクション画面
│   └── main_screen.dart          # メイン画面（タブナビゲーション）
├── widgets/
│   └── navigation/
│       └── bottom_nav_bar.dart   # ボトムナビゲーションバー
└── main.dart                     # アプリケーションエントリーポイント
```

## 実装済み機能

### 1. デザインシステム
- **カラーパレット**: Figmaデザインに基づいたダークテーマ
  - Background: グラデーション（#0A0E27 → #1A1F3A → #2A3158）
  - Primary: #5B6FED
  - 完全なカラー定義: `lib/core/constants/app_colors.dart`

### 2. 画面
- **ログイン画面**: ユーザー名/パスワード認証、Google認証ボタン
- **マップ画面**: Google Maps統合済み、現在地表示、位置情報パーミッション処理
- **チャット一覧画面**: チャットプレビュー、検索機能
- **チャット詳細画面**: メッセージ送受信、リアルタイムチャット
- **リアクション画面**: プレースホルダー（今後実装予定）
- **プロフィール画面**: ユーザー情報表示、ログアウト機能
- **統一ヘッダー**: メニューボタン、タイトル、プロフィールボタン
- **ボトムナビゲーション**: 3タブ（マップ、リアクション、チャット）

### 3. ナビゲーション
- シンプルなルートベースのナビゲーション
- ログイン → メイン画面への遷移

## セットアップ

### 必要な環境
- Flutter 3.35.7以上
- fvm（推奨）
- Xcode（iOS開発用）

### インストール手順

1. **依存関係のインストール**
   ```bash
   cd mobile
   fvm flutter pub get
   ```

2. **コード解析**
   ```bash
   fvm flutter analyze
   ```

3. **テスト実行**
   ```bash
   fvm flutter test
   ```

4. **Google Maps APIキーの設定**

   Google Maps APIキーが必要です：

   a. [Google Cloud Console](https://console.cloud.google.com/)でAPIキーを取得
   b. Maps SDK for iOSを有効化
   c. `ios/Runner/AppDelegate.swift`を開く
   d. `YOUR_GOOGLE_MAPS_API_KEY_HERE`を実際のAPIキーに置き換え

   ```swift
   GMSServices.provideAPIKey("YOUR_ACTUAL_API_KEY_HERE")
   ```

5. **iOS シミュレーターで実行**
   ```bash
   fvm flutter run
   ```

   **注意**: iOSシミュレーターでは位置情報のシミュレーションが必要です：
   - Xcode → Debug → Simulate Location → Apple や Custom Location を選択

## 次のステップ（今後の実装予定）

### 優先度: 高
1. **Firebase統合**
   - Firebase Authentication（認証機能）
   - Cloud Firestore（リアルタイムデータベース統合）
   - Firebase Cloud Messaging（プッシュ通知）

2. **位置情報機能の拡張**
   - バックグラウンドでの位置情報追跡
   - 「ポップ」の作成と表示
   - マップ上でのポップ表示とインタラクション

### 優先度: 中
3. **チャット機能の拡張**
   - Firestoreとのリアルタイムメッセージング統合
   - 画像・ファイル送信機能
   - 既読・未読状態の同期

4. **リアクション機能**
   - ポップへのリアクション
   - リアクション一覧表示
   - リアクション通知

5. **サイドメニュー**
   - 設定画面の詳細実装
   - 通知設定
   - プライバシー設定

### 優先度: 低
6. **状態管理の改善**
   - Providerパターンの完全実装
   - 認証状態管理
   - チャット状態管理
   - 位置情報状態管理

7. **プロフィール機能の拡張**
   - ユーザープロフィール編集
   - アバター画像のアップロード
   - ステータスメッセージ

## 既存のバックエンドとの統合

このプロジェクトは、`../backend`にあるFastAPI バックエンドと統合できるように設計されています。

### API統合予定
- `POST /api/v1/auth/login` - ログイン
- `GET /api/v1/users/me` - ユーザー情報取得
- `POST /api/v1/messages` - メッセージ送信
- `GET /api/v1/messages/conversations` - チャット一覧取得

## デザインリファレンス

このアプリは以下のFigmaデザインに基づいています：
- ログイン画面: ユーザー名/パスワード入力、Google認証
- マップ画面: インタラクティブな地図表示
- チャット画面: チャット一覧、検索機能
- ボトムナビゲーション: 3タブ構成

## 開発ノート

### fvmの使用
このプロジェクトはfvm（Flutter Version Management）を使用しています：
```bash
# Flutterバージョンの確認
fvm flutter --version

# コマンド実行例
fvm flutter run
fvm flutter build ios
```

### コード品質
- `flutter analyze`でエラー0を維持
- Lint規則: `flutter_lints 5.0.0`
- 100文字の行長制限（Ruffと同様）

## トラブルシューティング

### よくある問題

1. **依存関係のエラー**
   ```bash
   fvm flutter clean
   fvm flutter pub get
   ```

2. **iOSビルドエラー**
   ```bash
   cd ios
   pod install
   cd ..
   fvm flutter run
   ```

## ライセンス

このプロジェクトはPopLinkアプリケーションの一部です。
