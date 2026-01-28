#!/bin/bash

# Setup LocalStack Testing for Phase 1 Infrastructure
# This script sets up and tests the complete Phase 1 infrastructure locally

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOCALSTACK_DIR="$PROJECT_ROOT/localstack"

echo -e "${BLUE}🚀 Faith Motivator Chatbot - Phase 1 Infrastructure Testing${NC}"
echo -e "${BLUE}================================================================${NC}"
echo ""

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to wait for service
wait_for_service() {
    local service_name="$1"
    local check_command="$2"
    local timeout="${3:-60}"
    
    echo -e "${YELLOW}⏳ Waiting for $service_name to be ready...${NC}"
    
    local count=0
    while [ $count -lt $timeout ]; do
        if eval "$check_command" >/dev/null 2>&1; then
            echo -e "${GREEN}✅ $service_name is ready!${NC}"
            return 0
        fi
        sleep 2
        ((count += 2))
    done
    
    echo -e "${RED}❌ $service_name failed to start within ${timeout}s${NC}"
    return 1
}

# Check prerequisites
echo -e "${PURPLE}📋 Checking Prerequisites...${NC}"

if ! command_exists docker; then
    echo -e "${RED}❌ Docker is not installed. Please install Docker first.${NC}"
    exit 1
fi

if ! command_exists docker-compose; then
    echo -e "${RED}❌ Docker Compose is not installed. Please install Docker Compose first.${NC}"
    exit 1
fi

if ! command_exists python3; then
    echo -e "${RED}❌ Python 3 is not installed. Please install Python 3 first.${NC}"
    exit 1
fi

# Check if awslocal is available
if ! command_exists awslocal; then
    echo -e "${YELLOW}⚠️  awslocal not found. Installing localstack CLI...${NC}"
    pip3 install localstack awscli-local
fi

echo -e "${GREEN}✅ All prerequisites are available${NC}"
echo ""

# Start LocalStack
echo -e "${PURPLE}🐳 Starting LocalStack Services...${NC}"

cd "$PROJECT_ROOT"

# Stop any existing containers
docker-compose down -v 2>/dev/null || true

# Start LocalStack and dependencies
echo "Starting services with docker-compose..."
docker-compose up -d localstack redis

# Wait for LocalStack to be ready
wait_for_service "LocalStack" "curl -s http://localhost:4566/_localstack/health"

# Wait for Redis to be ready
wait_for_service "Redis" "docker-compose exec -T redis redis-cli ping"

echo ""

# Initialize LocalStack services
echo -e "${PURPLE}⚙️  Initializing AWS Services...${NC}"

