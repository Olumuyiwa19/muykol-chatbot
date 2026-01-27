#!/bin/bash
# CDK utility script for common operations

set -e

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

# Function to show usage
show_usage() {
    echo "Usage: $0 <command> [environment]"
    echo ""
    echo "Commands:"
    echo "  bootstrap [env]    Bootstrap CDK for the specified environment (or all)"
    echo "  diff [env]         Show differences for the specified environment"
    echo "  synth [env]        Synthesize CloudFormation templates"
    echo "  deploy [env]       Deploy the specified environment"
    echo "  destroy [env]      Destroy the specified environment"
    echo "  list               List all stacks"
    echo "  outputs [env]      Show stack outputs for environment"
    echo "  validate           Validate all CDK code"
    echo ""
    echo "Environments: dev, staging, prod (if not specified, applies to all)"
    echo ""
    echo "Examples:"
    echo "  $0 bootstrap dev     # Bootstrap CDK for dev environment"
    echo "  $0 deploy staging    # Deploy staging environment"
    echo "  $0 diff prod         # Show differences for prod environment"
    echo "  $0 outputs dev       # Show dev environment outputs"
}

# Function to setup environment
setup_environment() {
    cd "$(dirname "$0")/.."
    
    if [ ! -d "venv" ]; then
        print_status "Creating virtual environment..."
        python3 -m venv venv
    fi
    
    print_status "Activating virtual environment..."
    source venv/bin/activate
    
    print_status "Installing dependencies..."
    pip install -r requirements.txt > /dev/null 2>&1
}

# Function to check AWS credentials
check_aws_credentials() {
    if ! aws sts get-caller-identity > /dev/null 2>&1; then
        print_error "AWS credentials not configured. Please run 'aws configure' first."
        exit 1
    fi
    
    local account=$(aws sts get-caller-identity --query Account --output text)
    local region=$(aws configure get region)
    print_status "Using AWS Account: $account, Region: $region"
}

# Function to bootstrap CDK
bootstrap_cdk() {
    local env=$1
    
    if [ -z "$env" ]; then
        print_status "Bootstrapping CDK for all environments..."
        cdk bootstrap
    else
        print_status "Bootstrapping CDK for $env environment..."
        cdk bootstrap --context environment=$env
    fi
}

# Function to show diff
show_diff() {
    local env=$1
    
    if [ -z "$env" ]; then
        print_error "Environment must be specified for diff command"
        exit 1
    fi
    
    print_status "Showing differences for $env environment..."
    cdk diff chatbot-$env --context environment=$env
}

# Function to synthesize templates
synthesize() {
    local env=$1
    
    if [ -z "$env" ]; then
        print_status "Synthesizing all environments..."
        cdk synth
    else
        print_status "Synthesizing $env environment..."
        cdk synth chatbot-$env --context environment=$env
    fi
}

# Function to deploy
deploy() {
    local env=$1
    
    if [ -z "$env" ]; then
        print_error "Environment must be specified for deploy command"
        exit 1
    fi
    
    if [ "$env" = "prod" ]; then
        print_warning "You are about to deploy to PRODUCTION environment."
        read -p "Are you sure you want to continue? (yes/no): " confirm
        if [ "$confirm" != "yes" ]; then
            print_error "Production deployment cancelled."
            exit 1
        fi
    fi
    
    print_status "Deploying $env environment..."
    cdk deploy chatbot-$env \
        --context environment=$env \
        --require-approval never \
        --progress events
    
    print_success "$env environment deployed successfully!"
}

# Function to destroy
destroy() {
    local env=$1
    
    if [ -z "$env" ]; then
        print_error "Environment must be specified for destroy command"
        exit 1
    fi
    
    print_warning "You are about to DESTROY the $env environment."
    print_warning "This action cannot be undone!"
    read -p "Type 'DELETE' to confirm: " confirm
    if [ "$confirm" != "DELETE" ]; then
        print_error "Destroy operation cancelled."
        exit 1
    fi
    
    print_status "Destroying $env environment..."
    cdk destroy chatbot-$env --context environment=$env --force
    
    print_success "$env environment destroyed!"
}

# Function to list stacks
list_stacks() {
    print_status "Listing all CDK stacks..."
    cdk list
}

# Function to show outputs
show_outputs() {
    local env=$1
    
    if [ -z "$env" ]; then
        print_error "Environment must be specified for outputs command"
        exit 1
    fi
    
    print_status "Showing outputs for $env environment..."
    aws cloudformation describe-stacks \
        --stack-name chatbot-$env \
        --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue]' \
        --output table 2>/dev/null || print_warning "Stack chatbot-$env not found or not deployed"
}

# Function to validate CDK code
validate() {
    print_status "Validating CDK code..."
    
    # Check Python syntax
    python -m py_compile infrastructure/app.py
    python -m py_compile infrastructure/config.py
    python -m py_compile infrastructure/stacks/chatbot_stack.py
    
    # Run CDK synth to validate templates
    cdk synth > /dev/null
    
    print_success "CDK code validation passed!"
}

# Main script logic
main() {
    local command=$1
    local environment=$2
    
    if [ -z "$command" ]; then
        show_usage
        exit 1
    fi
    
    # Validate environment if provided
    if [ -n "$environment" ] && [[ ! "$environment" =~ ^(dev|staging|prod)$ ]]; then
        print_error "Invalid environment: $environment. Must be dev, staging, or prod."
        exit 1
    fi
    
    setup_environment
    check_aws_credentials
    
    case $command in
        bootstrap)
            bootstrap_cdk $environment
            ;;
        diff)
            show_diff $environment
            ;;
        synth)
            synthesize $environment
            ;;
        deploy)
            deploy $environment
            ;;
        destroy)
            destroy $environment
            ;;
        list)
            list_stacks
            ;;
        outputs)
            show_outputs $environment
            ;;
        validate)
            validate
            ;;
        *)
            print_error "Unknown command: $command"
            show_usage
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"