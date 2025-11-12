# imane 本番リリースチェックリスト

## ✅ 自動対応済み（Claudeが実施）

### アプリ設定
- [x] **アプリ名を "Mobile" から "imane" に変更**
  - `pubspec.yaml`: `name: imane`
  - `Info.plist`: CFBundleDisplayName/CFBundleName = "imane"
  - 全Dartファイルのimport文を `package:imane/` に変更

### バックエンドセキュリティ
- [x] **CORS設定の本番対応**
  - `.env` の `ALLOWED_ORIGINS` で本番ドメインを指定可能に
  - デフォルトは `*` だが、本番では必ず具体的なドメインに変更すること

- [x] **環境変数管理の強化**
  - `.env.production.example` テンプレート作成
  - `.gitignore` に `.env` と Firebase認証情報を追加
  - セキュリティチェックリスト付きテンプレート

- [x] **Firebase Crashlytics & Analytics 導入**
  - `firebase_crashlytics: ^4.1.5`
  - `firebase_analytics: ^11.3.5`
  - main.dart で自動初期化済み

---

## 📋 手動対応が必要なタスク

### 1. アプリアイコンの作成・適用 🎨
**Status:** 未対応（ユーザーが対応）

**必要なサイズ:**
- 1024x1024 (App Store用マスター)
- iOS用: 20pt, 29pt, 40pt, 60pt, 76pt, 83.5pt (各@1x, @2x, @3x)

**手順:**
1. デザインツールで 1024x1024 のアイコンを作成
2. https://appicon.co/ などでリサイズ
3. `mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/` に配置
4. `Contents.json` を更新

---

### 2. Bundle Identifier の設定 📱
**Status:** 確認が必要

**現在の設定を確認:**
```bash
cd mobile/ios
grep -A5 "PRODUCT_BUNDLE_IDENTIFIER" Runner.xcodeproj/project.pbxproj
```

**推奨設定:**
- 本番: `com.yourcompany.imane`
- 開発: `com.yourcompany.imane.dev`

**変更方法:**
1. Xcodeで `ios/Runner.xcodeproj` を開く
2. Runner ターゲット → General → Bundle Identifier を変更
3. Firebase Console でも同じBundle IDを使用

---

### 3. プライバシーポリシー・利用規約の準備 📄
**Status:** 未対応

**必須項目:**
- 位置情報の取り扱い（24時間自動削除を明記）
- データの収集・利用目的
- 第三者提供の有無
- お問い合わせ先

**ホスティング:**
- GitHub Pages
- 独自ドメイン
- Firebase Hosting

**App Store審査で必要:**
- プライバシーポリシーのURL
- 利用規約のURL（オプション）

---

### 4. 本番環境のバックエンド設定 🔧
**Status:** 未対応

#### 4-1. 本番用 `.env` ファイルの作成

```bash
cd backend
cp .env.production.example .env
```

以下の値を**必ず変更**:
```bash
# 強力なランダム文字列を生成
openssl rand -hex 32

# .envファイルに設定
SECRET_KEY=<生成した64文字の文字列>
ENCRYPTION_KEY=<別の64文字の文字列>
BATCH_TOKEN=<さらに別の64文字の文字列>

# 本番ドメインを設定
ALLOWED_ORIGINS=https://yourdomain.com

# Firebase本番プロジェクトを設定
FIREBASE_PROJECT_ID=your-production-project-id
FIREBASE_CREDENTIALS_PATH=/path/to/production/serviceAccountKey.json
```

#### 4-2. Firebase サービスアカウントキーの設定

```bash
# ファイルパーミッションを制限
chmod 600 backend/serviceAccountKey.json
```

#### 4-3. サーバーホスティング

選択肢:
- **Cloud Run (GCP)**: サーバーレス、自動スケール
- **App Engine (GCP)**: フルマネージド
- **EC2 (AWS)**: 柔軟性高い
- **Heroku**: 簡単デプロイ

---

### 5. App Store Connect のセットアップ 📲
**Status:** 未対応

#### 5-1. Apple Developer Program 登録
- 年間 $99 USD
- https://developer.apple.com/programs/

#### 5-2. App Store Connect でアプリ作成
1. https://appstoreconnect.apple.com/
2. 「マイApp」→「+」→「新規App」
3. 以下を入力:
   - プラットフォーム: iOS
   - 名前: imane
   - プライマリ言語: 日本語
   - Bundle ID: （前述のBundle Identifierと一致）
   - SKU: 任意（例: imane-ios-001）

#### 5-3. App情報の入力
- カテゴリ: ライフスタイル / ソーシャルネットワーキング
- 対象年齢: 4+
- プライバシーポリシーURL
- サポートURL

