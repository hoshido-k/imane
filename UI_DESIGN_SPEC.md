# PopLink UI設計仕様書

このドキュメントは、PopLinkアプリのUI設計に必要なすべての要素を整理したものです。
Figmaでデザインする際の参考資料としてご活用ください。

---

## 📱 画面一覧

### 1. 認証関連
- **ログイン画面** (`LoginScreen`)
- **サインアップ画面** (`SignupScreen`)
- **パスワードリセット画面** (`PasswordResetScreen`) ※オプション

### 2. メイン機能
- **ホーム画面（マップビュー）** (`HomeScreen`)
- **ポップ投稿画面** (`CreatePopScreen`)
- **ポップ詳細画面** (`PopDetailScreen`)
- **検索・フィルター画面** (`SearchScreen`)

### 3. リアクション機能
- **受信リアクション一覧** (`ReceivedReactionsScreen`)
- **送信リアクション一覧** (`SentReactionsScreen`)
- **リアクション詳細画面** (`ReactionDetailScreen`)

### 4. ユーザー関連
- **プロフィール画面** (`ProfileScreen`)
- **プロフィール編集画面** (`EditProfileScreen`)
- **設定画面** (`SettingsScreen`)

### 5. その他
- **通知画面** (`NotificationsScreen`)
- **チャット画面** (`ChatScreen`) ※マッチング後

---

## 🎨 カラーパレット

デザイン時に定義すべき色：

### Primary Colors（メインカラー）
- **Primary**: アプリのメインカラー（例: #6C63FF）
- **Primary Light**: Primary の明るいバリエーション
- **Primary Dark**: Primary の暗いバリエーション

### Secondary Colors（アクセントカラー）
- **Secondary**: アクセントカラー（例: #FF6584）
- **Secondary Light**: Secondary の明るいバリエーション
- **Secondary Dark**: Secondary の暗いバリエーション

### Background Colors（背景色）
- **Background**: メイン背景色（例: #FFFFFF）
- **Surface**: カード・コンテナの背景色（例: #F5F5F5）
- **Overlay**: モーダル・オーバーレイ背景色（半透明黒）

### Text Colors（テキスト色）
- **Text Primary**: メインテキスト色（例: #212121）
- **Text Secondary**: サブテキスト色（例: #757575）
- **Text Disabled**: 無効状態のテキスト色（例: #BDBDBD）
- **Text On Primary**: Primary色背景上のテキスト（通常は白）
- **Text On Secondary**: Secondary色背景上のテキスト

### Status Colors（ステータス色）
- **Success**: 成功（例: #4CAF50）
- **Error**: エラー（例: #F44336）
- **Warning**: 警告（例: #FF9800）
- **Info**: 情報（例: #2196F3）

### Category Colors（カテゴリ色）
各ポップカテゴリ用の色：
- **Food**: 食事・カフェ（例: #FF6B6B）
- **Hobby**: 趣味（例: #4ECDC4）
- **Sports**: スポーツ（例: #45B7D1）
- **Study**: 作業・勉強（例: #96CEB4）
- **Event**: イベント（例: #FFEAA7）
- **Business**: ビジネス（例: #DFE6E9）
- **Game**: ゲーム（例: #A29BFE）
- **Other**: その他（例: #BDBDBD）

---

## 🔤 タイポグラフィ（テキストスタイル）

### Font Family（フォントファミリー）
- **Primary Font**: メインフォント（例: Noto Sans JP, Inter）
- **Secondary Font**: アクセントフォント（例: Roboto）

### Text Styles（テキストスタイル定義）

#### Display（大見出し）
- **Display Large**: 57sp / Bold / Primary Text
- **Display Medium**: 45sp / Bold / Primary Text
- **Display Small**: 36sp / Bold / Primary Text

#### Headline（見出し）
- **Headline Large**: 32sp / Bold / Primary Text
- **Headline Medium**: 28sp / SemiBold / Primary Text
- **Headline Small**: 24sp / SemiBold / Primary Text

