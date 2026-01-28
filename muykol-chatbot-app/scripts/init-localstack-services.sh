#!/bin/bash

# Initialize LocalStack Services - Simplified Version
# Creates essential AWS resources for testing

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}⚙️  Initializing LocalStack Services${NC}"
echo -e "${BLUE}===================================${NC}"

# Check if LocalStack is running
if ! curl -s http://localhost:4566/_localstack/health >/dev/null; then
    echo -e "${RED}❌ LocalStack is not running. Please start it first with:${NC}"
    echo -e "${YELLOW}   ./scripts/start-localstack.sh${NC}"
    exit 1
fi

# Install awslocal if not available
if ! command -v awslocal >/dev/null 2>&1; then
    echo -e "${YELLOW}📦 Installing awslocal...${NC}"
    pip3 install awscli-local
fi

# Set AWS environment variables
export AWS_ENDPOINT_URL=http://localhost:4566
export AWS_REGION=us-east-1
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test

echo -e "${YELLOW}🗄️  Creating DynamoDB Tables...${NC}"

# Create UserProfiles table
echo "Creating UserProfiles table..."
awslocal dynamodb create-table \
  --table-name FaithChatbot-UserProfiles \
  --attribute-definitions \
    AttributeName=user_id,AttributeType=S \
    AttributeName=email,AttributeType=S \
  --key-schema \
    AttributeName=user_id,KeyType=HASH \
  --global-secondary-indexes \
    IndexName=EmailIndex,KeySchema=[{AttributeName=email,KeyType=HASH}],Projection={ProjectionType=ALL},ProvisionedThroughput={ReadCapacityUnits=5,WriteCapacityUnits=5} \
  --provisioned-throughput \
    ReadCapacityUnits=5,WriteCapacityUnits=5 \
  --region us-east-1 >/dev/null 2>&1 || echo "Table may already exist"

# Create ConversationSessions table
echo "Creating ConversationSessions table..."
awslocal dynamodb create-table \
  --table-name FaithChatbot-ConversationSessions \
  --attribute-definitions \
    AttributeName=session_id,AttributeType=S \
    AttributeName=user_id,AttributeType=S \
    AttributeName=created_at,AttributeType=S \
  --key-schema \
    AttributeName=session_id,KeyType=HASH \
  --global-secondary-indexes \
    IndexName=UserIndex,KeySchema=[{AttributeName=user_id,KeyType=HASH},{AttributeName=created_at,KeyType=RANGE}],Projection={ProjectionType=ALL},ProvisionedThroughput={ReadCapacityUnits=5,WriteCapacityUnits=5} \
  --provisioned-throughput \
    ReadCapacityUnits=5,WriteCapacityUnits=5 \
  --region us-east-1 >/dev/null 2>&1 || echo "Table may already exist"

echo -e "${YELLOW}📨 Creating SQS Queues...${NC}"

# Create DLQ first
echo "Creating Dead Letter Queue..."
awslocal sqs create-queue \
  --queue-name FaithChatbot-PrayerRequests-DLQ \
  --region us-east-1 >/dev/null 2>&1 || echo "Queue may already exist"

# Get DLQ ARN
DLQ_URL=$(awslocal sqs get-queue-url --queue-name FaithChatbot-PrayerRequests-DLQ --region us-east-1 --output text --query 'QueueUrl' 2>/dev/null || echo "")
if [ ! -z "$DLQ_URL" ]; then
    DLQ_ARN=$(awslocal sqs get-queue-attributes --queue-url "$DLQ_URL" --attribute-names QueueArn --region us-east-1 --output text --query 'Attributes.QueueArn' 2>/dev/null || echo "")
fi

# Create main queue
echo "Creating Prayer Requests Queue..."
if [ ! -z "$DLQ_ARN" ]; then
    awslocal sqs create-queue \
      --queue-name FaithChatbot-PrayerRequests \
      --attributes '{
        "VisibilityTimeoutSeconds": "300",
        "MessageRetentionPeriod": "1209600",
        "ReceiveMessageWaitTimeSeconds": "20",
        "RedrivePolicy": "{\"deadLetterTargetArn\":\"'$DLQ_ARN'\",\"maxReceiveCount\":3}"
      }' \
      --region us-east-1 >/dev/null 2>&1 || echo "Queue may already exist"