# Make scripts executable
chmod +x "$LOCALSTACK_DIR"/*.sh

# Run initialization scripts in order
scripts=(
    "01-create-dynamodb-tables.sh"
    "02-create-sqs-queues.sh"
    "03-setup-ses.sh"
    "04-setup-secrets.sh"
    "05-setup-cognito.sh"
)

for script in "${scripts[@]}"; do
    script_path="$LOCALSTACK_DIR/$script"
    if [ -f "$script_path" ]; then
        echo -e "${BLUE}Running $script...${NC}"
        bash "$script_path"
        echo ""
    else
        echo -e "${YELLOW}⚠️  Script $script not found, skipping...${NC}"
    fi
done

echo -e "${GREEN}✅ AWS services initialized successfully!${NC}"
echo ""

# Install Python dependencies for testing
echo -e "${PURPLE}📦 Installing Python Dependencies...${NC}"

# Create virtual environment if it doesn't exist
if [ ! -d "$PROJECT_ROOT/venv" ]; then
    echo "Creating Python virtual environment..."
    python3 -m venv "$PROJECT_ROOT/venv"
fi

# Activate virtual environment
source "$PROJECT_ROOT/venv/bin/activate"

# Install required packages
pip install boto3 requests

echo -e "${GREEN}✅ Python dependencies installed${NC}"
echo ""

# Run infrastructure tests
echo -e "${PURPLE}🧪 Running Infrastructure Tests...${NC}"

python3 "$SCRIPT_DIR/test-phase1-infrastructure.py"
test_exit_code=$?

echo ""

# Run shell-based tests
echo -e "${PURPLE}🔍 Running Additional Verification Tests...${NC}"

if [ -f "$LOCALSTACK_DIR/06-test-infrastructure.sh" ]; then
    bash "$LOCALSTACK_DIR/06-test-infrastructure.sh"
    shell_test_exit_code=$?
else
    echo -e "${YELLOW}⚠️  Shell test script not found, skipping...${NC}"
    shell_test_exit_code=0
fi

echo ""

# Display service information
echo -e "${PURPLE}📊 Service Information${NC}"
echo -e "${BLUE}================================================================${NC}"

echo -e "${YELLOW}LocalStack Services:${NC}"
echo "  • LocalStack Dashboard: http://localhost:4566"
echo "  • Health Check: http://localhost:4566/_localstack/health"
echo ""

echo -e "${YELLOW}Available Services:${NC}"
echo "  • DynamoDB: http://localhost:4566"
echo "  • SQS: http://localhost:4566"
echo "  • SES: http://localhost:4566"
echo "  • Cognito: http://localhost:4566"
echo "  • Secrets Manager: http://localhost:4566"
echo ""

echo -e "${YELLOW}Redis:${NC}"
echo "  • Redis: localhost:6379"
echo ""

# Display test users
echo -e "${YELLOW}Test Users (if Cognito setup succeeded):${NC}"
echo "  • Email: testuser@faithchatbot.local"
echo "  • Password: TestPass123!"
echo ""
echo "  • Email: john.doe@faithchatbot.local"
echo "  • Password: TestPass123!"
echo ""

# Display useful commands
echo -e "${YELLOW}Useful Commands:${NC}"
echo "  • List DynamoDB tables: awslocal dynamodb list-tables --region us-east-1"
echo "  • List SQS queues: awslocal sqs list-queues --region us-east-1"
echo "  • List Cognito user pools: awslocal cognito-idp list-user-pools --max-items 10 --region us-east-1"
echo "  • Check LocalStack logs: docker-compose logs localstack"
echo ""

# Environment variables for development
echo -e "${YELLOW}Environment Variables for Development:${NC}"
cat << EOF
export AWS_ENDPOINT_URL=http://localhost:4566
export AWS_REGION=us-east-1
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export REDIS_URL=redis://localhost:6379
EOF

# Load Cognito configuration if available
if [ -f "/tmp/cognito-config.env" ]; then
    echo ""
    echo -e "${YELLOW}Cognito Configuration:${NC}"
    cat /tmp/cognito-config.env
fi

echo ""

# Final status
if [ $test_exit_code -eq 0 ] && [ $shell_test_exit_code -eq 0 ]; then
    echo -e "${GREEN}🎉 SUCCESS: All tests passed! Phase 1 infrastructure is working correctly.${NC}"
    echo -e "${GREEN}✅ LocalStack environment is ready for development and testing.${NC}"
    echo ""
    echo -e "${BLUE}Next Steps:${NC}"
    echo "1. Start developing the FastAPI backend (Phase 1 Task 2.1)"
    echo "2. Implement emotion classification system (Phase 1 Task 3.1)"
    echo "3. Test with the running LocalStack environment"
    echo ""
    echo -e "${YELLOW}To stop the environment:${NC} docker-compose down"
    echo -e "${YELLOW}To restart:${NC} bash $0"
    
    exit 0
else
    echo -e "${RED}❌ FAILURE: Some tests failed. Please check the output above.${NC}"
    echo ""
    echo -e "${YELLOW}Troubleshooting:${NC}"
    echo "1. Check LocalStack logs: docker-compose logs localstack"
    echo "2. Verify all services are running: docker-compose ps"
    echo "3. Check LocalStack health: curl http://localhost:4566/_localstack/health"
    echo "4. Restart LocalStack: docker-compose restart localstack"
    
    exit 1
fi