#### Title（タイトル）
- **Title Large**: 22sp / Medium / Primary Text
- **Title Medium**: 16sp / Medium / Primary Text
- **Title Small**: 14sp / Medium / Primary Text

#### Body（本文）
- **Body Large**: 16sp / Regular / Primary Text
- **Body Medium**: 14sp / Regular / Primary Text
- **Body Small**: 12sp / Regular / Secondary Text

#### Label（ラベル）
- **Label Large**: 14sp / Medium / Primary Text
- **Label Medium**: 12sp / Medium / Secondary Text
- **Label Small**: 11sp / Medium / Secondary Text

---

## 🧱 共通UIコンポーネント

### 1. ボタン（Buttons）

#### Primary Button（メインボタン）
- **用途**: CTA（Call to Action）、送信、保存など
- **デザイン要素**:
  - 背景色: Primary
  - テキスト色: Text On Primary
  - パディング: 垂直16px, 水平24px
  - 角丸: 8px
  - 影: Elevation 2 (軽い影)
  - 状態: Normal, Pressed, Disabled

#### Secondary Button（サブボタン）
- **用途**: キャンセル、戻る、代替アクション
- **デザイン要素**:
  - 背景色: Transparent
  - ボーダー: 1px solid Primary
  - テキスト色: Primary
  - パディング: 垂直16px, 水平24px
  - 角丸: 8px

#### Text Button（テキストボタン）
- **用途**: リンク、補助的なアクション
- **デザイン要素**:
  - 背景色: Transparent
  - テキスト色: Primary
  - パディング: 垂直8px, 水平16px

#### Icon Button（アイコンボタン）
- **用途**: ツールバー、アクションボタン
- **デザイン要素**:
  - サイズ: 48x48px (タップエリア)
  - アイコンサイズ: 24x24px
  - 背景色: Transparent
  - アイコン色: Text Primary

#### Floating Action Button (FAB)
- **用途**: メインアクション（ポップ投稿）
- **デザイン要素**:
  - サイズ: 56x56px
  - 背景色: Secondary
  - アイコン色: Text On Secondary
  - 角丸: 28px (円形)
  - 影: Elevation 6 (強い影)

### 2. カード（Cards）

#### Pop Card（ポップカード）
- **用途**: ポップ一覧、検索結果
- **デザイン要素**:
  - 背景色: Surface
  - 角丸: 12px
  - 影: Elevation 1
  - パディング: 16px
  - 構成要素:
    - ユーザーアイコン (40x40px)
    - 表示名 (Title Medium)
    - カテゴリバッジ
    - 投稿内容 (Body Medium, 最大3行)
    - メタ情報 (Label Small: 時刻、距離、リアクション数)

#### Reaction Card（リアクションカード）
- **用途**: リアクション一覧
- **デザイン要素**:
  - 背景色: Surface
  - 角丸: 12px
  - 影: Elevation 1
  - パディング: 16px
  - 構成要素:
    - ユーザーアイコン (48x48px)
    - 表示名 (Title Medium)
    - メッセージプレビュー (Body Small, 2行)
    - ステータスバッジ
    - アクションボタン (承認/拒否)

#### User Card（ユーザーカード）
- **用途**: プロフィール表示
- **デザイン要素**:
  - 背景色: Surface
  - 角丸: 12px
  - パディング: 20px
  - 構成要素:
    - プロフィール画像 (80x80px, 円形)
    - 表示名 (Headline Small)
    - メールアドレス (Body Small)

### 3. 入力要素（Input Fields）

#### Text Field（テキスト入力）
- **デザイン要素**:
  - ボーダー: 1px solid #E0E0E0
  - 角丸: 8px
  - パディング: 垂直12px, 水平16px
  - フォントサイズ: Body Medium
  - ラベル: Label Medium
  - 状態: Default, Focused, Error, Disabled

#### Text Area（複数行入力）
- **用途**: ポップ投稿、メッセージ入力
- **デザイン要素**:
  - 最小高さ: 100px
  - その他はText Fieldと同じ

