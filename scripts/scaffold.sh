#!/bin/bash
# scripts/scaffold.sh - ホスト側で実行
set -euo pipefail

echo "=== プロジェクトファイルを生成 ==="

# ディレクトリ作成
mkdir -p bin lib src/handlers tests/unit tests/events env config

######################################
# package.json
######################################
cat > package.json << 'EOF'
{
  "name": "serverless-api",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "build": "tsc",
    "watch": "tsc -w",
    "cdk": "cdk",
    "synth": "cdk synth --no-staging -q",
    "test": "jest",
    "test:unit": "jest tests/unit",
    "lint": "eslint . --ext .ts"
  },
  "dependencies": {
    "@aws-sdk/client-dynamodb": "^3.700.0",
    "@aws-sdk/client-sqs": "^3.700.0",
    "@aws-sdk/lib-dynamodb": "^3.700.0",
    "aws-cdk-lib": "^2.170.0",
    "constructs": "^10.4.2",
    "uuid": "^11.0.0"
  },
  "devDependencies": {
    "@types/aws-lambda": "^8.10.147",
    "@types/jest": "^29.5.14",
    "@types/node": "^22.10.0",
    "@types/uuid": "^10.0.0",
    "aws-cdk": "^2.170.0",
    "esbuild": "^0.24.0",
    "eslint": "^9.15.0",
    "jest": "^29.7.0",
    "ts-jest": "^29.2.5",
    "ts-node": "^10.9.2",
    "typescript": "~5.7.0"
  }
}
EOF

######################################
# tsconfig.json
######################################
cat > tsconfig.json << 'EOF'
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "commonjs",
    "lib": ["ES2022"],
    "declaration": true,
    "strict": true,
    "noImplicitAny": true,
    "strictNullChecks": true,
    "noImplicitReturns": true,
    "inlineSourceMap": true,
    "inlineSources": true,
    "experimentalDecorators": true,
    "strictPropertyInitialization": false,
    "outDir": "./dist",
    "rootDir": ".",
    "baseUrl": ".",
    "esModuleInterop": true,
    "resolveJsonModule": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true
  },
  "include": ["bin/**/*.ts", "lib/**/*.ts", "src/**/*.ts", "tests/**/*.ts"],
  "exclude": ["node_modules", "cdk.out", "dist"]
}
EOF

######################################
# cdk.json
######################################
cat > cdk.json << 'EOF'
{
  "app": "npx ts-node --prefer-ts-exts bin/app.ts",
  "watch": {
    "include": ["**"],
    "exclude": ["README.md", "cdk*.json", "**/*.d.ts", "**/*.js",
                "tsconfig.json", "package*.json", "jest.config.ts",
                "node_modules", "test", "dist"]
  }
}
EOF

######################################
# jest.config.ts
######################################
cat > jest.config.ts << 'EOF'
import type { Config } from 'jest';
const config: Config = {
  testEnvironment: 'node',
  roots: ['<rootDir>/tests'],
  testMatch: ['**/*.test.ts'],
  transform: { '^.+\\.tsx?$': 'ts-jest' },
  moduleFileExtensions: ['ts', 'tsx', 'js', 'jsx', 'json'],
  collectCoverageFrom: ['src/**/*.ts', '!src/**/*.d.ts'],
};
export default config;
EOF

######################################
# bin/app.ts
######################################
cat > bin/app.ts << 'EOF'
#!/usr/bin/env node
import * as cdk from 'aws-cdk-lib';
import { ApiStack } from '../lib/api-stack';

const app = new cdk.App();
new ApiStack(app, 'ApiStack', {
  env: {
    account: process.env.CDK_DEFAULT_ACCOUNT,
    region: process.env.CDK_DEFAULT_REGION ?? 'ap-northeast-1',
  },
});
EOF

######################################
# lib/api-stack.ts
######################################
cat > lib/api-stack.ts << 'EOF'
import * as cdk from 'aws-cdk-lib';
import * as dynamodb from 'aws-cdk-lib/aws-dynamodb';
import * as sqs from 'aws-cdk-lib/aws-sqs';
import * as s3 from 'aws-cdk-lib/aws-s3';
import * as apigw from 'aws-cdk-lib/aws-apigateway';
import { NodejsFunction } from 'aws-cdk-lib/aws-lambda-nodejs';
import { Runtime } from 'aws-cdk-lib/aws-lambda';
import { Construct } from 'constructs';
import * as path from 'path';

