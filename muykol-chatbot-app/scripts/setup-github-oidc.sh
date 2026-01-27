#!/bin/bash

# GitHub OIDC Provider Setup Script
# This script helps set up the GitHub OIDC provider and IAM roles for CI/CD

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}$1${NC}"
}

# Check if AWS CLI is installed
check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed. Please install it first."
        exit 1
    fi
    
    # Check if AWS credentials are configured
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials are not configured. Please run 'aws configure' first."
        exit 1
    fi
    
    print_status "AWS CLI is configured and working"
}

# Get repository information
get_repo_info() {
    if [[ -z "${GITHUB_REPOSITORY:-}" ]]; then
        if git remote -v | grep -q github.com; then
            GITHUB_REPOSITORY=$(git remote get-url origin | sed 's/.*github.com[:/]\([^/]*\/[^/]*\)\.git.*/\1/')
        else
            GITHUB_REPOSITORY="Olumuyiwa19/muykol-chatbot"
        fi
    fi
    
    print_status "GitHub Repository: $GITHUB_REPOSITORY"
}

# Deploy CloudFormation stack
deploy_oidc_stack() {
    local stack_name="github-oidc-chatbot"
    local template_file="github-oidc-provider.yaml"
    
    print_header "Deploying GitHub OIDC Provider CloudFormation Stack"
    
    # Check if template exists
    if [[ ! -f "$template_file" ]]; then
        print_error "CloudFormation template not found: $template_file"
        print_status "Please run the setup-oidc.yml GitHub Action first to generate the template"
        exit 1
    fi
    
    # Deploy stack
    print_status "Deploying stack: $stack_name"
    aws cloudformation deploy \
        --template-file "$template_file" \
        --stack-name "$stack_name" \
        --capabilities CAPABILITY_NAMED_IAM \
        --parameter-overrides GitHubRepository="$GITHUB_REPOSITORY" \
        --no-fail-on-empty-changeset
    
    print_status "Stack deployment completed"
}

# Get role ARN from stack outputs
get_role_arn() {
    local stack_name="github-oidc-chatbot"
    
    print_status "Getting IAM Role ARN from CloudFormation stack..."
    
    ROLE_ARN=$(aws cloudformation describe-stacks \
        --stack-name "$stack_name" \
        --query 'Stacks[0].Outputs[?OutputKey==`GitHubActionsRoleArn`].OutputValue' \
        --output text)
    
    if [[ -z "$ROLE_ARN" ]]; then
        print_error "Could not retrieve Role ARN from stack outputs"
        exit 1
    fi
    
    print_status "Role ARN: $ROLE_ARN"
}

# Main execution
main() {
    print_header "🚀 GitHub OIDC Provider Setup for Chatbot CI/CD"
    echo
    
    check_aws_cli
    get_repo_info
    
    # Check if template exists, if not provide instructions
    if [[ ! -f "github-oidc-provider.yaml" ]]; then
        print_warning "CloudFormation template not found"
        print_status "Please run the GitHub Action 'Setup GitHub OIDC Provider' first"
        print_status "Or download the template from the action artifacts"
        exit 1
    fi
    
    deploy_oidc_stack
    get_role_arn
    
    print_header "✅ Setup Complete!"
    echo
    print_status "Next steps:"
    echo "1. Add the following secret to your GitHub repository:"
    echo "   Secret Name: AWS_ROLE_ARN"
    echo "   Secret Value: $ROLE_ARN"
    echo
    echo "2. You can add this secret via:"
    echo "   - GitHub web interface: Settings > Secrets and variables > Actions"
    echo "   - GitHub CLI: gh secret set AWS_ROLE_ARN --body '$ROLE_ARN'"
    echo
    print_status "Your CI/CD pipeline is now ready to use!"
}

# Run main function
main "$@"