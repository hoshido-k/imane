# GitHub Pages セットアップ手順

このガイドでは、imaneのプライバシーポリシーをGitHub Pagesで公開する手順を説明します。

---

## 1. ファイル構成確認

以下のファイルが `docs/` ディレクトリに作成されています:

```
docs/
├── index.html              # トップページ（アプリ紹介）
├── privacy-policy.html     # プライバシーポリシー
└── terms-of-service.html   # 利用規約（準備中）
```

これらのファイルをGitHubリポジトリにプッシュします。

---

## 2. GitHubリポジトリへのプッシュ

### 手順

```bash
# 1. 作業ディレクトリに移動
cd /Users/shoto4410/Desktop/develop/imane

# 2. 現在のブランチを確認
git status

# 3. docs/ ディレクトリをステージング
git add docs/

# 4. コミット
git commit -m "Add GitHub Pages: privacy policy and landing page

- プライバシーポリシーHTML版作成 (docs/privacy-policy.html)
- ランディングページ作成 (docs/index.html)
- 利用規約ページ作成（準備中表示） (docs/terms-of-service.html)
- App Store申請用のプライバシーポリシーURL準備完了"

# 5. GitHubにプッシュ
git push origin develop
```

### 注意

- 現在のブランチは `develop` です
- `main` ブランチにマージする前にGitHub Pagesを有効化できます
- GitHub Pagesは `main` ブランチまたは `develop` ブランチから公開可能です

---

## 3. GitHub Pagesの有効化

### 手順（ブラウザで操作）

1. **GitHubリポジトリにアクセス**
   - URL: https://github.com/hoshido-k/imane
   - ブラウザでリポジトリを開きます

2. **Settings（設定）タブを開く**
   - リポジトリページの上部メニューから「Settings」をクリック

3. **Pagesセクションに移動**
   - 左サイドバーから「Pages」をクリック

4. **Source（ソース）を設定**
   - 「Build and deployment」セクションで:
     - **Source**: 「Deploy from a branch」を選択
     - **Branch**:
       - プルダウンから `develop` を選択（または `main` にマージ後は `main` を選択）
       - フォルダは `/docs` を選択
     - **Save** ボタンをクリック

5. **デプロイ完了を待つ**
   - 通常、1〜2分程度でデプロイが完了します
   - ページ上部に緑色のチェックマークと「Your site is live at ...」のメッセージが表示されます

6. **公開URLを確認**
   - 表示されるURL: `https://hoshido-k.github.io/imane/`

---

## 4. 公開されるURL一覧

GitHub Pagesが有効化されると、以下のURLでアクセスできるようになります:

| ページ | URL |
|--------|-----|
| トップページ | `https://hoshido-k.github.io/imane/` |
| プライバシーポリシー | `https://hoshido-k.github.io/imane/privacy-policy.html` |
| 利用規約 | `https://hoshido-k.github.io/imane/terms-of-service.html` |

---

## 5. App Store Connect への登録

App Store申請時に、以下のURLをプライバシーポリシーURLとして登録します:

```
https://hoshido-k.github.io/imane/privacy-policy.html
```

### App Store Connect での設定箇所

1. **App Information**
   - App Store Connect にログイン
   - 「マイApp」 > imane を選択
   - 左サイドバー「App情報」をクリック
   - 「プライバシーポリシーURL」欄に上記URLを入力
   - 保存

---

## 6. 動作確認

GitHub Pagesが公開されたら、以下の確認を行ってください:

### 確認項目

- [ ] トップページが正しく表示される
- [ ] プライバシーポリシーページが正しく表示される
- [ ] 利用規約ページが「準備中」と表示される
- [ ] ナビゲーションリンクが正しく機能する
- [ ] モバイル表示が適切である（レスポンシブデザイン）
- [ ] 連絡先メールアドレスが正しく表示される: `imane.app.contact@gmail.com`
- [ ] 開発者名が正しく表示される: `hoshido-k`

### 確認方法

