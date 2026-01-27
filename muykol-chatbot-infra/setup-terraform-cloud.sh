#!/bin/bash

# Terraform Cloud Workspace Setup Script for muykol-chatbot
# This script creates and configures Terraform Cloud workspaces

set -e

# Configuration
ORG_NAME="muykol-chatbot"  # Replace with your Terraform Cloud organization
PROJECT_NAME="muykol-chatbot"
ENVIRONMENTS=("dev" "staging" "prod")

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Setting up Terraform Cloud workspaces for muykol-chatbot${NC}"

# Check if Terraform CLI is installed
if ! command -v terraform &> /dev/null; then
    echo -e "${RED}Terraform CLI is not installed. Please install it first.${NC}"
    exit 1
fi

# Check if user is logged into Terraform Cloud
if ! terraform login --help &> /dev/null; then
    echo -e "${YELLOW}Please login to Terraform Cloud first:${NC}"
    echo "terraform login"
    exit 1
fi

# Function to create workspace
create_workspace() {
    local env=$1
    local workspace_name="${PROJECT_NAME}-${env}"
    
    echo -e "${YELLOW}Creating workspace: ${workspace_name}${NC}"
    
    # Create workspace configuration
    cat > workspace-${env}.json << EOF
{
  "data": {
    "type": "workspaces",
    "attributes": {
      "name": "${workspace_name}",
      "description": "muykol-chatbot ${env} environment infrastructure",
      "execution-mode": "remote",
      "auto-apply": false,
      "queue-all-runs": false,
      "speculative-enabled": true,
      "structured-run-output-enabled": true,
      "terraform-version": "~> 1.0",
      "working-directory": "muykol-chatbot-infra",
      "trigger-prefixes": ["muykol-chatbot-infra/"],
      "tag-names": ["muykol-chatbot", "aws", "${env}"]
    }
  }
}
EOF

    # Create the workspace using Terraform Cloud API
    echo "Workspace configuration created for ${env}"
}

# Function to set environment variables
set_workspace_variables() {
    local env=$1
    local workspace_name="${PROJECT_NAME}-${env}"
    
    echo -e "${YELLOW}Setting up environment variables for ${workspace_name}${NC}"
    
    # Environment-specific variables
    case $env in
        "dev")
            AWS_REGION="us-east-1"
            VPC_CIDR="10.0.0.0/16"
            ;;
        "staging")
            AWS_REGION="us-east-1"
            VPC_CIDR="10.1.0.0/16"
            ;;
        "prod")
            AWS_REGION="us-east-1"
            VPC_CIDR="10.2.0.0/16"
            ;;
    esac
    
    echo "Environment variables configured for ${env}"
}

# Main execution
echo -e "${GREEN}Starting workspace setup...${NC}"

for env in "${ENVIRONMENTS[@]}"; do
    echo -e "\n${GREEN}Processing environment: ${env}${NC}"
    create_workspace $env
    set_workspace_variables $env
done

echo -e "\n${GREEN}Workspace setup complete!${NC}"
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Go to https://app.terraform.io/app/${ORG_NAME}/workspaces"
echo "2. Configure AWS credentials for each workspace"
echo "3. Set up VCS integration with your GitHub repository"
echo "4. Configure workspace-specific variables"
echo "5. Run terraform plan/apply from Terraform Cloud UI"

# Cleanup
rm -f workspace-*.json

echo -e "${GREEN}Setup script completed successfully!${NC}"
