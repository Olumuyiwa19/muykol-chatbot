#!/bin/bash

echo "🧪 Testing Faith Motivator Chatbot Infrastructure with LocalStack..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test results tracking
TESTS_PASSED=0
TESTS_FAILED=0

# Function to run test and track results
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    echo -e "${BLUE}Testing: $test_name${NC}"
    
    if eval "$test_command" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ PASS: $test_name${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}❌ FAIL: $test_name${NC}"
        ((TESTS_FAILED++))
    fi
    echo ""
}

# Wait for LocalStack to be ready
echo "Waiting for LocalStack to be fully ready..."
until curl -s http://localhost:4566/_localstack/health | grep -q '"status": "running"'; do
    echo "Waiting for LocalStack..."
    sleep 2
done

echo -e "${GREEN}LocalStack is ready! Starting infrastructure tests...${NC}"
echo ""

# Test 1: DynamoDB Tables
echo -e "${YELLOW}=== Testing DynamoDB Tables ===${NC}"

run_test "UserProfiles table exists" \
    "awslocal dynamodb describe-table --table-name FaithChatbot-UserProfiles --region us-east-1"

run_test "ConversationSessions table exists" \
    "awslocal dynamodb describe-table --table-name FaithChatbot-ConversationSessions --region us-east-1"

run_test "PrayerRequests table exists" \
    "awslocal dynamodb describe-table --table-name FaithChatbot-PrayerRequests --region us-east-1"

run_test "ConsentLogs table exists" \
    "awslocal dynamodb describe-table --table-name FaithChatbot-ConsentLogs --region us-east-1"

# Test DynamoDB operations
echo "Testing DynamoDB operations..."

# Insert test user profile
awslocal dynamodb put-item \
    --table-name FaithChatbot-UserProfiles \
    --item '{
        "user_id": {"S": "test-user-123"},
        "email": {"S": "test@example.com"},
        "given_name": {"S": "Test"},
        "family_name": {"S": "User"},
        "created_at": {"S": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"},
        "prayer_connect_consent": {"BOOL": false}
    }' \
    --region us-east-1

run_test "Can insert user profile" \
    "awslocal dynamodb get-item --table-name FaithChatbot-UserProfiles --key '{\"user_id\":{\"S\":\"test-user-123\"}}' --region us-east-1"

run_test "Can query user by email" \
    "awslocal dynamodb query --table-name FaithChatbot-UserProfiles --index-name EmailIndex --key-condition-expression 'email = :email' --expression-attribute-values '{\":email\":{\"S\":\"test@example.com\"}}' --region us-east-1"

# Test 2: SQS Queues
echo -e "${YELLOW}=== Testing SQS Queues ===${NC}"

run_test "Prayer Requests queue exists" \
    "awslocal sqs get-queue-url --queue-name FaithChatbot-PrayerRequests --region us-east-1"

run_test "Prayer Requests DLQ exists" \
    "awslocal sqs get-queue-url --queue-name FaithChatbot-PrayerRequests-DLQ --region us-east-1"

# Test SQS operations
echo "Testing SQS operations..."

QUEUE_URL=$(awslocal sqs get-queue-url --queue-name FaithChatbot-PrayerRequests --region us-east-1 --output text --query 'QueueUrl')

# Send test message
awslocal sqs send-message \
    --queue-url "$QUEUE_URL" \
    --message-body '{
        "user_id": "test-user-123",
        "prayer_text": "Please pray for my family",
        "consent_given": true,
        "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"
    }' \
    --region us-east-1

run_test "Can send message to prayer queue" \
    "awslocal sqs receive-message --queue-url '$QUEUE_URL' --region us-east-1"

# Test 3: SES Configuration
echo -e "${YELLOW}=== Testing SES Configuration ===${NC}"

run_test "Sender email is verified" \
    "awslocal ses list-verified-email-addresses --region us-east-1 | grep -q 'noreply@faithchatbot.local'"

run_test "Email templates exist" \
    "awslocal ses list-templates --region us-east-1 | grep -q 'WelcomeEmail'"

# Test SES operations
echo "Testing SES operations..."

run_test "Can send test email" \
    "awslocal ses send-email --source 'noreply@faithchatbot.local' --destination 'ToAddresses=test@example.com' --message 'Subject={Data=\"Test Email\"},Body={Text={Data=\"This is a test email from Faith Motivator Chatbot\"}}' --region us-east-1"

# Test 4: Secrets Manager
echo -e "${YELLOW}=== Testing Secrets Manager ===${NC}"

run_test "Database config secret exists" \
    "awslocal secretsmanager describe-secret --secret-id 'faith-chatbot/database-config' --region us-east-1"

