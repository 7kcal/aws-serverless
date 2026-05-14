.PHONY: help up down shell build-sam local invoke-get invoke-create \
        test test-unit seed logs clean synth check-infra

TEMPLATE = ./cdk.out/ApiStack.template.json
PORT     = 3000
NETWORK  = serverless-net

help: ## コマンド一覧
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
	  awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-18s\033[0m %s\n", $$1, $$2}'

# ==============================================================
#  ホストマシンで実行するコマンド
# ==============================================================
up: ## 全コンテナ起動
	docker compose up -d --build
	@echo ""
	@echo "✅ Ready! make shell で開発コンテナに入れます"

down: ## コンテナ停止（データは保持）
	docker compose down
	@echo "✅ コンテナ停止（ボリュームデータは保持されています）"

down-clean: ## コンテナ停止 + 全データ削除
	docker compose down -v
	@echo "✅ コンテナ停止 + ボリューム削除完了"

volumes: ## ボリューム使用状況を確認
	@echo "=== Volumes ==="
	@docker volume ls --filter name=serverless
	@echo ""
	@docker system df -v 2>/dev/null | grep -A5 "VOLUME NAME" || true

shell: ## dev コンテナに入る
	docker compose exec dev bash

logs: ## LocalStack ログ表示
	docker compose logs -f

rebuild: ## イメージ再ビルド
	docker compose build --no-cache

# ==============================================================
#  dev コンテナ内で実行するコマンド
# ==============================================================
install: ## npm install
	npm install

synth: ## CDK テンプレート合成
	npx cdk synth --no-staging -q

build-sam: synth ## sam build（アセットを .aws-sam/build に正規化）
	sam build -t $(TEMPLATE)

local: build-sam ## API をローカル起動 (port 3000)
	sam local start-api \
	  --host 0.0.0.0 \
	  --port $(PORT) \
	  --env-vars env/local.json \
	  --docker-network $(NETWORK) \
	  --container-host host.docker.internal \
	  --container-host-interface 0.0.0.0 \
	  --warm-containers LAZY \
	  --skip-pull-image

local-cold: build-sam ## API をローカル起動（コンテナ再利用なし・確実に動く版）
	sam local start-api \
	  --host 0.0.0.0 \
	  --port $(PORT) \
	  --env-vars env/local.json \
	  --docker-network $(NETWORK) \
	  --container-host host.docker.internal \
	  --container-host-interface 0.0.0.0 \
	  --skip-pull-image

invoke-get: build-sam ## GetUser Lambda 単体実行
	sam local invoke GetUserFunction \
	  --event tests/events/get-user.json \
	  --env-vars env/local.json \
	  --docker-network $(NETWORK) \
	  --container-host host.docker.internal \
	  --container-host-interface 0.0.0.0

invoke-create: build-sam ## CreateUser Lambda 単体実行
	sam local invoke CreateUserFunction \
	  --event tests/events/create-user.json \
	  --env-vars env/local.json \
	  --docker-network $(NETWORK) \
	  --container-host host.docker.internal \
	  --container-host-interface 0.0.0.0

invoke-update: build-sam ## UpdateUser Lambda を単体実行
	sam local invoke UpdateUserFunction \
	  -t $(TEMPLATE) \
	  --event tests/events/update-user.json \
	  --env-vars env/local.json \
	  --docker-network $(NETWORK) \
	  --container-host host.docker.internal \
	  --container-host-interface 0.0.0.0

test: ## 全テスト
	npx jest --verbose

test-unit: ## Unit テストのみ
	npx jest tests/unit --verbose

seed: ## テストデータ投入
	aws --endpoint-url http://dynamodb-local:8000 dynamodb put-item \
	  --table-name Users \
	  --region ap-northeast-1 \
	  --item '{"userId":{"S":"u001"},"name":{"S":"Taro"},"email":{"S":"taro@example.com"}}'
	@echo "✅ Seed data inserted"

check-infra: ## インフラリソース確認
	@echo "=== DynamoDB ==="
	@aws --endpoint-url http://dynamodb-local:8000 dynamodb list-tables --region ap-northeast-1
	@echo ""
	@echo "=== SQS (ElasticMQ) ==="
	@curl -s http://elasticmq:9324/ | head -5 || echo "ElasticMQ not responding"

clean: ## ビルド成果物削除
	rm -rf cdk.out dist .aws-sam

# ==============================================================
#  データ確認（dev コンテナ内）
# ==============================================================
db-scan: ## DynamoDB Users テーブル全件表示
	@aws dynamodb scan \
	  --endpoint-url http://dynamodb-local:8000 \
	  --region ap-northeast-1 \
	  --table-name Users \
	  --output table

db-get: ## DynamoDB 特定ユーザー取得 (usage: make db-get ID=u001)
	@aws dynamodb get-item \
	  --endpoint-url http://dynamodb-local:8000 \
	  --region ap-northeast-1 \
	  --table-name Users \
	  --key '{"userId": {"S": "$(ID)"}}' \
	  --output json | jq .

s3-ls: ## S3 バケット内容一覧
	@aws s3 ls s3://app-bucket/ \
	  --endpoint-url http://minio:9000 \
	  --recursive 2>/dev/null || echo "(empty)"

sqs-peek: ## SQS メッセージ確認（最大10件）
	@aws sqs receive-message \
	  --endpoint-url http://elasticmq:9324 \
	  --region ap-northeast-1 \
	  --queue-url http://elasticmq:9324/000000000000/user-events-queue \
	  --max-number-of-messages 10 \
	  --output json | jq '.Messages[]?.Body | fromjson' 2>/dev/null || echo "(no messages)"

sqs-count: ## SQS メッセージ数
	@aws sqs get-queue-attributes \
	  --endpoint-url http://elasticmq:9324 \
	  --region ap-northeast-1 \
	  --queue-url http://elasticmq:9324/000000000000/user-events-queue \
	  --attribute-names ApproximateNumberOfMessages \
	  --output text | awk '{print "Messages in queue: " $$2}'
