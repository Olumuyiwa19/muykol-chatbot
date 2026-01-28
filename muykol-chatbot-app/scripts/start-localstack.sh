#!/bin/bash

# Simplified LocalStack Startup Script
# Focuses on getting LocalStack running reliably

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Starting LocalStack for Faith Motivator Chatbot${NC}"
echo -e "${BLUE}=================================================${NC}"

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
echo -e "${YELLOW}📋 Checking Prerequisites...${NC}"

if ! command_exists docker; then
    echo -e "${RED}❌ Docker is not installed. Please install Docker first.${NC}"
    exit 1
fi

if ! command_exists docker-compose; then
    echo -e "${RED}❌ Docker Compose is not installed. Please install Docker Compose first.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Prerequisites OK${NC}"

# Clean up any existing containers
echo -e "${YELLOW}🧹 Cleaning up existing containers...${NC}"
docker-compose -f docker-compose.localstack.yml down -v 2>/dev/null || true

# Remove any stuck LocalStack containers
docker ps -a | grep localstack | awk '{print $1}' | xargs -r docker rm -f 2>/dev/null || true

# Clean up Docker system if needed
echo -e "${YELLOW}🧹 Cleaning Docker system...${NC}"
docker system prune -f >/dev/null 2>&1 || true

# Start LocalStack with simplified configuration
echo -e "${YELLOW}🐳 Starting LocalStack...${NC}"
docker-compose -f docker-compose.localstack.yml up -d

# Wait for LocalStack to be ready with better error handling
echo -e "${YELLOW}⏳ Waiting for LocalStack to be ready...${NC}"

MAX_ATTEMPTS=30
ATTEMPT=0

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    if curl -s http://localhost:4566/_localstack/health >/dev/null 2>&1; then
        echo -e "${GREEN}✅ LocalStack is ready!${NC}"
        break
    fi
    
    ATTEMPT=$((ATTEMPT + 1))
    echo -e "${YELLOW}   Attempt $ATTEMPT/$MAX_ATTEMPTS - waiting...${NC}"
    
    # Check if container is still running
    if ! docker-compose -f docker-compose.localstack.yml ps localstack | grep -q "Up"; then
        echo -e "${RED}❌ LocalStack container stopped unexpectedly${NC}"
        echo -e "${YELLOW}📋 Container logs:${NC}"
        docker-compose -f docker-compose.localstack.yml logs localstack --tail=20
        exit 1
    fi
    
    sleep 5
done

if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
    echo -e "${RED}❌ LocalStack failed to start within timeout${NC}"
    echo -e "${YELLOW}📋 Container status:${NC}"
    docker-compose -f docker-compose.localstack.yml ps
    echo -e "${YELLOW}📋 Container logs:${NC}"
    docker-compose -f docker-compose.localstack.yml logs localstack --tail=30
    exit 1
fi

# Check service health
echo -e "${YELLOW}🔍 Checking service health...${NC}"
HEALTH_RESPONSE=$(curl -s http://localhost:4566/_localstack/health)
echo -e "${BLUE}Health Status:${NC}"
echo "$HEALTH_RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$HEALTH_RESPONSE"

# Check which services are available
AVAILABLE_SERVICES=$(echo "$HEALTH_RESPONSE" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    services = data.get('services', {})
    available = [k for k, v in services.items() if v == 'available']
    print('Available services:', ', '.join(available))
except:
    print('Could not parse health response')
" 2>/dev/null)

echo -e "${GREEN}$AVAILABLE_SERVICES${NC}"

# Display connection information
echo ""
echo -e "${GREEN}🎉 LocalStack is running successfully!${NC}"
echo -e "${BLUE}=================================================${NC}"
echo -e "${YELLOW}Connection Information:${NC}"
echo "  • LocalStack Endpoint: http://localhost:4566"
echo "  • Health Check: http://localhost:4566/_localstack/health"
echo "  • Redis: localhost:6379"
echo ""
echo -e "${YELLOW}Environment Variables:${NC}"
echo "  export AWS_ENDPOINT_URL=http://localhost:4566"
echo "  export AWS_REGION=us-east-1"
echo "  export AWS_ACCESS_KEY_ID=test"
echo "  export AWS_SECRET_ACCESS_KEY=test"
echo ""
echo -e "${YELLOW}Useful Commands:${NC}"
echo "  • Check status: curl http://localhost:4566/_localstack/health"
echo "  • View logs: docker-compose -f docker-compose.localstack.yml logs localstack"
echo "  • Stop services: docker-compose -f docker-compose.localstack.yml down"
echo ""
echo -e "${BLUE}Next Steps:${NC}"
echo "1. Install awslocal: pip install awscli-local"
echo "2. Initialize services: ./scripts/init-localstack-services.sh"
echo "3. Run tests: ./scripts/test-localstack-simple.sh"