# LocalStack Setup Guide

## Overview

LocalStack provides a **fully functional local AWS cloud stack** for development and testing. Run AWS services locally without incurring cloud costs or requiring internet connectivity.

## Supported AWS Services

LocalStack includes the following AWS services:

### Core Services (Always Available)
- **S3**: Object storage
- **DynamoDB**: NoSQL database
- **Lambda**: Serverless functions
- **SQS**: Message queuing
- **SNS**: Pub/sub messaging
- **CloudWatch**: Monitoring and logs
- **Secrets Manager**: Secret storage
- **Systems Manager (SSM)**: Parameter store
- **EventBridge**: Event bus

### Additional Services (LocalStack Pro)
- RDS, Aurora, Redshift
- ECS, EKS, ECR
- Cognito, API Gateway
- Step Functions, Kinesis
- And many more...

## Quick Start

### 1. Start LocalStack

```bash
# Start all homelab services including LocalStack
make up

# Or start only LocalStack
docker compose up -d localstack
```

### 2. Verify LocalStack is Running

```bash
# Check container status
docker compose ps localstack

# Check health
curl http://localhost:4566/_localstack/health

# Expected output:
# {"services": {"s3": "running", "dynamodb": "running", ...}}
```

### 3. Configure AWS CLI

Create AWS CLI profile for LocalStack:

```bash
# Configure AWS CLI
aws configure --profile localstack

# Use these values:
# AWS Access Key ID: test
# AWS Secret Access Key: test
# Default region name: us-east-1
# Default output format: json
```

Or set environment variables:

```bash
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1
export AWS_ENDPOINT_URL=http://localhost:4566
```

## Usage Examples

### S3 Operations

```bash
# Create bucket
aws --endpoint-url=http://localhost:4566 s3 mb s3://my-bucket

# List buckets
aws --endpoint-url=http://localhost:4566 s3 ls

# Upload file
aws --endpoint-url=http://localhost:4566 s3 cp file.txt s3://my-bucket/

# Download file
aws --endpoint-url=http://localhost:4566 s3 cp s3://my-bucket/file.txt ./

# List objects in bucket
aws --endpoint-url=http://localhost:4566 s3 ls s3://my-bucket/
```

### DynamoDB Operations

```bash
# Create table
aws --endpoint-url=http://localhost:4566 dynamodb create-table \
    --table-name Users \
    --attribute-definitions \
        AttributeName=UserId,AttributeType=S \
    --key-schema \
        AttributeName=UserId,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST

# Put item
aws --endpoint-url=http://localhost:4566 dynamodb put-item \
    --table-name Users \
    --item '{"UserId": {"S": "user123"}, "Name": {"S": "John Doe"}}'

# Get item
aws --endpoint-url=http://localhost:4566 dynamodb get-item \
    --table-name Users \
    --key '{"UserId": {"S": "user123"}}'

# Scan table
aws --endpoint-url=http://localhost:4566 dynamodb scan --table-name Users
```

### Lambda Operations

```bash
# Create Lambda function (Node.js example)
# First, create index.js:
cat > index.js << 'EOF'
exports.handler = async (event) => {
    return {
        statusCode: 200,
        body: JSON.stringify({ message: 'Hello from LocalStack!' })
    };
};
EOF

# Zip the function
zip function.zip index.js

# Create Lambda function
aws --endpoint-url=http://localhost:4566 lambda create-function \
    --function-name my-function \
    --runtime nodejs18.x \
    --role arn:aws:iam::000000000000:role/lambda-role \
    --handler index.handler \
    --zip-file fileb://function.zip

# Invoke Lambda function
aws --endpoint-url=http://localhost:4566 lambda invoke \
    --function-name my-function \
    output.txt

# View output
cat output.txt
```

### SQS Operations

```bash
# Create queue
aws --endpoint-url=http://localhost:4566 sqs create-queue --queue-name my-queue

# Send message
aws --endpoint-url=http://localhost:4566 sqs send-message \
    --queue-url http://localhost:4566/000000000000/my-queue \
    --message-body "Hello from SQS"

# Receive message
aws --endpoint-url=http://localhost:4566 sqs receive-message \
    --queue-url http://localhost:4566/000000000000/my-queue
```

### SNS Operations

```bash
# Create topic
aws --endpoint-url=http://localhost:4566 sns create-topic --name my-topic

# Subscribe to topic
aws --endpoint-url=http://localhost:4566 sns subscribe \
    --topic-arn arn:aws:sns:us-east-1:000000000000:my-topic \
    --protocol email \
    --notification-endpoint test@example.com

# Publish message
aws --endpoint-url=http://localhost:4566 sns publish \
    --topic-arn arn:aws:sns:us-east-1:000000000000:my-topic \
    --message "Hello from SNS"
```

## SDK Configuration

### Python (boto3)

```python
import boto3

# Configure boto3 to use LocalStack
s3 = boto3.client(
    's3',
    endpoint_url='http://localhost:4566',
    aws_access_key_id='test',
    aws_secret_access_key='test',
    region_name='us-east-1'
)

# Create bucket
s3.create_bucket(Bucket='my-bucket')

# Upload file
s3.put_object(Bucket='my-bucket', Key='file.txt', Body=b'Hello World')

# Download file
response = s3.get_object(Bucket='my-bucket', Key='file.txt')
content = response['Body'].read()
print(content)
```

