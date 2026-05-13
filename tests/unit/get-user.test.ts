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
