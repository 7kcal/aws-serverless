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
      bundling: { minify: true, sourceMap: true },
    };

    const getUserFn = new NodejsFunction(this, 'GetUserFunction', {
      ...commonLambdaProps,
      entry: path.join(__dirname, '../src/handlers/get-user.ts'),
      handler: 'handler',
      environment: { USERS_TABLE: usersTable.tableName, DYNAMODB_ENDPOINT: '' },
    });
    usersTable.grantReadData(getUserFn);

    const createUserFn = new NodejsFunction(this, 'CreateUserFunction', {
      ...commonLambdaProps,
      entry: path.join(__dirname, '../src/handlers/create-user.ts'),
      handler: 'handler',
      environment: {
        USERS_TABLE: usersTable.tableName,
        QUEUE_URL: userEventsQueue.queueUrl,
        DYNAMODB_ENDPOINT: '',
        SQS_ENDPOINT: ''
      },
    });

    const updateUserFn = new NodejsFunction(this, 'UpdateUserFunction', {
      ...commonLambdaProps,
      entry: path.join(__dirname, '../src/handlers/update-user.ts'),
      handler: 'handler',
      environment: {
        USERS_TABLE: usersTable.tableName,
        DYNAMODB_ENDPOINT: '',
      },
    });
    usersTable.grantWriteData(createUserFn);
    usersTable.grantWriteData(updateUserFn);
    userEventsQueue.grantSendMessages(createUserFn);

    const api = new apigw.RestApi(this, 'MyApi', {
      restApiName: 'ServerlessAPI',
      deployOptions: { stageName: 'v1' },
    });

    const users = api.root.addResource('users');
    users.addMethod('POST', new apigw.LambdaIntegration(createUserFn));
    const user = users.addResource('{id}');
    user.addMethod('GET', new apigw.LambdaIntegration(getUserFn));
    user.addMethod('PUT', new apigw.LambdaIntegration(updateUserFn));

    new cdk.CfnOutput(this, 'ApiUrl', { value: api.url });
    new cdk.CfnOutput(this, 'TableName', { value: usersTable.tableName });
  }
}