#### Dropdown / Picker（選択）
- **用途**: カテゴリ選択、有効期間選択
- **デザイン要素**:
  - ボーダー: 1px solid #E0E0E0
  - 角丸: 8px
  - パディング: 垂直12px, 水平16px
  - ドロップダウンアイコン: 24x24px

#### Checkbox（チェックボックス）
- **デザイン要素**:
  - サイズ: 20x20px
  - ボーダー: 2px solid Primary
  - 角丸: 4px
  - チェックマーク色: Text On Primary

#### Radio Button（ラジオボタン）
- **用途**: 有効期間選択（15/30/45/60分）
- **デザイン要素**:
  - サイズ: 20x20px (外円)
  - 内円: 10x10px
  - ボーダー: 2px solid Primary

#### Toggle Switch（トグルスイッチ）
- **用途**: 公開範囲切り替え
- **デザイン要素**:
  - サイズ: 52x32px
  - トラック色: ON=Primary, OFF=#E0E0E0
  - サム（つまみ）: 28x28px, 白色

#### Slider（スライダー）
- **用途**: 距離フィルター
- **デザイン要素**:
  - トラック高さ: 4px
  - トラック色: Primary Light
  - サム: 20x20px, Primary

### 4. ナビゲーション

#### Top App Bar（トップバー）
- **デザイン要素**:
  - 高さ: 56px
  - 背景色: Primary
  - タイトル色: Text On Primary
  - アイコン色: Text On Primary
  - 影: Elevation 4

#### Bottom Navigation Bar（ボトムナビゲーション）
- **デザイン要素**:
  - 高さ: 80px
  - 背景色: Surface
  - 影: Elevation 8
  - アイテム数: 5個
  - アイテム構成:
    - アイコン: 24x24px
    - ラベル: Label Small
    - 選択時: Primary色
    - 非選択時: Text Secondary色
  - FABスペース: 中央に80x80pxの余白

#### Tab Bar（タブバー）
- **用途**: フィルター切り替え
- **デザイン要素**:
  - 高さ: 48px
  - インジケーター: 2px, Primary色
  - ラベル: Label Large
  - 選択時: Primary色
  - 非選択時: Text Secondary色

### 5. フィードバック要素

#### Loading Spinner（ローディング）
- **デザイン要素**:
  - サイズ: 40x40px
  - 色: Primary
  - アニメーション: 回転

#### Progress Bar（プログレスバー）
- **デザイン要素**:
  - 高さ: 4px
  - 色: Primary
  - 背景色: Primary Light

#### Snackbar / Toast（通知バー）
- **デザイン要素**:
  - 背景色: #323232
  - テキスト色: 白
  - 角丸: 4px
  - パディング: 垂直14px, 水平16px
  - 位置: 画面下部、中央
  - 表示時間: 3秒

#### Dialog / Modal（ダイアログ）
- **デザイン要素**:
  - 背景色: Surface
  - 角丸: 28px
  - パディング: 24px
  - 影: Elevation 24
  - 最大幅: 280px
  - 構成:
    - タイトル (Title Large)
    - 本文 (Body Medium)
    - アクションボタン（右揃え）

#### Empty State（空状態）
- **デザイン要素**:
  - アイコン: 64x64px, Text Secondary
  - メッセージ: Title Medium, Text Secondary
  - サブメッセージ: Body Small, Text Secondary

#### Error State（エラー状態）
- **デザイン要素**:
  - アイコン: 64x64px, Error色
  - メッセージ: Title Medium, Error色
  - リトライボタン: Primary Button

### 6. バッジ・チップ

#### Badge（バッジ）
- **用途**: 通知数表示
- **デザイン要素**:
  - サイズ: 20x20px (円形)
  - 背景色: Error
  - テキスト色: 白
  - フォントサイズ: 12sp

