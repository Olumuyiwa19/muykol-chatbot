#!/bin/bash

# Terraform Cloud Workspace Setup Script for muykol-chatbot
# This script creates and configures Terraform Cloud workspaces using the API

set -e

# Configuration
ORG_NAME="Kolayemi-org"
PROJECT_NAME="muykol-chatbot"
ENVIRONMENTS=("dev" "staging" "prod")

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Setting up Terraform Cloud workspaces for muykol-chatbot${NC}"

# Check if TF_API_TOKEN is set
if [ -z "$TF_API_TOKEN" ]; then
    echo -e "${RED}TF_API_TOKEN environment variable is not set.${NC}"
    echo -e "${YELLOW}Please set it with your Terraform Cloud API token:${NC}"
    echo "export TF_API_TOKEN=your-token-here"
    echo ""
    echo "Get your token from: https://app.terraform.io/app/settings/tokens"
    exit 1
fi

# Function to create workspace
create_workspace() {
    local env=$1
    local workspace_name="${PROJECT_NAME}-${env}"
    
    echo -e "${YELLOW}Creating workspace: ${workspace_name}${NC}"
    
    # Create workspace using Terraform Cloud API
    response=$(curl -s -w "%{http_code}" \
        --header "Authorization: Bearer $TF_API_TOKEN" \
        --header "Content-Type: application/vnd.api+json" \
        --request POST \
        --data @- \
        https://app.terraform.io/api/v2/organizations/${ORG_NAME}/workspaces << EOF
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
)

    # Extract HTTP status code (last 3 characters)
    http_code="${response: -3}"
    response_body="${response%???}"

    if [ "$http_code" -eq 201 ]; then
        echo -e "${GREEN}✓ Workspace ${workspace_name} created successfully${NC}"
    elif [ "$http_code" -eq 422 ]; then
        echo -e "${YELLOW}⚠ Workspace ${workspace_name} already exists${NC}"
    else
        echo -e "${RED}✗ Failed to create workspace ${workspace_name} (HTTP: ${http_code})${NC}"
        echo "Response: $response_body"
    fi
}

# Function to set workspace variables
set_workspace_variables() {
    local env=$1
    local workspace_name="${PROJECT_NAME}-${env}"
    
    echo -e "${YELLOW}Setting up variables for ${workspace_name}${NC}"
    
    # Get workspace ID
    workspace_response=$(curl -s \
        --header "Authorization: Bearer $TF_API_TOKEN" \
        --header "Content-Type: application/vnd.api+json" \
        https://app.terraform.io/api/v2/organizations/${ORG_NAME}/workspaces/${workspace_name})
    
    workspace_id=$(echo "$workspace_response" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
    
    if [ -z "$workspace_id" ]; then
        echo -e "${RED}✗ Could not get workspace ID for ${workspace_name}${NC}"
        return 1
    fi
    
    # Set environment variable
    curl -s \
        --header "Authorization: Bearer $TF_API_TOKEN" \
        --header "Content-Type: application/vnd.api+json" \
        --request POST \
        --data @- \
        https://app.terraform.io/api/v2/workspaces/${workspace_id}/vars << EOF > /dev/null
{
  "data": {
    "type": "vars",
    "attributes": {
      "key": "environment",
      "value": "${env}",
      "category": "terraform",
      "hcl": false,
      "sensitive": false
    }
  }
}
EOF
    
    echo -e "${GREEN}✓ Variables configured for ${workspace_name}${NC}"
}

# Check if organization exists
echo -e "${YELLOW}Checking organization: ${ORG_NAME}${NC}"
org_response=$(curl -s -w "%{http_code}" \
    --header "Authorization: Bearer $TF_API_TOKEN" \
    --header "Content-Type: application/vnd.api+json" \
    https://app.terraform.io/api/v2/organizations/${ORG_NAME})

org_http_code="${org_response: -3}"
if [ "$org_http_code" -ne 200 ]; then
    echo -e "${RED}✗ Organization '${ORG_NAME}' not found or not accessible${NC}"
    echo -e "${YELLOW}Please create the organization first at: https://app.terraform.io${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Organization found${NC}"

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
echo "2. Configure AWS credentials for each workspace:"
echo "   - AWS_ACCESS_KEY_ID (sensitive)"
echo "   - AWS_SECRET_ACCESS_KEY (sensitive)"
echo "   - AWS_DEFAULT_REGION = us-east-1"
echo "3. Set up VCS integration with your GitHub repository"
echo "4. Run terraform plan/apply from Terraform Cloud UI"

echo -e "${GREEN}Setup script completed successfully!${NC}"
