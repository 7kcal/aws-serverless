## 前提条件

- Ubuntu 22.04+
- Docker / Docker Compose v2
- Git
- make（任意だが推奨）

前提条件の自動チェック:

```bash
chmod +x scripts/setup.sh
./scripts/setup.sh
```

## セットアップ
### 1. リポジトリ取得
git clone https://github.com/7kcal/aws-serverless.git
cd aws-serverless

### 2. 全コンテナ起動（初回はイメージビルド: 約2〜3分）
make up

### 3. 開発コンテナに入る
make shell

### 4. npm install（初回のみ）
make install

### 5. テストデータ投入
make seed

### 6. API 起動
make local

## 開発フロー
### 作業開始
make up                   # コンテナ起動（2回目以降は make start でも可）
make shell                # 開発コンテナに入る
make local                # API 起動 (http://localhost:3000)

### コード修正後
Ctrl+C                    # sam local 停止
make local                # 再ビルド＆再起動

### テスト
make test                 # 全テスト
make test-unit            # Unit テストのみ

### 作業終了
exit                      # コンテナから出る
make down                 # 停止（データ保持）

## API 仕様
### POST /users - ユーザー作成
- リクエスト
```bash
curl -s -X POST http://localhost:3000/users \
  -H 'Content-Type: application/json' \
  -d '{"name": "Taro Yamada", "email": "taro@example.com"}' | jq .
```

- レスポンス (201):
```json
{
  "userId": "550e8400-e29b-41d4-a716-446655440000",
  "name": "Taro Yamada",
  "email": "taro@example.com",
  "createdAt": "2026-05-13T06:30:00.000Z"
}
```

### GET /users/{id} - ユーザー取得
- リクエスト
```bash
curl -s http://localhost:3000/users/{userId} | jq .
```

- レスポンス（200）
```json
{
  "userId": "550e8400-e29b-41d4-a716-446655440000",
  "name": "Taro Yamada",
  "email": "taro@example.com",
  "createdAt": "2026-05-13T06:30:00.000Z"
}
```

## コマンド一覧
`make help`で全コマンドを表示

### ホストマシンで実行
- `make up`	全コンテナ起動（ビルド含む）
- `make down`	コンテナ停止（データ保持）
- `make down-clean`	コンテナ停止＋全データ削除
- `make stop`	一時停止（全データ保持、SQS含む）
- `make start`	一時停止したコンテナを再開
- `make shell`	開発コンテナに入る
- `make logs`	コンテナログ表示
- `make rebuild`	イメージ再ビルド

### devコンテナ内で実行
- `make install`	npm install
- `make local`	API ローカル起動 (port 3000)
- `make local-cold`	API 起動（warm container なし・確実に動く版）
- `make test`	全テスト実行
- `make test-unit`	Unit テストのみ
- `make synth`	CDK テンプレート合成
- `make seed`	テストデータ投入
- `make check`-infra	インフラリソース確認
- `make clean`	ビルド成果物削除
- `make db-scan`	DynamoDB 全件表示
- `make db-get ID=xxx`	DynamoDB 特定ユーザー取得
- `make s3-ls`	S3 オブジェクト一覧
- `make sqs-peek`	SQS メッセージ確認
- `make sqs-count`	SQS メッセージ数

## Web UI
- DynamoDB Admin	http://localhost:8001
- MinIO Console	http://localhost:9001	minioadmin / minioadmin

## データ永続化
DynamoDB と S3 のデータは名前付きボリュームで永続化される。