#### Category Badge（カテゴリバッジ）
- **用途**: ポップのカテゴリ表示
- **デザイン要素**:
  - 背景色: カテゴリ色
  - テキスト色: 白
  - パディング: 垂直4px, 水平12px
  - 角丸: 16px
  - フォントサイズ: Label Small
  - アイコン: 16x16px

#### Status Badge（ステータスバッジ）
- **用途**: リアクションのステータス表示
- **デザイン要素**:
  - 種類:
    - Pending: 背景#FFF3E0, テキスト#F57C00
    - Accepted: 背景#E8F5E9, テキスト#388E3C
    - Rejected: 背景#FFEBEE, テキスト#D32F2F
    - Cancelled: 背景#F5F5F5, テキスト#757575
  - パディング: 垂直4px, 水平8px
  - 角丸: 4px
  - フォントサイズ: Label Small

#### Chip（チップ）
- **用途**: フィルター選択
- **デザイン要素**:
  - 背景色: 非選択=#E0E0E0, 選択=Primary Light
  - テキスト色: 非選択=Text Primary, 選択=Primary
  - パディング: 垂直8px, 水平16px
  - 角丸: 16px
  - フォントサイズ: Label Medium

---

## 🗺️ 画面別の詳細要素

### 1. ログイン画面（LoginScreen）

**必要な要素:**
- アプリロゴ（200x200px程度）
- アプリタイトル（Headline Large）
- メールアドレス入力フィールド
  - ラベル: "メールアドレス"
  - プレースホルダー: "example@email.com"
  - プレフィックスアイコン: メールアイコン
- パスワード入力フィールド
  - ラベル: "パスワード"
  - プレースホルダー: "8文字以上"
  - プレフィックスアイコン: 鍵アイコン
  - サフィックスアイコン: 表示/非表示トグル
- ログインボタン（Primary Button, 全幅）
- 新規登録リンク（Text Button）
- パスワードを忘れた場合のリンク（Text Button, オプション）

**レイアウト:**
- 垂直中央配置
- 左右マージン: 24px
- 要素間スペース: 16px

---

### 2. サインアップ画面（SignupScreen）

**必要な要素:**
- タイトル: "新規登録"（Headline Medium）
- 表示名入力フィールド
  - ラベル: "表示名"
  - プレフィックスアイコン: 人物アイコン
- メールアドレス入力フィールド
- パスワード入力フィールド
- パスワード（確認）入力フィールド（オプション）
- 利用規約同意チェックボックス（オプション）
- サインアップボタン（Primary Button, 全幅）
- ログインに戻るリンク（Text Button）

---

### 3. ホーム画面（HomeScreen）

**必要な要素:**

#### Top App Bar
- アプリロゴ（小）
- 検索ボタン（Icon Button）
- フィルターボタン（Icon Button）
- 通知ボタン（Icon Button + Badge）

#### Map View
- 地図表示エリア（全画面）
- 現在地マーカー（青い円、アニメーション）
- ポップマーカー
  - カテゴリアイコン
  - Time-Dimming効果（透明度・サイズ変化）
  - タップでポップ詳細表示

#### Floating Action Button
- 位置: 右下
- アイコン: プラスアイコン
- アクション: ポップ投稿画面へ遷移

#### Bottom Navigation Bar
- ホーム（地図アイコン）
- 受信（受信箱アイコン + Badge）
- ポップ投稿（中央、大きなプラスアイコン）
- 送信（送信箱アイコン）
- プロフィール（人物アイコン）

---

### 4. ポップ投稿画面（CreatePopScreen）

**必要な要素:**

#### Top App Bar
- 戻るボタン（Icon Button）
- タイトル: "ポップを投稿"
- プレビューボタン（Text Button, オプション）

#### 入力フォーム
- コンテンツ入力（Text Area）
  - ラベル: "何をしたい？"
  - プレースホルダー: "例: 渋谷でランチしませんか？"
  - 最大文字数: 500
  - 文字カウンター表示

