#!/bin/bash

# Simple LocalStack Testing Script
# Tests basic functionality without complex dependencies

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🧪 Testing LocalStack Services${NC}"
echo -e "${BLUE}=============================${NC}"

# Set environment variables
export AWS_ENDPOINT_URL=http://localhost:4566
export AWS_REGION=us-east-1
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0

# Function to run test
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    echo -e "${YELLOW}Testing: $test_name${NC}"
    
    if eval "$test_command" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ PASS: $test_name${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}❌ FAIL: $test_name${NC}"
        ((TESTS_FAILED++))
    fi
}

# Check if LocalStack is running
if ! curl -s http://localhost:4566/_localstack/health >/dev/null; then
    echo -e "${RED}❌ LocalStack is not running. Please start it first.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ LocalStack is running${NC}"
echo ""

# Test DynamoDB
echo -e "${YELLOW}🗄️  Testing DynamoDB...${NC}"

run_test "DynamoDB service available" \
    "awslocal dynamodb list-tables --region us-east-1"

run_test "UserProfiles table exists" \
    "awslocal dynamodb describe-table --table-name FaithChatbot-UserProfiles --region us-east-1"

# Test DynamoDB operations
echo "Testing DynamoDB operations..."
TEST_USER_ID="test-user-$(date +%s)"

# Insert test item
awslocal dynamodb put-item \
    --table-name FaithChatbot-UserProfiles \
    --item '{
        "user_id": {"S": "'$TEST_USER_ID'"},
        "email": {"S": "test@example.com"},
        "given_name": {"S": "Test"},
        "family_name": {"S": "User"},
        "created_at": {"S": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}
    }' \
    --region us-east-1 >/dev/null 2>&1

run_test "DynamoDB put/get operations" \
    "awslocal dynamodb get-item --table-name FaithChatbot-UserProfiles --key '{\"user_id\":{\"S\":\"'$TEST_USER_ID'\"}}' --region us-east-1"

echo ""

# Test SQS
echo -e "${YELLOW}📨 Testing SQS...${NC}"

run_test "SQS service available" \
    "awslocal sqs list-queues --region us-east-1"

run_test "Prayer Requests queue exists" \
    "awslocal sqs get-queue-url --queue-name FaithChatbot-PrayerRequests --region us-east-1"

# Test SQS operations
echo "Testing SQS operations..."
QUEUE_URL=$(awslocal sqs get-queue-url --queue-name FaithChatbot-PrayerRequests --region us-east-1 --output text --query 'QueueUrl' 2>/dev/null || echo "")

if [ ! -z "$QUEUE_URL" ]; then
    # Send test message
    awslocal sqs send-message \
        --queue-url "$QUEUE_URL" \
        --message-body '{"test": "message", "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}' \
        --region us-east-1 >/dev/null 2>&1
    
    run_test "SQS send/receive operations" \
        "awslocal sqs receive-message --queue-url '$QUEUE_URL' --region us-east-1"
else
    echo -e "${RED}❌ Could not get queue URL${NC}"
    ((TESTS_FAILED++))
fi

echo ""

# Test SES
echo -e "${YELLOW}📧 Testing SES...${NC}"

run_test "SES service available" \
    "awslocal ses list-verified-email-addresses --region us-east-1"

run_test "Test email verified" \
    "awslocal ses list-verified-email-addresses --region us-east-1 | grep -q 'noreply@faithchatbot.local'"

# Test email sending
run_test "SES send email" \
    "awslocal ses send-email --source 'noreply@faithchatbot.local' --destination 'ToAddresses=test@example.com' --message 'Subject={Data=\"Test Email\"},Body={Text={Data=\"Test message\"}}' --region us-east-1"

echo ""

# Test Secrets Manager
echo -e "${YELLOW}🔐 Testing Secrets Manager...${NC}"

run_test "Secrets Manager service available" \
    "awslocal secretsmanager list-secrets --region us-east-1"

run_test "Database config secret exists" \
    "awslocal secretsmanager describe-secret --secret-id 'faith-chatbot/database-config' --region us-east-1"

run_test "Can retrieve secret value" \
    "awslocal secretsmanager get-secret-value --secret-id 'faith-chatbot/database-config' --region us-east-1"

echo ""

# Test Results Summary
echo -e "${BLUE}📊 Test Results Summary${NC}"
echo -e "${BLUE}======================${NC}"
echo -e "${GREEN}Tests Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Tests Failed: $TESTS_FAILED${NC}"
echo -e "Total Tests: $((TESTS_PASSED + TESTS_FAILED))"

if [ $TESTS_FAILED -eq 0 ]; then
    echo ""
    echo -e "${GREEN}🎉 All tests passed! LocalStack is working correctly.${NC}"
    echo ""
    echo -e "${YELLOW}Next Steps:${NC}"
    echo "1. Start developing your FastAPI backend"
    echo "2. Use these LocalStack services for testing"
    echo "3. Run your application with AWS_ENDPOINT_URL=http://localhost:4566"
    echo ""
    echo -e "${BLUE}Environment Variables:${NC}"
    echo "export AWS_ENDPOINT_URL=http://localhost:4566"
    echo "export AWS_REGION=us-east-1"
    echo "export AWS_ACCESS_KEY_ID=test"
    echo "export AWS_SECRET_ACCESS_KEY=test"
    
    exit 0
else
    echo ""
    echo -e "${RED}❌ Some tests failed. Please check the LocalStack setup.${NC}"
    echo ""
    echo -e "${YELLOW}Troubleshooting:${NC}"
    echo "1. Check LocalStack logs: docker-compose -f docker-compose.localstack.yml logs localstack"
    echo "2. Restart LocalStack: ./scripts/start-localstack.sh"
    echo "3. Reinitialize services: ./scripts/init-localstack-services.sh"
    
    exit 1
fi