#!/bin/bash

# Faith Motivator Chatbot - Development Environment Setup Script

set -e  # Exit on any error

echo "🚀 Setting up Faith Motivator Chatbot development environment..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Docker is installed and running
check_docker() {
    print_status "Checking Docker installation..."
    
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        print_error "Docker is not running. Please start Docker first."
        exit 1
    fi
    
    print_success "Docker is installed and running"
}

# Check if Docker Compose is available
check_docker_compose() {
    print_status "Checking Docker Compose..."
    
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        print_error "Docker Compose is not available. Please install Docker Compose."
        exit 1
    fi
    
    print_success "Docker Compose is available"
}

# Create .env file from example if it doesn't exist
setup_env_file() {
    print_status "Setting up environment file..."
    
    if [ ! -f .env ]; then
        if [ -f .env.example ]; then
            cp .env.example .env
            print_success "Created .env file from .env.example"
            print_warning "Please review and update the .env file with your specific configuration"
        else
            print_error ".env.example file not found"
            exit 1
        fi
    else
        print_success ".env file already exists"
    fi
}

# Make scripts executable
make_scripts_executable() {
    print_status "Making scripts executable..."
    
    chmod +x scripts/*.sh
    chmod +x scripts/*.py
    chmod +x localstack/*.sh
    
    print_success "Scripts are now executable"
}

# Clean up any existing containers
cleanup_containers() {
    print_status "Cleaning up existing containers..."
    
    if docker-compose ps -q &> /dev/null; then
        docker-compose down -v
    elif docker compose ps -q &> /dev/null; then
        docker compose down -v
    fi
    
    print_success "Cleaned up existing containers"
}

# Start the development environment
start_environment() {
    print_status "Starting development environment..."
    
    # Use docker-compose if available, otherwise use docker compose
    if command -v docker-compose &> /dev/null; then
        docker-compose up -d
    else
        docker compose up -d
    fi
    
    print_success "Development environment started"
}

# Wait for services to be ready
wait_for_services() {
    print_status "Waiting for services to be ready..."
    
    # Wait for LocalStack
    print_status "Waiting for LocalStack..."
    timeout=60
    while [ $timeout -gt 0 ]; do
        if curl -s http://localhost:4566/_localstack/health &> /dev/null; then
            break
        fi
        sleep 2
        timeout=$((timeout - 2))
    done
    
    if [ $timeout -le 0 ]; then
        print_error "LocalStack failed to start within 60 seconds"
        exit 1
    fi
    
    print_success "LocalStack is ready"
    
    # Wait for Redis
    print_status "Waiting for Redis..."
    timeout=30
    while [ $timeout -gt 0 ]; do
        if redis-cli -h localhost -p 6379 ping &> /dev/null; then
            break
        fi
        sleep 2
        timeout=$((timeout - 2))
    done
    
    if [ $timeout -le 0 ]; then
        print_warning "Redis may not be ready, but continuing..."
    else
        print_success "Redis is ready"
    fi
}

# Initialize LocalStack services
initialize_localstack() {
    print_status "Initializing LocalStack services..."
    
    # The initialization scripts should run automatically via LocalStack init hooks
    # But we can also run them manually to ensure they complete
    
    sleep 5  # Give LocalStack a moment to fully initialize
    
    print_success "LocalStack services initialized"
}

# Seed the database
seed_database() {
    print_status "Seeding database with test data..."
    
    # Install Python dependencies if needed
    if [ ! -d "venv" ]; then
        python3 -m venv venv
        source venv/bin/activate
        pip install -r requirements.txt
    else
        source venv/bin/activate
    fi
    
    # Run the seeding script
    python scripts/seed_database.py
    
    print_success "Database seeded with test data"
}

# Validate environment
validate_environment() {
    print_status "Validating environment configuration..."
    
    if [ -d "venv" ]; then
        source venv/bin/activate
    fi
    
    python scripts/validate_env.py
    
    if [ $? -eq 0 ]; then
        print_success "Environment validation passed"
    else
        print_error "Environment validation failed"
        exit 1
    fi
}

# Display service URLs
display_urls() {
    print_success "Development environment is ready!"
    echo ""
    echo "🌐 Service URLs:"
    echo "  Frontend (Reflex):     http://localhost:3000"
    echo "  Backend API:           http://localhost:8000"
    echo "  LocalStack:            http://localhost:4566"
    echo "  Redis:                 redis://localhost:6379"
    echo "  PostgreSQL:            postgresql://dev:devpass@localhost:5432/faithchatbot_dev"
    echo ""
    echo "📚 Useful Commands:"
    echo "  View logs:             docker-compose logs -f"
    echo "  Stop environment:      docker-compose down"
    echo "  Restart services:      docker-compose restart"
    echo "  Clean everything:      docker-compose down -v"
    echo ""
    echo "🔧 Development Tools:"
    echo "  Validate config:       python scripts/validate_env.py"
    echo "  Seed database:         python scripts/seed_database.py"
    echo "  Run tests:             pytest"
    echo ""
}

# Main execution
main() {
    echo "Faith Motivator Chatbot - Development Setup"
    echo "==========================================="
    
    check_docker
    check_docker_compose
    setup_env_file
    make_scripts_executable
    cleanup_containers
    start_environment
    wait_for_services
    initialize_localstack
    
    # Optional steps
    if [ "$1" != "--no-seed" ]; then
        seed_database
    fi
    
    if [ "$1" != "--no-validate" ]; then
        validate_environment
    fi
    
    display_urls
}

# Handle script arguments
case "$1" in
    --help|-h)
        echo "Usage: $0 [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  --no-seed      Skip database seeding"
        echo "  --no-validate  Skip environment validation"
        echo "  --help, -h     Show this help message"
        echo ""
        exit 0
        ;;
    *)
        main "$1"
        ;;
esac