---

### 6. スクリーンショット・説明文の準備 📸
**Status:** 未対応

#### 必要なスクリーンショット
- **6.5インチ** (iPhone 14 Pro Max): 3〜10枚
- **5.5インチ** (iPhone 8 Plus): 3〜10枚

#### アプリ説明文（日本語）

**サブタイトル（30文字以内）:**
```
大切な人に「今ね、」を届ける位置通知アプリ
```

**説明文（4000文字以内）:**
```
【imaneとは】
「今ね、」到着したよ。「今ね、」出発したよ。
大切な人に、リアルタイムで居場所を自動でお知らせするアプリです。

【主な機能】
✓ 目的地設定で自動通知
  - 到着したら自動でお知らせ
  - 60分滞在後も通知
  - 出発時も自動通知

✓ プライバシー重視設計
  - 位置情報は24時間で自動削除
  - 通知だけのシンプル設計
  - チャット機能なし

✓ スケジュール管理
  - よく行く場所をお気に入り登録
  - 繰り返し設定も可能

【こんな方におすすめ】
- 家族に到着を知らせたい
- 友人との待ち合わせに
- 一人暮らしの安否確認に
```

**キーワード（100文字以内、カンマ区切り）:**
```
位置情報,通知,家族,安否確認,到着通知,GPS,自動,プライバシー
```

---

### 7. リリースビルドのテスト 🧪
**Status:** 未対応

#### 7-1. リリースビルドの実行

```bash
cd mobile

# 依存関係の更新
flutter pub get

# iOSリリースビルド
flutter build ios --release

# 実機でテスト
flutter run --release
```

#### 7-2. TestFlightでベータテスト

1. Xcodeで `ios/Runner.xcworkspace` を開く
2. Product → Archive
3. Distribute App → App Store Connect
4. App Store Connect で「TestFlight」タブ
5. 内部テスター or 外部テスターに配布

#### 7-3. 確認項目
- [ ] 位置情報の取得・送信が正常動作
- [ ] プッシュ通知が届く
- [ ] バックグラウンドでの位置追跡
- [ ] ジオフェンス検知（50m圏内到着）
- [ ] 60分滞在通知
- [ ] 出発通知
- [ ] Crashlyticsにクラッシュが送信されるか

---

### 8. セキュリティ最終チェック 🔒

#### バックエンド
- [ ] `DEBUG=False` に設定
- [ ] `SECRET_KEY` を本番用ランダム文字列に変更
- [ ] `ENCRYPTION_KEY` を本番用ランダム文字列に変更
- [ ] `BATCH_TOKEN` を設定
- [ ] `ALLOWED_ORIGINS` を本番ドメインに制限
- [ ] Firebase本番プロジェクトを使用
- [ ] `.env` が `.gitignore` に含まれている
- [ ] `serviceAccountKey.json` のパーミッションが 600

#### フロントエンド
- [ ] API keys が環境変数で管理されている
- [ ] `GoogleService-Info.plist` が `.gitignore` に含まれている
- [ ] リリースビルドで難読化有効

---

### 9. その他の推奨事項 💡

#### エラー監視
- [x] Firebase Crashlytics 導入済み
- [ ] Firebase Analytics でユーザー行動分析
- [ ] Sentryなどのエラートラッキング（オプション）

#### パフォーマンス
- [ ] Firebase Performance Monitoring 導入
- [ ] 画像の最適化
- [ ] APIレスポンスの最適化

#### マーケティング
- [ ] Webサイト・ランディングページ
- [ ] SNSアカウント作成
- [ ] プレスリリース準備

---

## 📝 リリース手順（本番申請時）

### ステップ1: 最終ビルド
```bash
cd mobile
flutter clean
flutter pub get
flutter build ios --release --obfuscate --split-debug-info=./debug-info
```

### ステップ2: Xcodeでアーカイブ
1. Xcodeで `ios/Runner.xcworkspace` を開く
2. Product → Scheme → Runner (Release)
3. Product → Archive
4. Organizer → Distribute App → App Store Connect

### ステップ3: App Store Connect で審査申請
1. ビルドを選択
2. 「審査に提出」をクリック
3. 必要事項を入力（スクリーンショット、説明文等）
4. 提出

### ステップ4: 審査待ち
- 平均 1〜3日
- リジェクトされた場合は修正して再提出

---

## 🚀 リリース後のタスク

- [ ] ユーザーフィードバックの収集
- [ ] クラッシュレポートの監視
- [ ] パフォーマンス指標の確認
- [ ] 定期的なアップデート計画

---

**最終更新:** 2025-11-12
**対応者:** Claude Code