export class ApiStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    const usersTable = new dynamodb.Table(this, 'UsersTable', {
      tableName: 'Users',
      partitionKey: { name: 'userId', type: dynamodb.AttributeType.STRING },
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
      removalPolicy: cdk.RemovalPolicy.DESTROY,
    });

    const userEventsQueue = new sqs.Queue(this, 'UserEventsQueue', {
      queueName: 'user-events-queue',
      visibilityTimeout: cdk.Duration.seconds(30),
    });

    const appBucket = new s3.Bucket(this, 'AppBucket', {
      removalPolicy: cdk.RemovalPolicy.DESTROY,
      autoDeleteObjects: true,
    });

    const commonLambdaProps = {
      runtime: Runtime.NODEJS_20_X,
      memorySize: 256,
      timeout: cdk.Duration.seconds(10),
      bundling: { minify: true, sourceMap: true, externalModules: ['@aws-sdk/*'] },
    };

    const getUserFn = new NodejsFunction(this, 'GetUserFunction', {
      ...commonLambdaProps,
      entry: path.join(__dirname, '../src/handlers/get-user.ts'),
      handler: 'handler',
      environment: { USERS_TABLE: usersTable.tableName },
    });
    usersTable.grantReadData(getUserFn);

    const createUserFn = new NodejsFunction(this, 'CreateUserFunction', {
      ...commonLambdaProps,
      entry: path.join(__dirname, '../src/handlers/create-user.ts'),
      handler: 'handler',
      environment: {
        USERS_TABLE: usersTable.tableName,
        QUEUE_URL: userEventsQueue.queueUrl,
      },
    });
    usersTable.grantWriteData(createUserFn);
    userEventsQueue.grantSendMessages(createUserFn);

    const api = new apigw.RestApi(this, 'MyApi', {
      restApiName: 'ServerlessAPI',
      deployOptions: { stageName: 'v1' },
    });

    const users = api.root.addResource('users');
    users.addMethod('POST', new apigw.LambdaIntegration(createUserFn));
    const user = users.addResource('{id}');
    user.addMethod('GET', new apigw.LambdaIntegration(getUserFn));

    new cdk.CfnOutput(this, 'ApiUrl', { value: api.url });
    new cdk.CfnOutput(this, 'TableName', { value: usersTable.tableName });
  }
}
EOF

######################################
# src/handlers/get-user.ts
######################################
cat > src/handlers/get-user.ts << 'EOF'
import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, GetCommand } from '@aws-sdk/lib-dynamodb';

const ddbClient = new DynamoDBClient({
  ...(process.env.DYNAMODB_ENDPOINT && { endpoint: process.env.DYNAMODB_ENDPOINT }),
});
const docClient = DynamoDBDocumentClient.from(ddbClient);
const TABLE_NAME = process.env.USERS_TABLE!;

export const handler = async (event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> => {
  console.log('Event:', JSON.stringify(event, null, 2));
  const userId = event.pathParameters?.id;
  if (!userId) {
    return { statusCode: 400, headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ message: 'Missing path parameter: id' }) };
  }
  try {
    const result = await docClient.send(new GetCommand({ TableName: TABLE_NAME, Key: { userId } }));
    if (!result.Item) {
      return { statusCode: 404, headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ message: 'User not found' }) };
    }
    return { statusCode: 200, headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(result.Item) };
  } catch (error) {
    console.error('Error:', error);
    return { statusCode: 500, headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ message: 'Internal server error' }) };
  }
};
EOF

######################################
# src/handlers/create-user.ts
######################################
cat > src/handlers/create-user.ts << 'EOF'
import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, PutCommand } from '@aws-sdk/lib-dynamodb';
import { SQSClient, SendMessageCommand } from '@aws-sdk/client-sqs';
import { v4 as uuidv4 } from 'uuid';

const ddbClient = new DynamoDBClient({
  ...(process.env.DYNAMODB_ENDPOINT && { endpoint: process.env.DYNAMODB_ENDPOINT }),
});
const docClient = DynamoDBDocumentClient.from(ddbClient);
const sqsClient = new SQSClient({
  ...(process.env.SQS_ENDPOINT && { endpoint: process.env.SQS_ENDPOINT }),
});
const TABLE_NAME = process.env.USERS_TABLE!;
const QUEUE_URL = process.env.QUEUE_URL!;

interface CreateUserRequest { name: string; email: string; }

