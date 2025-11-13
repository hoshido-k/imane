# Google Maps API Key Setup Guide

このドキュメントでは、imane アプリで使用する Google Maps API キーの設定方法を説明します。

## 概要

imane アプリでは、Google Maps Platform の以下の API を使用します：

- **Maps SDK for iOS**: 地図表示
- **Places API (New)**: 場所の検索とオートコンプリート
- **Geocoding API**: 住所と座標の変換

**セキュリティのため、開発環境と本番環境で異なる API キーを使用します。**

## API キーの取得

### 1. Google Cloud Console にアクセス

1. [Google Cloud Console](https://console.cloud.google.com/) にアクセス
2. Firebase プロジェクト（imane-dev または imane-prod）を選択
3. 「API とサービス」→「認証情報」を開く

### 2. 必要な API を有効化

「API とサービス」→「ライブラリ」から以下を有効化：

- Maps SDK for iOS
- Places API (New)
- Geocoding API

### 3. API キーを作成

#### 開発環境用キー

1. 「認証情報を作成」→「API キー」
2. 作成されたキーの名前を「imane iOS Dev Key」に変更
3. 「キーを制限」をクリック：
   - **アプリケーションの制限**: iOS アプリ
   - **バンドル ID**: `jp.imane.app.dev`（開発用）
   - **API の制限**: 以下の 3 つのみ選択
     - Maps SDK for iOS
     - Places API (New)
     - Geocoding API
4. 保存してキーをコピー

#### 本番環境用キー

1. 「認証情報を作成」→「API キー」
2. 作成されたキーの名前を「imane iOS Prod Key」に変更
3. 「キーを制限」をクリック：
   - **アプリケーションの制限**: iOS アプリ
   - **バンドル ID**: `jp.imane.app`（本番用）
   - **API の制限**: 以下の 3 つのみ選択
     - Maps SDK for iOS
     - Places API (New)
     - Geocoding API
4. 保存してキーをコピー

## ローカル開発環境の設定

### 1. .env ファイルを作成

```bash
cd mobile
cp .env.example .env
```

### 2. API キーを設定

`.env` ファイルを開いて、取得した API キーを設定：

```bash
# 開発環境用キー
GOOGLE_MAPS_API_KEY_DEV=AIzaSy...（開発用キー）

# 本番環境用キー
GOOGLE_MAPS_API_KEY_PROD=AIzaSy...（本番用キー）
```

### 3. .env ファイルが Git で無視されることを確認

`.gitignore` に以下が含まれていることを確認（すでに設定済み）：

```gitignore
.env
.env.*
!.env.example
**/lib/core/config/api_keys.dart
```

## 使い方

### 開発環境で実行

```bash
# シミュレーターで実行（開発用キーを自動使用）
./scripts/run-dev-simulator.sh

# 実機で実行（開発用キーを自動使用）
./scripts/run-dev-device.sh
```

### 本番ビルド

```bash
# 本番用ビルド（本番用キーを自動使用）
./scripts/build-prod.sh
```

### 手動実行（スクリプトを使わない場合）

```bash
# 開発環境
fvm flutter run \
  --dart-define=ENVIRONMENT=development \
  --dart-define=GOOGLE_MAPS_API_KEY_DEV=your-dev-key

# 本番ビルド
fvm flutter build ios \
  --dart-define=ENVIRONMENT=production \
  --dart-define=GOOGLE_MAPS_API_KEY_PROD=your-prod-key \
  --release
```

## CI/CD 環境での設定

### GitHub Actions の場合

1. リポジトリの「Settings」→「Secrets and variables」→「Actions」
2. 以下のシークレットを追加：
   - `GOOGLE_MAPS_API_KEY_DEV`: 開発用キー
   - `GOOGLE_MAPS_API_KEY_PROD`: 本番用キー

3. ワークフローファイルで使用：

```yaml
- name: Build iOS app (Development)
  run: |
    cd mobile
    fvm flutter build ios \
      --dart-define=ENVIRONMENT=development \
      --dart-define=GOOGLE_MAPS_API_KEY_DEV=${{ secrets.GOOGLE_MAPS_API_KEY_DEV }}

- name: Build iOS app (Production)
  run: |
    cd mobile
    fvm flutter build ios \
      --dart-define=ENVIRONMENT=production \
      --dart-define=GOOGLE_MAPS_API_KEY_PROD=${{ secrets.GOOGLE_MAPS_API_KEY_PROD }} \
      --release
```

## トラブルシューティング

### エラー: "Google Maps API key not configured"

**原因**: API キーが設定されていないか、環境変数が正しく渡されていない

**解決方法**:
1. `.env` ファイルが存在し、正しいキーが設定されているか確認
2. スクリプトを使って実行しているか確認
3. 手動実行の場合、`--dart-define` フラグが正しく設定されているか確認

### API リクエストが失敗する

**原因**: API キーの制限設定が正しくない、または API が有効化されていない

**解決方法**:
1. Google Cloud Console で API が有効化されているか確認
2. API キーの制限設定を確認：
   - iOS バンドル ID が正しいか
   - 必要な API（Maps SDK, Places API, Geocoding API）が許可されているか
3. API の使用量制限に達していないか確認

### 開発環境で本番キーが使われる（またはその逆）

**原因**: `ENVIRONMENT` パラメータが正しく設定されていない

**解決方法**:
1. スクリプトを使用する（自動的に正しい環境が設定される）
2. 手動実行の場合、`--dart-define=ENVIRONMENT=development` または `production` を確認

## セキュリティベストプラクティス

1. **API キーを分離**: 開発環境と本番環境で異なるキーを使用
2. **制限を設定**: API キーに iOS バンドル ID と API の制限を必ず設定
3. **定期的なローテーション**: API キーを定期的に更新
4. **使用量の監視**: Google Cloud Console で API の使用量を定期的に確認
5. **コミット禁止**: `.env` ファイルや実際の API キーを Git にコミットしない

## 参考リンク

- [Google Maps Platform - 認証情報](https://console.cloud.google.com/google/maps-apis/credentials)
- [Maps SDK for iOS - API キー](https://developers.google.com/maps/documentation/ios-sdk/get-api-key)
- [Places API (New) - ドキュメント](https://developers.google.com/maps/documentation/places/web-service/op-overview)
- [Geocoding API - ドキュメント](https://developers.google.com/maps/documentation/geocoding)
