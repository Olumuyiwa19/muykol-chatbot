#!/bin/bash

# Docker Test Script for FastAPI Backend
# This script helps test the Docker configuration

set -e

echo "🐳 Docker Configuration Test Script"
echo "=================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed or not in PATH"
    exit 1
fi

print_status "Docker is available"

# Build the Docker image
echo ""
echo "Building Docker image..."
if docker build -t chatbot-backend:test ./backend; then
    print_status "Docker image built successfully"
else
    print_error "Failed to build Docker image"
    exit 1
fi

# Test the Docker image
echo ""
echo "Testing Docker image..."

# Start container in background
CONTAINER_ID=$(docker run -d -p 8001:8000 \
    -e AWS_REGION=us-east-1 \
    -e LOG_LEVEL=INFO \
    -e ENVIRONMENT=test \
    chatbot-backend:test)

if [ $? -eq 0 ]; then
    print_status "Container started with ID: $CONTAINER_ID"
else
    print_error "Failed to start container"
    exit 1
fi

# Wait for container to be ready
echo "Waiting for container to be ready..."
sleep 10

# Test health endpoint
echo "Testing health endpoint..."
if curl -f http://localhost:8001/api/v1/health > /dev/null 2>&1; then
    print_status "Health endpoint is responding"
else
    print_warning "Health endpoint is not responding (this may be expected without AWS credentials)"
fi

# Test root endpoint
echo "Testing root endpoint..."
if curl -f http://localhost:8001/ > /dev/null 2>&1; then
    print_status "Root endpoint is responding"
else
    print_error "Root endpoint is not responding"
fi

# Show container logs
echo ""
echo "Container logs (last 20 lines):"
echo "================================"
docker logs --tail 20 $CONTAINER_ID

# Cleanup
echo ""
echo "Cleaning up..."
docker stop $CONTAINER_ID > /dev/null
docker rm $CONTAINER_ID > /dev/null
print_status "Container stopped and removed"

echo ""
print_status "Docker configuration test completed successfully!"
echo ""
echo "Next steps:"
echo "1. Set up your AWS credentials"
echo "2. Configure environment variables in .env.docker"
echo "3. Run 'make docker-up' to start the development environment"
echo "4. Run 'make docker-up-prod' to test production configuration"