- カテゴリ選択
  - ラベル: "カテゴリ"
  - 表示: 8つのカテゴリアイコンをグリッド表示
  - 選択状態: ボーダー + 影で強調

- 位置情報設定
  - ラベル: "場所"
  - 現在地ボタン（Secondary Button）
  - 地図プレビュー（縮小表示）
  - 選択中の住所表示（Body Small）

- 有効期間選択
  - ラベル: "有効期間"
  - ラジオボタン: 15分 / 30分 / 45分 / 60分
  - 横並び表示

- 公開範囲選択
  - ラベル: "公開範囲"
  - トグルスイッチ: 全体公開 / フレンド限定

#### Bottom Actions
- キャンセルボタン（Secondary Button）
- 投稿ボタン（Primary Button）

---

### 5. ポップ詳細画面（PopDetailScreen）

**必要な要素:**

#### Top App Bar
- 戻るボタン
- メニューボタン（報告、ブロック）

#### Pop Information Card
- ユーザー情報
  - プロフィール画像（64x64px）
  - 表示名（Title Large）
  - 投稿時刻（Label Small）
- カテゴリバッジ
- 投稿内容（Body Large）
- メタ情報
  - 距離表示（アイコン + テキスト）
  - 残り時間（アイコン + テキスト）
  - リアクション数（アイコン + テキスト）
- Time-Dimming プログレスバー（視覚的に残り時間を表示）

#### Map Preview
- 小さな地図（高さ200px）
- ポップの位置マーカー

#### Action Buttons
- リアクションボタン（Primary Button, 全幅）
  - テキスト: "興味あり！"
- メッセージ付きリアクション
  - Text Field（折りたたみ可能）
  - 送信ボタン

---

### 6. 受信リアクション一覧画面（ReceivedReactionsScreen）

**必要な要素:**

#### Top App Bar
- タイトル: "受信リアクション"
- フィルターボタン

#### Filter Tabs
- すべて
- 未対応（Badge付き）
- 承認済み
- 拒否済み

#### Reaction List
- Reaction Card（スクロールリスト）
  - 各カードの要素:
    - 送信者プロフィール画像
    - 送信者表示名
    - 関連ポップのサムネイル（テキスト抜粋）
    - メッセージプレビュー
    - 送信時刻
    - ステータスバッジ
    - アクションボタン（承認/拒否）※pending時のみ

#### Empty State
- アイコン: 受信箱アイコン
- メッセージ: "まだリアクションがありません"

---

### 7. 送信リアクション一覧画面（SentReactionsScreen）

**必要な要素:**

#### Top App Bar
- タイトル: "送信リアクション"

#### Filter Tabs
- すべて
- 待機中
- 承認済み
- 拒否済み

#### Reaction List
- Reaction Card（スクロールリスト）
  - 各カードの要素:
    - 送信先ポップのサムネイル
    - 送信先ユーザー名
    - 自分のメッセージ
    - ステータスバッジ
    - キャンセルボタン（pending時）
    - チャットボタン（accepted時）

---

### 8. プロフィール画面（ProfileScreen）

**必要な要素:**

#### Header
- プロフィール画像（120x120px, 円形）
- 編集ボタン（Icon Button, 右上）
- 表示名（Headline Medium）
- メールアドレス（Body Small）

#### Statistics Cards
- 3つのカードを横並び
  - 投稿数
  - 受信数
  - マッチング数

#### Settings Menu
- リスト形式
  - プロフィール編集（矢印アイコン）
  - 通知設定（矢印アイコン）
  - プライバシー設定（矢印アイコン）
  - ヘルプ・サポート（矢印アイコン）
  - ログアウト（危険色）

---

### 9. 検索・フィルター画面（SearchScreen）

**必要な要素:**

#### Top App Bar
- 戻るボタン
- 検索バー（Text Field）

#### Filter Section（折りたたみ可能）
- カテゴリフィルター
  - Chipの横並び（複数選択可能）
- 距離スライダー
  - 0.1km - 50km
  - 現在値表示
- 有効なポップのみトグル

