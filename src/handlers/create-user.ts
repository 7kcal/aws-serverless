// src/handlers/create-user.ts
import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { PutCommand } from '@aws-sdk/lib-dynamodb';
import { SendMessageCommand } from '@aws-sdk/client-sqs';
import { v4 as uuidv4 } from 'uuid';
import { docClient, sqsClient } from '../shared/aws-clients';

const TABLE_NAME = process.env.USERS_TABLE!;
const QUEUE_URL = process.env.QUEUE_URL!;

interface CreateUserRequest { name: string; email: string; }

export const handler = async (event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> => {
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