export const handler = async (event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> => {
  console.log('Event:', JSON.stringify(event, null, 2));
  if (!event.body) {
    return { statusCode: 400, headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ message: 'Missing request body' }) };
  }
  try {
    const { name, email }: CreateUserRequest = JSON.parse(event.body);
    if (!name || !email) {
      return { statusCode: 400, headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ message: 'name and email are required' }) };
    }
    const userId = uuidv4();
    const now = new Date().toISOString();
    const user = { userId, name, email, createdAt: now };
    await docClient.send(new PutCommand({ TableName: TABLE_NAME, Item: user }));
    await sqsClient.send(new SendMessageCommand({
      QueueUrl: QUEUE_URL,
      MessageBody: JSON.stringify({ eventType: 'USER_CREATED', userId, timestamp: now }),
    }));
    return { statusCode: 201, headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(user) };
  } catch (error) {
    console.error('Error:', error);
    return { statusCode: 500, headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ message: 'Internal server error' }) };
  }
};
EOF

######################################
# tests/unit/get-user.test.ts
######################################
cat > tests/unit/get-user.test.ts << 'EOF'
import { APIGatewayProxyEvent } from 'aws-lambda';

const mockSend = jest.fn();
jest.mock('@aws-sdk/client-dynamodb', () => ({ DynamoDBClient: jest.fn(() => ({})) }));
jest.mock('@aws-sdk/lib-dynamodb', () => ({
  DynamoDBDocumentClient: { from: jest.fn(() => ({ send: mockSend })) },
  GetCommand: jest.fn((input) => input),
}));
process.env.USERS_TABLE = 'Users';

import { handler } from '../../src/handlers/get-user';

const createEvent = (pathParams?: Record<string, string>) =>
  ({ pathParameters: pathParams ?? null, headers: {}, body: null, httpMethod: 'GET' } as unknown as APIGatewayProxyEvent);

describe('GET /users/{id}', () => {
  beforeEach(() => jest.clearAllMocks());

  it('200: ユーザーが見つかった場合', async () => {
    mockSend.mockResolvedValue({ Item: { userId: 'u001', name: 'Taro', email: 'taro@example.com' } });
    const result = await handler(createEvent({ id: 'u001' }));
    expect(result.statusCode).toBe(200);
    expect(JSON.parse(result.body)).toEqual({ userId: 'u001', name: 'Taro', email: 'taro@example.com' });
  });

  it('404: ユーザーが見つからない場合', async () => {
    mockSend.mockResolvedValue({});
    const result = await handler(createEvent({ id: 'u999' }));
    expect(result.statusCode).toBe(404);
  });

  it('400: パスパラメータが無い場合', async () => {
    const result = await handler(createEvent());
    expect(result.statusCode).toBe(400);
  });
});
EOF

######################################
# tests/events/get-user.json
######################################
cat > tests/events/get-user.json << 'EOF'
{
  "httpMethod": "GET",
  "path": "/users/u001",
  "pathParameters": { "id": "u001" },
  "headers": { "Content-Type": "application/json" },
  "body": null,
  "isBase64Encoded": false,
  "requestContext": { "httpMethod": "GET", "path": "/users/u001", "resourcePath": "/users/{id}" }
}
EOF

######################################
# tests/events/create-user.json
######################################
cat > tests/events/create-user.json << 'EOF'
{
  "httpMethod": "POST",
  "path": "/users",
  "pathParameters": null,
  "headers": { "Content-Type": "application/json" },
  "body": "{\"name\": \"Taro\", \"email\": \"taro@example.com\"}",
  "isBase64Encoded": false,
  "requestContext": { "httpMethod": "POST", "path": "/users", "resourcePath": "/users" }
}
EOF

######################################
# env/local.json
######################################
cat > env/local.json << 'EOF'
{
  "Parameters": {
    "DYNAMODB_ENDPOINT": "http://dynamodb-local:8000",
    "SQS_ENDPOINT": "http://elasticmq:9324",
    "S3_ENDPOINT": "http://minio:9000",
    "AWS_ACCESS_KEY_ID": "test",
    "AWS_SECRET_ACCESS_KEY": "test",
    "AWS_DEFAULT_REGION": "ap-northeast-1",
    "USERS_TABLE": "Users",
    "QUEUE_URL": "http://elasticmq:9324/000000000000/user-events-queue"
  }
}
EOF

echo ""
echo "✅ 全ファイル生成完了"
echo ""
echo "次のステップ:"
echo "  make up      # コンテナ起動"
echo "  make shell   # コンテナに入る"
echo "  make install # npm install"