else
    awslocal sqs create-queue \
      --queue-name FaithChatbot-PrayerRequests \
      --region us-east-1 >/dev/null 2>&1 || echo "Queue may already exist"
fi

echo -e "${YELLOW}📧 Setting up SES...${NC}"

# Verify email addresses
echo "Verifying email addresses..."
awslocal ses verify-email-identity \
  --email-address noreply@faithchatbot.local \
  --region us-east-1 >/dev/null 2>&1 || echo "Email may already be verified"

awslocal ses verify-email-identity \
  --email-address test@example.com \
  --region us-east-1 >/dev/null 2>&1 || echo "Email may already be verified"

echo -e "${YELLOW}🔐 Creating Secrets...${NC}"

# Create basic secrets
echo "Creating database config secret..."
awslocal secretsmanager create-secret \
  --name "faith-chatbot/database-config" \
  --description "Database configuration" \
  --secret-string '{
    "host": "localhost",
    "port": 5432,
    "database": "faithchatbot_dev",
    "username": "dev",
    "password": "devpass"
  }' \
  --region us-east-1 >/dev/null 2>&1 || echo "Secret may already exist"

echo "Creating API keys secret..."
awslocal secretsmanager create-secret \
  --name "faith-chatbot/api-keys" \
  --description "API keys for external services" \
  --secret-string '{
    "jwt_secret": "dev-jwt-secret-key-change-in-production",
    "telegram_bot_token": "dev-telegram-token"
  }' \
  --region us-east-1 >/dev/null 2>&1 || echo "Secret may already exist"

# Test basic operations
echo -e "${YELLOW}🧪 Testing Basic Operations...${NC}"

# Test DynamoDB
echo "Testing DynamoDB..."
TABLES=$(awslocal dynamodb list-tables --region us-east-1 --output text --query 'TableNames' 2>/dev/null || echo "")
if echo "$TABLES" | grep -q "FaithChatbot-UserProfiles"; then
    echo -e "${GREEN}✅ DynamoDB tables created successfully${NC}"
else
    echo -e "${RED}❌ DynamoDB table creation failed${NC}"
fi

# Test SQS
echo "Testing SQS..."
QUEUES=$(awslocal sqs list-queues --region us-east-1 --output text --query 'QueueUrls' 2>/dev/null || echo "")
if echo "$QUEUES" | grep -q "FaithChatbot-PrayerRequests"; then
    echo -e "${GREEN}✅ SQS queues created successfully${NC}"
else
    echo -e "${RED}❌ SQS queue creation failed${NC}"
fi

# Test SES
echo "Testing SES..."
EMAILS=$(awslocal ses list-verified-email-addresses --region us-east-1 --output text --query 'VerifiedEmailAddresses' 2>/dev/null || echo "")
if echo "$EMAILS" | grep -q "noreply@faithchatbot.local"; then
    echo -e "${GREEN}✅ SES email verification successful${NC}"
else
    echo -e "${RED}❌ SES email verification failed${NC}"
fi

# Test Secrets Manager
echo "Testing Secrets Manager..."
SECRETS=$(awslocal secretsmanager list-secrets --region us-east-1 --output text --query 'SecretList[].Name' 2>/dev/null || echo "")
if echo "$SECRETS" | grep -q "faith-chatbot/database-config"; then
    echo -e "${GREEN}✅ Secrets Manager setup successful${NC}"
else
    echo -e "${RED}❌ Secrets Manager setup failed${NC}"
fi

echo ""
echo -e "${GREEN}🎉 LocalStack services initialized!${NC}"
echo -e "${BLUE}===================================${NC}"
echo -e "${YELLOW}Available Resources:${NC}"
echo "  • DynamoDB Tables: FaithChatbot-UserProfiles, FaithChatbot-ConversationSessions"
echo "  • SQS Queues: FaithChatbot-PrayerRequests, FaithChatbot-PrayerRequests-DLQ"
echo "  • SES Verified Emails: noreply@faithchatbot.local, test@example.com"
echo "  • Secrets: faith-chatbot/database-config, faith-chatbot/api-keys"
echo ""
echo -e "${YELLOW}Test Commands:${NC}"
echo "  • List tables: awslocal dynamodb list-tables --region us-east-1"
echo "  • List queues: awslocal sqs list-queues --region us-east-1"
echo "  • List secrets: awslocal secretsmanager list-secrets --region us-east-1"
echo ""
echo -e "${BLUE}Ready for development and testing!${NC}"