#### Results Section
- タブ: リスト表示 / 地図表示
- ポップカードのリスト

---

## 📐 レイアウト・スペーシング

### Grid System
- **基本単位**: 8px
- **コンテンツマージン**: 16px (左右)
- **カード間スペース**: 12px
- **セクション間スペース**: 24px

### Elevation（影の深さ）
- **Level 0**: 影なし
- **Level 1**: 軽い影（カード）
- **Level 2**: 中程度の影（ボタン）
- **Level 4**: 強めの影（App Bar）
- **Level 8**: 強い影（Bottom Nav, FAB）
- **Level 24**: 最も強い影（Dialog）

---

## 🎭 アニメーション

### Transition（画面遷移）
- **Duration**: 300ms
- **Easing**: Ease-in-out

### Button Press（ボタン押下）
- **Duration**: 150ms
- **Effect**: Scale 0.95

### Loading（ローディング）
- **Duration**: Infinite
- **Effect**: Rotation

### Time-Dimming Pop（ポップの縮小）
- **Duration**: リアルタイム（有効期限に応じて）
- **Effect**: Scale + Opacity

---

## 🎯 インタラクション

### タップ可能エリアの最小サイズ
- **推奨**: 48x48px
- **最小**: 40x40px

### タップフィードバック
- **Ripple Effect**: Primary色、透明度20%
- **Duration**: 300ms

---

## 📊 データ表示フォーマット

### 日時表示
- **絶対時刻**: "2025年10月29日 14:30"
- **相対時刻**: "3分前", "1時間前", "昨日", "3日前"

### 距離表示
- **メートル単位**: "50m", "500m"
- **キロメートル単位**: "1.5km", "10km"

### 数値表示
- **少数**: "5", "24", "99"
- **多数**: "100+", "999+"

---

## 🔔 通知タイプ

### 通知メッセージ例
- **新規リアクション**: "◯◯さんがあなたのポップにリアクションしました"
- **リアクション承認**: "◯◯さんがあなたのリアクションを承認しました"
- **リアクション拒否**: "◯◯さんがあなたのリアクションを拒否しました"
- **ポップ期限切れ**: "あなたのポップの有効期限が切れました"
- **チャットメッセージ**: "◯◯さんからメッセージが届きました"

---

## ✅ デザインチェックリスト

### 完成前に確認すべき項目
- [ ] すべての画面が定義されている
- [ ] カラーパレットが統一されている
- [ ] テキストスタイルが一貫している
- [ ] ボタンのスタイルが統一されている
- [ ] カードのスタイルが統一されている
- [ ] スペーシングが一貫している
- [ ] アイコンのサイズが統一されている
- [ ] タップ可能エリアが適切なサイズ
- [ ] Empty Stateが定義されている
- [ ] Error Stateが定義されている
- [ ] Loading Stateが定義されている
- [ ] アニメーションが定義されている

---

## 📱 推奨画面サイズ

### デザイン時の基準サイズ
- **iPhone基準**: 390 x 844 (iPhone 14)
- **Android基準**: 360 x 800 (一般的なサイズ)

### レスポンシブ対応
- 横幅320px - 428pxの範囲で適切に表示されること
- タブレット対応は後回しでOK（まずはスマートフォン）

---

## 📝 備考

### このドキュメントの使い方
1. Figmaでデザインする際の参考資料として活用
2. 必要に応じて色やサイズをカスタマイズ
3. デザイン完成後、スクリーンショットまたはFigma共有リンクを共有
4. Claude CodeがFlutterコードに変換

### Figmaでの推奨作業フロー
1. **カラーパレット定義**: Stylesで色を定義
2. **テキストスタイル定義**: Stylesでタイポグラフィを定義
3. **コンポーネント作成**: ボタン、カードなどを再利用可能なコンポーネント化
4. **画面デザイン**: フレームを作成して各画面をデザイン
5. **プロトタイプ作成**: 画面遷移を設定（オプション）

---

**最終更新**: 2025-10-29
