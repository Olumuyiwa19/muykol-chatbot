# LocalStack Testing Guide for Phase 1 Infrastructure

This guide explains how to use LocalStack to test the Phase 1 infrastructure implementation locally before deploying to AWS.

## 🚀 Quick Start

### 1. Prerequisites

Make sure you have the following installed:
- Docker and Docker Compose
- Python 3.9+
- AWS CLI (optional, for awslocal)

### 2. Start LocalStack Testing Environment

Run the comprehensive setup script:

```bash
# Make scripts executable
chmod +x scripts/*.sh localstack/*.sh scripts/*.py

# Start LocalStack and run all tests
./scripts/setup-localstack-testing.sh
```

This script will:
- Start LocalStack with all required AWS services
- Initialize DynamoDB tables, SQS queues, SES, Cognito, and Secrets Manager
- Run comprehensive infrastructure tests
- Provide test users and configuration

### 3. Manual Testing (Alternative)

If you prefer to run components individually:

```bash
# Start LocalStack
docker-compose up -d localstack redis

# Wait for LocalStack to be ready
curl http://localhost:4566/_localstack/health

# Initialize services
./localstack/01-create-dynamodb-tables.sh
./localstack/02-create-sqs-queues.sh
./localstack/03-setup-ses.sh
./localstack/04-setup-secrets.sh
./localstack/05-setup-cognito.sh

# Run tests
./localstack/06-test-infrastructure.sh
python3 scripts/test-phase1-infrastructure.py
```

## 🏗️ What Gets Tested

### DynamoDB Tables
- **UserProfiles**: User account information with email GSI
- **ConversationSessions**: Chat sessions with user GSI and TTL
- **PrayerRequests**: Prayer requests with user and status GSIs
- **ConsentLogs**: GDPR compliance audit trail

### SQS Queues
- **FaithChatbot-PrayerRequests**: Main prayer request processing queue
- **FaithChatbot-PrayerRequests-DLQ**: Dead letter queue for failed messages
- Message sending and receiving operations

### SES Configuration
- Verified email addresses for sending
- Email templates (Welcome, Prayer Request Notification, Data Export)
- Email sending functionality

### Cognito User Pool
- User pool with proper password policy
- Web client configuration with OAuth flows
- Test users with credentials
- Custom attributes for prayer connect consent

### Secrets Manager
- Database configuration secrets
- API keys and JWT configuration
- Email service configuration
- Third-party integration secrets

### Integration Tests
- Complete user workflow simulation
- Cross-service data flow testing
- End-to-end scenarios

## 🔧 Configuration

### Environment Variables

The LocalStack environment uses these variables:

```bash
export AWS_ENDPOINT_URL=http://localhost:4566
export AWS_REGION=us-east-1
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export REDIS_URL=redis://localhost:6379
```

### Test Users

After running the Cognito setup, you'll have these test users:

- **Email**: `testuser@faithchatbot.local`
- **Password**: `TestPass123!`

- **Email**: `john.doe@faithchatbot.local`
- **Password**: `TestPass123!`

## 🧪 Testing Your Code

### Python SDK Testing

```python
import boto3

# Configure for LocalStack
dynamodb = boto3.client(
    'dynamodb',
    endpoint_url='http://localhost:4566',
    region_name='us-east-1',
    aws_access_key_id='test',
    aws_secret_access_key='test'
)

# Test DynamoDB operations
response = dynamodb.scan(TableName='FaithChatbot-UserProfiles')
print(f"Found {response['Count']} users")
```

### FastAPI Integration

```python
import os
import boto3
from fastapi import FastAPI

app = FastAPI()

# Use LocalStack in development
endpoint_url = os.getenv('AWS_ENDPOINT_URL')
dynamodb = boto3.resource(
    'dynamodb',
    endpoint_url=endpoint_url,
    region_name='us-east-1',
    aws_access_key_id='test',
    aws_secret_access_key='test'
)

@app.get("/users")
async def get_users():
    table = dynamodb.Table('FaithChatbot-UserProfiles')
    response = table.scan()
    return response['Items']
```

## 📊 Monitoring and Debugging

### LocalStack Dashboard

Access the LocalStack dashboard at: http://localhost:4566

### Health Check

Check service status:
```bash
curl http://localhost:4566/_localstack/health
```

### Service Logs

View LocalStack logs:
```bash
docker-compose logs localstack
```

### AWS CLI Commands

Use `awslocal` for LocalStack-specific commands:

```bash
# List DynamoDB tables
awslocal dynamodb list-tables --region us-east-1

# List SQS queues
awslocal sqs list-queues --region us-east-1

# List Cognito user pools
awslocal cognito-idp list-user-pools --max-items 10 --region us-east-1

# Get queue messages
awslocal sqs receive-message --queue-url http://localhost:4566/000000000000/FaithChatbot-PrayerRequests --region us-east-1
```

## 🔄 Development Workflow

### 1. Start Environment
```bash
./scripts/setup-localstack-testing.sh
```

### 2. Develop Your Code
- Use the LocalStack endpoints in your application
- Test against the local AWS services
- Iterate quickly without AWS costs

### 3. Run Tests
```bash
# Run infrastructure tests
python3 scripts/test-phase1-infrastructure.py

# Run your application tests
pytest tests/
```

### 4. Debug Issues
- Check LocalStack logs
- Verify service health
- Use AWS CLI commands to inspect data

### 5. Deploy to AWS
- Update environment variables to use real AWS
- Deploy using Terraform
- Run integration tests against real AWS

## 🚨 Troubleshooting

### Common Issues

**LocalStack not starting:**
```bash
# Check Docker
docker ps

# Restart LocalStack
docker-compose restart localstack

# Check logs
docker-compose logs localstack
```

**Services not available:**
```bash
# Wait for services to be ready
curl http://localhost:4566/_localstack/health

# Check specific service
awslocal dynamodb list-tables --region us-east-1
```

**Permission errors:**
```bash
# Make scripts executable
chmod +x scripts/*.sh localstack/*.sh scripts/*.py
```

**Python dependencies:**
```bash
# Install required packages
pip install boto3 requests localstack awscli-local
```

## 📈 Performance Testing

### Load Testing with LocalStack

```python
import asyncio
import aiohttp
import time

async def test_load():
    """Test API performance with LocalStack"""
    async with aiohttp.ClientSession() as session:
        tasks = []
        for i in range(100):
            task = session.get('http://localhost:8000/health')
            tasks.append(task)
        
        start_time = time.time()
        responses = await asyncio.gather(*tasks)
        end_time = time.time()
        
        print(f"100 requests completed in {end_time - start_time:.2f}s")
```

## 🎯 Next Steps

Once your LocalStack testing is successful:

1. **Implement Backend API** (Phase 1 Task 2.1-2.3)
2. **Add Emotion Classification** (Phase 1 Task 3.1-3.3)
3. **Test with Real AWS** using Terraform
4. **Set up CI/CD Pipeline** for automated testing

## 📚 Additional Resources

- [LocalStack Documentation](https://docs.localstack.cloud/)
- [AWS SDK for Python (Boto3)](https://boto3.amazonaws.com/v1/documentation/api/latest/index.html)
- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [DynamoDB Local Development](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/DynamoDBLocal.html)

---

**Happy Testing! 🚀** The LocalStack environment provides a complete AWS simulation for developing and testing the Faith Motivator Chatbot infrastructure locally.