### Node.js (AWS SDK v3)

```javascript
import { S3Client, CreateBucketCommand, PutObjectCommand } from "@aws-sdk/client-s3";

// Configure S3 client for LocalStack
const s3Client = new S3Client({
  endpoint: "http://localhost:4566",
  region: "us-east-1",
  credentials: {
    accessKeyId: "test",
    secretAccessKey: "test"
  },
  forcePathStyle: true
});

// Create bucket
await s3Client.send(new CreateBucketCommand({ Bucket: "my-bucket" }));

// Upload file
await s3Client.send(new PutObjectCommand({
  Bucket: "my-bucket",
  Key: "file.txt",
  Body: "Hello World"
}));
```

### Java (AWS SDK v2)

```java
import software.amazon.awssdk.auth.credentials.AwsBasicCredentials;
import software.amazon.awssdk.auth.credentials.StaticCredentialsProvider;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.CreateBucketRequest;

import java.net.URI;

// Configure S3 client for LocalStack
S3Client s3 = S3Client.builder()
    .endpointOverride(URI.create("http://localhost:4566"))
    .region(Region.US_EAST_1)
    .credentialsProvider(StaticCredentialsProvider.create(
        AwsBasicCredentials.create("test", "test")))
    .build();

// Create bucket
s3.createBucket(CreateBucketRequest.builder()
    .bucket("my-bucket")
    .build());
```

## Data Persistence

LocalStack data is persisted in the Docker volume `localstack-data`. This means:

- ✅ S3 buckets and objects survive container restarts
- ✅ DynamoDB tables and data survive container restarts
- ✅ Lambda functions survive container restarts
- ✅ All AWS resources are preserved

### Backup LocalStack Data

```bash
# Create backup
docker run --rm -v homelab_localstack-data:/data -v $(pwd):/backup alpine \
    tar czf /backup/localstack-backup-$(date +%Y%m%d).tar.gz -C /data .

# Restore backup
docker run --rm -v homelab_localstack-data:/data -v $(pwd):/backup alpine \
    tar xzf /backup/localstack-backup-YYYYMMDD.tar.gz -C /data
```

## Monitoring

LocalStack integrates with the homelab monitoring stack:

- **Health Checks**: Available at `http://localhost:4566/_localstack/health`
- **Prometheus Metrics**: (if LocalStack Pro)
- **Logs**: Sent to Vector → Elasticsearch/Loki

### Check Service Status

```bash
# View LocalStack logs
docker compose logs -f localstack

# Check which services are running
curl http://localhost:4566/_localstack/health | jq
```

## Troubleshooting

### LocalStack Not Starting

```bash
# Check logs
docker compose logs localstack

# Common issues:
# 1. Port 4566 already in use
# 2. Docker socket not accessible
# 3. Insufficient memory
```

### AWS CLI Commands Failing

```bash
# Verify endpoint is accessible
curl http://localhost:4566/_localstack/health

# Check AWS CLI configuration
aws configure list --profile localstack

# Test with explicit endpoint
aws --endpoint-url=http://localhost:4566 s3 ls
```

### Data Not Persisting

```bash
# Check if persistence is enabled
docker compose exec localstack env | grep PERSISTENCE

# Verify volume exists
docker volume ls | grep localstack

# Check volume contents
docker run --rm -v homelab_localstack-data:/data alpine ls -la /data
```

## Advanced Configuration

### Enable Additional Services

Edit `.env` and add services:

```bash
LOCALSTACK_SERVICES=s3,dynamodb,lambda,sqs,sns,cloudwatch,logs,events,secretsmanager,ssm,rds,kinesis
```

### Enable Debug Mode

```bash
LOCALSTACK_DEBUG=1
```

### Use LocalStack Pro

If you have a LocalStack Pro license:

```bash
# Add to .env
LOCALSTACK_API_KEY=your-api-key-here

# Restart LocalStack
docker compose restart localstack
```

## Integration with CI/CD

LocalStack is perfect for CI/CD pipelines:

```yaml
# GitHub Actions example
- name: Start LocalStack
  run: |
    docker compose up -d localstack
    docker compose exec localstack wait-for-localstack

- name: Run tests
  env:
    AWS_ENDPOINT_URL: http://localhost:4566
  run: |
    pytest tests/
```

## Cost Savings

Using LocalStack for development:

- ✅ **Zero AWS costs** during development
- ✅ **Faster iteration** (no network latency)
- ✅ **Offline development** (no internet required)
- ✅ **Reproducible environments** (consistent across team)
- ✅ **Safe testing** (no risk of affecting production)

## Resources

- **LocalStack Docs**: https://docs.localstack.cloud/
- **AWS CLI Reference**: https://docs.aws.amazon.com/cli/
- **LocalStack GitHub**: https://github.com/localstack/localstack
- **LocalStack Pro**: https://localstack.cloud/pricing/

---

**Need Help?** Check logs: `docker compose logs localstack`
