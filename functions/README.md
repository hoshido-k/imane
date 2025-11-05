# imane Cloud Functions

Firebase Cloud Functionsを使用したポップ自動削除機能の実装。

## 機能

### 1. `delete_expired_pops` - 期限切れポップの自動削除
- **スケジュール**: 5分ごとに実行
- **処理内容**: `expires_at`が現在時刻を過ぎている全てのアクティブなポップを論理削除（`is_active=False`）に設定
- **バッチ処理**: 500件ごとにFirestoreバッチ更新

### 2. `cleanup_old_deleted_pops` - 古い削除済みポップの物理削除
- **スケジュール**: 1時間ごとに実行
- **処理内容**: 削除されてから24時間以上経過したポップをFirestoreから完全削除
- **目的**: ストレージ容量の削減

## セットアップ

### 1. 依存関係のインストール

```bash
cd functions
uv sync
```

### 2. Firebaseプロジェクトの設定

```bash
# Firebase CLIのインストール（未インストールの場合）
npm install -g firebase-tools

# Firebaseにログイン
firebase login

# Firebaseプロジェクトの初期化
firebase init functions
```

プロンプトで以下を選択:
- 言語: Python
- 既存のファイルを上書き: No

### 3. 環境変数の設定

Firebase Consoleで以下を設定:
- プロジェクトID
- サービスアカウントキー（自動設定）

## デプロイ

### 推奨: デプロイスクリプトを使用

uvで管理しつつFirebase CLIの要求に対応したスクリプト：

```bash
cd functions
./deploy.sh
```

スクリプトは自動的に:
1. `pyproject.toml`から`requirements.txt`を生成
2. Firebase CLI用の`venv`を作成（初回のみ）
3. Cloud Functionsにデプロイ

### 手動デプロイ

```bash
# 1. requirements.txtを生成
cd functions
uv pip compile pyproject.toml -o requirements.txt

# 2. Firebase CLI用のvenvを作成
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
deactivate

# 3. デプロイ
cd ..
firebase deploy --only functions
```

### 特定の関数のみデプロイ

```bash
# 期限切れポップ削除関数のみ
firebase deploy --only functions:delete_expired_pops

# 古いポップクリーンアップ関数のみ
firebase deploy --only functions:cleanup_old_deleted_pops
```

### 注意事項

- **依存関係管理**: 通常の開発は`uv`で管理（`.venv`）
- **デプロイ時**: Firebase CLIは標準の`venv`と`requirements.txt`を要求
- `venv`と`requirements.txt`は`.gitignore`に含まれ、自動生成されます

## ローカルエミュレータでのテスト

```bash
# エミュレータの起動
firebase emulators:start

# 関数の手動トリガー
# Firebase Console > Functions > delete_expired_pops > Test function
```

## 監視とログ

### ログの確認

```bash
# リアルタイムログ
firebase functions:log

# 特定の関数のログ
firebase functions:log --only delete_expired_pops
```

### Firebase Consoleでの監視

1. Firebase Console > Functions
2. 各関数の実行回数、エラー率、実行時間を確認
3. ログをフィルタリング・検索

## トラブルシューティング

### エラー: "Permission denied"
- サービスアカウントのFirestore権限を確認
- Firebase Console > IAM & Admin で`Cloud Datastore User`ロールを付与

### 関数が実行されない
- Firebase Console > Functions で関数のステータスを確認
- スケジュール設定を確認（Cloud Scheduler）
- ログでエラーメッセージを確認

### バッチ処理の制限
- Firestoreのバッチ操作は500件まで
- 大量のポップを処理する場合は自動的に複数バッチに分割

## コスト最適化

### 実行頻度の調整

`main.py`でスケジュールを変更:

```python
# 期限切れポップ削除を10分ごとに変更
@scheduler_fn.on_schedule(schedule="every 10 minutes")
def delete_expired_pops(event: scheduler_fn.ScheduledEvent) -> None:
    ...

# クリーンアップを6時間ごとに変更
@scheduler_fn.on_schedule(schedule="every 6 hours")
def cleanup_old_deleted_pops(event: scheduler_fn.ScheduledEvent) -> None:
    ...
```

### 無料枠
- Cloud Functions: 月200万回の呼び出し
- Cloud Scheduler: 月3ジョブまで無料

## 開発ガイドライン

### 新しいスケジュール関数の追加

```python
@scheduler_fn.on_schedule(schedule="every 1 hours")
def my_scheduled_function(event: scheduler_fn.ScheduledEvent) -> None:
    """関数の説明"""
    try:
        # 処理内容
        logger.info("Processing...")
    except Exception as e:
        logger.error(f"Error: {str(e)}", exc_info=True)
        raise
```

### ベストプラクティス
1. 常に例外ハンドリングを実装
2. 詳細なログを記録
3. バッチ処理で大量データを効率的に処理
4. タイムアウト時間を考慮（デフォルト60秒）
5. 冪等性を確保（同じ処理を複数回実行しても安全）