```bash
# 1. ブラウザで各URLにアクセス
open https://hoshido-k.github.io/imane/
open https://hoshido-k.github.io/imane/privacy-policy.html
open https://hoshido-k.github.io/imane/terms-of-service.html

# 2. スマートフォンでも確認
# iPhoneのSafariでURLを開いて、表示が崩れていないかチェック
```

---

## 7. 更新方法

今後、プライバシーポリシーやページ内容を変更する場合:

```bash
# 1. HTMLファイルを編集
# 例: docs/privacy-policy.html を編集

# 2. 変更をコミット
git add docs/
git commit -m "Update privacy policy: [変更内容]"

# 3. GitHubにプッシュ
git push origin develop

# 4. 自動的に再デプロイされる（1〜2分後に反映）
```

---

## 8. カスタムドメイン設定（オプション）

独自ドメインを使用したい場合:

### 例: `imane.app` ドメインを使用する場合

1. **ドメインを取得**
   - Google Domains、お名前.com、Cloudflare などでドメインを取得

2. **DNS設定**
   - CNAMEレコードを追加:
     ```
     www.imane.app  CNAME  hoshido-k.github.io
     ```
   - Aレコードを追加（apex domain用）:
     ```
     imane.app  A  185.199.108.153
     imane.app  A  185.199.109.153
     imane.app  A  185.199.110.153
     imane.app  A  185.199.111.153
     ```

3. **GitHub Pages設定**
   - Settings > Pages > Custom domain に `imane.app` を入力
   - 「Enforce HTTPS」にチェック

4. **CNAME ファイル作成**
   ```bash
   echo "imane.app" > docs/CNAME
   git add docs/CNAME
   git commit -m "Add custom domain: imane.app"
   git push origin develop
   ```

5. **App Store Connect のURL更新**
   - プライバシーポリシーURLを以下に変更:
     ```
     https://imane.app/privacy-policy.html
     ```

---

## 9. トラブルシューティング

### 問題: 404エラーが表示される

**原因**: GitHub Pagesがまだデプロイされていない、またはブランチ/フォルダ設定が間違っている

**解決策**:
1. Settings > Pages で設定を確認
2. ブランチが `develop` または `main` に設定されているか確認
3. フォルダが `/docs` に設定されているか確認
4. デプロイ完了まで待つ（最大5分）

### 問題: スタイルが崩れている

**原因**: CSSファイルが正しく読み込まれていない

**解決策**:
- すべてのスタイルはHTMLファイル内に埋め込まれているため、この問題は発生しないはず
- ブラウザのキャッシュをクリアして再読み込み: `Cmd + Shift + R` (Mac)

### 問題: リンクが機能しない

**原因**: 相対パスの設定ミス

**解決策**:
- 現在のHTMLファイルはすべて相対パス（`index.html`, `privacy-policy.html` など）を使用しているため、正常に動作するはず
- GitHub Pagesのベースパスは `/imane/` だが、ファイル間のリンクは相対パスなので問題なし

---

## 10. セキュリティ設定

GitHub Pagesは静的サイトなので、基本的にセキュリティリスクは低いですが、以下の点に注意:

### 確認事項

- [ ] HTTPS が有効化されている（GitHub Pagesは自動的に有効化）
- [ ] 個人情報（本名、住所）が含まれていない
- [ ] 連絡先は専用メールアドレス（`imane.app.contact@gmail.com`）のみ
- [ ] Gitリポジトリに機密情報（APIキー、パスワード）が含まれていない

---

## 次のステップ

1. **GitHubにプッシュ**（上記の手順2を実行）
2. **GitHub Pagesを有効化**（上記の手順3を実行）
3. **公開URLを確認**（上記の手順4、6を実行）
4. **App Store Connect に登録**（App Store申請時）

---

**注**: GitHub Pagesは無料で使用でき、追加費用は発生しません。帯域幅制限は月間100GBですが、プライバシーポリシーのような静的ページでは問題ありません。
