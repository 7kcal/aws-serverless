// tests/unit/update-user.test.ts
import { APIGatewayProxyEvent } from 'aws-lambda';

const mockSend = jest.fn();
jest.mock('@aws-sdk/client-dynamodb', () => ({
  DynamoDBClient: jest.fn(() => ({})),
}));
jest.mock('@aws-sdk/lib-dynamodb', () => ({
  DynamoDBDocumentClient: { from: jest.fn(() => ({ send: mockSend })) },
  UpdateCommand: jest.fn((input) => input),
}));
process.env.USERS_TABLE = 'Users';

import { handler } from '../../src/handlers/update-user';

const createEvent = (
  pathParams?: Record<string, string>,
  body?: string
): APIGatewayProxyEvent =>
  ({
    pathParameters: pathParams ?? null,
    headers: { 'Content-Type': 'application/json' },
    body: body ?? null,
    httpMethod: 'PUT',
  } as unknown as APIGatewayProxyEvent);

describe('PUT /users/{id}', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('200: ユーザーが更新された場合', async () => {
    const mockUser = {
      userId: 'u001',
      name: 'Taro Updated',
      email: 'taro@example.com',
      updatedAt: '2026-05-13T08:00:00.000Z',
    };
    mockSend.mockResolvedValue({ Attributes: mockUser });

    const result = await handler(
      createEvent(
        { id: 'u001' },
        JSON.stringify({ name: 'Taro Updated' })
      )
    );

    expect(result.statusCode).toBe(200);
    expect(JSON.parse(result.body)).toEqual(mockUser);
  });

  it('200: メールだけを更新', async () => {
    const mockUser = {
      userId: 'u001',
      name: 'Taro',
      email: 'newemail@example.com',
      updatedAt: '2026-05-13T08:00:00.000Z',
    };
    mockSend.mockResolvedValue({ Attributes: mockUser });

    const result = await handler(
      createEvent(
        { id: 'u001' },
        JSON.stringify({ email: 'newemail@example.com' })
      )
    );

    expect(result.statusCode).toBe(200);
  });

  it('400: body が空の場合', async () => {
    const result = await handler(createEvent({ id: 'u001' }, ''));

    expect(result.statusCode).toBe(400);
  });

  it('400: 両方のフィールドが空の場合', async () => {
    const result = await handler(
      createEvent({ id: 'u001' }, JSON.stringify({}))
    );

    expect(result.statusCode).toBe(400);
    expect(result.body).toContain('At least one field');
  });

  it('400: パスパラメータが無い場合', async () => {
    const result = await handler(
      createEvent(
        undefined,
        JSON.stringify({ name: 'Taro' })
      )
    );

    expect(result.statusCode).toBe(400);
  });
});
