// src/shared/aws-clients.ts
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient } from '@aws-sdk/lib-dynamodb';
import { SQSClient } from '@aws-sdk/client-sqs';

const localCredentials = {
  accessKeyId: 'test',
  secretAccessKey: 'test',
};

function buildOptions(endpointEnvVar: string) {
  const endpoint = process.env[endpointEnvVar];
  // ★ 空文字もfalsy扱いで本番では何も設定しない
  if (!endpoint) return {};
  return { endpoint, credentials: localCredentials };
}

// DynamoDB
const ddbClient = new DynamoDBClient(buildOptions('DYNAMODB_ENDPOINT'));
export const docClient = DynamoDBDocumentClient.from(ddbClient);

// SQS
export const sqsClient = new SQSClient(buildOptions('SQS_ENDPOINT'));
