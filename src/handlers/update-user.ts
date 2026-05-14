// src/handlers/update-user.ts
import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { UpdateCommand } from '@aws-sdk/lib-dynamodb';
import { docClient } from '../shared/aws-clients';

const TABLE_NAME = process.env.USERS_TABLE!;

interface UpdateUserRequest {
  name?: string;
  email?: string;
}

export const handler = async (
  event: APIGatewayProxyEvent
): Promise<APIGatewayProxyResult> => {
  console.log('Event:', JSON.stringify(event, null, 2));

  const userId = event.pathParameters?.id;
  if (!userId) {
    return {
      statusCode: 400,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ message: 'Missing path parameter: id' }),
    };
  }

  if (!event.body) {
    return {
      statusCode: 400,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ message: 'Missing request body' }),
    };
  }

  try {
    const { name, email }: UpdateUserRequest = JSON.parse(event.body);

    // 最低1つのフィールドが必要
    if (!name && !email) {
      return {
        statusCode: 400,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ message: 'At least one field (name or email) is required' }),
      };
    }

    // DynamoDB の UPDATE コマンド用に動的に属性を構築
    const updateExpression: string[] = [];
    const expressionAttributeNames: Record<string, string> = {};
    const expressionAttributeValues: Record<string, unknown> = {};

    if (name) {
      updateExpression.push('#n = :name');
      expressionAttributeNames['#n'] = 'name';
      expressionAttributeValues[':name'] = name;
    }

    if (email) {
      updateExpression.push('#e = :email');
      expressionAttributeNames['#e'] = 'email';
      expressionAttributeValues[':email'] = email;
    }

    // 更新時刻も追加
    updateExpression.push('#u = :updatedAt');
    expressionAttributeNames['#u'] = 'updatedAt';
    expressionAttributeValues[':updatedAt'] = new Date().toISOString();

    const result = await docClient.send(
      new UpdateCommand({
        TableName: TABLE_NAME,
        Key: { userId },
        UpdateExpression: `SET ${updateExpression.join(', ')}`,
        ExpressionAttributeNames: expressionAttributeNames,
        ExpressionAttributeValues: expressionAttributeValues,
        ReturnValues: 'ALL_NEW',  // 更新後の全属性を返す
      })
    );

    return {
      statusCode: 200,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(result.Attributes),
    };
  } catch (error) {
    console.error('Error:', error);
    return {
      statusCode: 500,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ message: 'Internal server error' }),
    };
  }
};