run_test "API keys secret exists" \
    "awslocal secretsmanager describe-secret --secret-id 'faith-chatbot/api-keys' --region us-east-1"

run_test "JWT config secret exists" \
    "awslocal secretsmanager describe-secret --secret-id 'faith-chatbot/jwt-config' --region us-east-1"

# Test secret retrieval
echo "Testing secret retrieval..."

run_test "Can retrieve database config" \
    "awslocal secretsmanager get-secret-value --secret-id 'faith-chatbot/database-config' --region us-east-1"

# Test 5: Cognito User Pool
echo -e "${YELLOW}=== Testing Cognito User Pool ===${NC}"

# Get User Pool ID from environment or find it
if [ -z "$AWS_COGNITO_USER_POOL_ID" ]; then
    USER_POOL_ID=$(awslocal cognito-idp list-user-pools --max-items 10 --region us-east-1 --query 'UserPools[?Name==`FaithChatbot-UserPool-Dev`].Id' --output text)
else
    USER_POOL_ID=$AWS_COGNITO_USER_POOL_ID
fi

if [ ! -z "$USER_POOL_ID" ] && [ "$USER_POOL_ID" != "None" ]; then
    run_test "User Pool exists" \
        "awslocal cognito-idp describe-user-pool --user-pool-id '$USER_POOL_ID' --region us-east-1"
    
    run_test "User Pool Client exists" \
        "awslocal cognito-idp list-user-pool-clients --user-pool-id '$USER_POOL_ID' --region us-east-1"
    
    run_test "Test user exists" \
        "awslocal cognito-idp admin-get-user --user-pool-id '$USER_POOL_ID' --username 'testuser@faithchatbot.local' --region us-east-1"
else
    echo -e "${YELLOW}⚠️  Cognito User Pool not found. Run 05-setup-cognito.sh first.${NC}"
    ((TESTS_FAILED++))
fi

# Test 6: Integration Tests
echo -e "${YELLOW}=== Integration Tests ===${NC}"

# Test complete user workflow
echo "Testing complete user workflow..."

# Create conversation session
SESSION_ID="test-session-$(date +%s)"
awslocal dynamodb put-item \
    --table-name FaithChatbot-ConversationSessions \
    --item '{
        "session_id": {"S": "'$SESSION_ID'"},
        "user_id": {"S": "test-user-123"},
        "created_at": {"S": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"},
        "status": {"S": "active"},
        "message_count": {"N": "0"}
    }' \
    --region us-east-1

run_test "Can create conversation session" \
    "awslocal dynamodb get-item --table-name FaithChatbot-ConversationSessions --key '{\"session_id\":{\"S\":\"'$SESSION_ID'\"}}' --region us-east-1"

# Create prayer request
REQUEST_ID="prayer-request-$(date +%s)"
awslocal dynamodb put-item \
    --table-name FaithChatbot-PrayerRequests \
    --item '{
        "request_id": {"S": "'$REQUEST_ID'"},
        "user_id": {"S": "test-user-123"},
        "prayer_text": {"S": "Please pray for healing"},
        "status": {"S": "pending"},
        "created_at": {"S": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"},
        "consent_given": {"BOOL": true}
    }' \
    --region us-east-1

run_test "Can create prayer request" \
    "awslocal dynamodb get-item --table-name FaithChatbot-PrayerRequests --key '{\"request_id\":{\"S\":\"'$REQUEST_ID'\"}}' --region us-east-1"

# Log consent
CONSENT_ID="consent-$(date +%s)"
awslocal dynamodb put-item \
    --table-name FaithChatbot-ConsentLogs \
    --item '{
        "log_id": {"S": "'$CONSENT_ID'"},
        "user_id": {"S": "test-user-123"},
        "consent_type": {"S": "prayer_connect"},
        "consent_given": {"BOOL": true},
        "timestamp": {"S": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"},
        "ip_address": {"S": "127.0.0.1"},
        "user_agent": {"S": "LocalStack Test"}
    }' \
    --region us-east-1

run_test "Can log consent" \
    "awslocal dynamodb get-item --table-name FaithChatbot-ConsentLogs --key '{\"log_id\":{\"S\":\"'$CONSENT_ID'\"}}' --region us-east-1"

# Test Results Summary
echo ""
echo -e "${BLUE}=== Test Results Summary ===${NC}"
echo -e "${GREEN}Tests Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Tests Failed: $TESTS_FAILED${NC}"
echo -e "Total Tests: $((TESTS_PASSED + TESTS_FAILED))"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}🎉 All tests passed! Infrastructure is working correctly.${NC}"
    exit 0
else
    echo -e "${RED}❌ Some tests failed. Please check the LocalStack setup.${NC}"
    exit 1
fi