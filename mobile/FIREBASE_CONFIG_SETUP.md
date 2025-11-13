# Firebase Configuration Setup Guide

imaneアプリでは開発環境と本番環境で異なるFirebaseプロジェクトを使用します。このガイドでは、Xcodeビルド時に自動的に正しい設定ファイルを使用するための設定方法を説明します。

## 概要

### Firebase設定ファイル
- **開発環境**: `GoogleService-Info-Dev.plist` (PROJECT_ID: `imane-dev`, BUNDLE_ID: `com.imane`)
- **本番環境**: `GoogleService-Info-Prod.plist` (PROJECT_ID: `imane-production`, BUNDLE_ID: `com.imane.app`)
- **ビルド時に使用**: `GoogleService-Info.plist` (ビルドスクリプトで自動生成)

## Xcodeでの設定手順

### 1. Xcodeプロジェクトを開く
```bash
open ios/Runner.xcworkspace
```

### 2. Build Schemeを設定

#### 開発用Scheme（Debug/Dev）
1. Xcodeメニューバー: **Product > Scheme > Edit Scheme...**
2. 左側から **Build > Pre-actions** を選択
3. 「+」ボタンをクリック → **New Run Script Action** を選択
4. 以下のスクリプトを追加:
   ```bash
   "${SRCROOT}/../../scripts/setup-firebase-config.sh" dev
   ```
5. **Provide build settings from**: `Runner` を選択

#### 本番用Scheme（Release/Production）
1. Xcodeメニューバー: **Product > Scheme > Manage Schemes...**
2. 既存の「Runner」Schemeを複製（選択して歯車アイコン → Duplicate）
3. 名前を「Runner-Production」に変更
4. **Edit Scheme...** を開く
5. **Build > Pre-actions** に以下を追加:
   ```bash
   "${SRCROOT}/../../scripts/setup-firebase-config.sh" prod
   ```
6. **Provide build settings from**: `Runner` を選択

### 3. Bundle Identifierの設定

#### 開発環境（Debug）
1. Xcodeの左側Navigator → **Runner** プロジェクトを選択
2. **TARGETS > Runner** を選択
3. **Signing & Capabilities** タブ
4. **Bundle Identifier**: `com.imane`

#### 本番環境（Release）
1. 同じ画面で **Build Settings** タブ
2. 検索バーで「Bundle Identifier」を検索
3. **Release** 行を展開して `com.imane.app` に設定

または、`xcconfig` ファイルで管理:
```bash
# ios/Flutter/Debug.xcconfig に追加
PRODUCT_BUNDLE_IDENTIFIER = com.imane

# ios/Flutter/Release.xcconfig に追加
PRODUCT_BUNDLE_IDENTIFIER = com.imane.app
```

## 手動でのFirebase設定切り替え

ビルド前に手動で切り替えたい場合:

```bash
# 開発環境
cd mobile
SRCROOT=$(pwd)/ios ./scripts/setup-firebase-config.sh dev

# 本番環境
SRCROOT=$(pwd)/ios ./scripts/setup-firebase-config.sh prod
```

## Flutter起動コマンド

### シミュレーター（開発環境）
```bash
# 手動でFirebase設定を切り替え
SRCROOT=$(pwd)/ios ./scripts/setup-firebase-config.sh dev

# アプリ起動
flutter run --dart-define=ENVIRONMENT=development
```

### 実機（開発環境）
```bash
# 手動でFirebase設定を切り替え
SRCROOT=$(pwd)/ios ./scripts/setup-firebase-config.sh dev

# アプリ起動（API URLを明示的に指定）
flutter run --dart-define=ENVIRONMENT=development --dart-define=API_BASE_URL=http://192.168.0.14:8000/api/v1
```

### 本番ビルド
```bash
# 手動でFirebase設定を切り替え
SRCROOT=$(pwd)/ios ./scripts/setup-firebase-config.sh prod

# リリースビルド
flutter build ios --release \
  --dart-define=ENVIRONMENT=production \
  --dart-define=API_BASE_URL=https://api.imane.app/api/v1
```

## トラブルシューティング

### 問題: Firebaseの初期化エラー
**原因**: 間違ったFirebase設定ファイルが使用されている

**解決策**:
1. `ios/Runner/GoogleService-Info.plist` の`PROJECT_ID`を確認:
   ```bash
   /usr/libexec/PlistBuddy -c "Print :PROJECT_ID" ios/Runner/GoogleService-Info.plist
   ```
2. 開発環境なら `imane-dev`、本番環境なら `imane-production` であることを確認
3. 正しくない場合はスクリプトを手動実行:
   ```bash
   SRCROOT=$(pwd)/ios ./scripts/setup-firebase-config.sh dev
   ```

### 問題: API接続タイムアウト
**原因**: 実機からローカルバックエンドサーバーにアクセスできない

**解決策**:
1. MacのIPアドレスを確認:
   ```bash
   ifconfig | grep "inet " | grep -v 127.0.0.1
   ```
2. `mobile/lib/services/api_service.dart` の `defaultValue` を正しいIPに更新
3. または起動時に明示的に指定:
   ```bash
   flutter run --dart-define=API_BASE_URL=http://192.168.0.14:8000/api/v1
   ```

### 問題: Build Schemeのスクリプトが動かない
**原因**: スクリプトに実行権限がない、またはパスが間違っている

**解決策**:
```bash
# 実行権限を付与
chmod +x mobile/scripts/setup-firebase-config.sh

# パスを絶対パスで確認
ls -la mobile/scripts/setup-firebase-config.sh
```

## 参考リンク

- [Firebase iOS Setup - Multiple Environments](https://firebase.google.com/docs/projects/multiprojects)
- [Flutter Build Configurations](https://docs.flutter.dev/deployment/flavors)
- [Xcode Schemes and Build Configurations](https://developer.apple.com/documentation/xcode/customizing-the-build-schemes-for-a-project)
