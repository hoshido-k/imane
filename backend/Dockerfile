FROM python:3.11-slim

WORKDIR /app

# uvのインストール
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

# 依存関係のインストール
COPY pyproject.toml uv.lock* ./
RUN uv sync --frozen --no-dev

# アプリケーションコードのコピー
COPY ./app ./app

# 本番環境設定ファイルとサービスアカウントキーのコピー
COPY .env.production .env
COPY serviceAccountKey-prod.json ./serviceAccountKey-prod.json

# ポート公開
EXPOSE 8080

# アプリケーション起動
# Cloud Runはポート8080を期待するが、環境変数PORTで上書きされる場合がある
CMD [".venv/bin/uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8080"]
