#!/bin/bash

# Script to create GitHub token secret for Amplify deployment
# Usage: ./setup-github-token.sh <environment> <github-token>

set -e

ENVIRONMENT=${1:-dev}
GITHUB_TOKEN=${2}

if [ -z "$GITHUB_TOKEN" ]; then
    echo "Usage: $0 <environment> <github-token>"
    echo "Example: $0 dev ghp_xxxxxxxxxxxxxxxxxxxx"
    echo ""
    echo "To create a GitHub Personal Access Token:"
    echo "1. Go to GitHub Settings > Developer settings > Personal access tokens"
    echo "2. Click 'Generate new token (classic)'"
    echo "3. Select scopes: repo, admin:repo_hook"
    echo "4. Copy the generated token"
    exit 1
fi

SECRET_NAME="${ENVIRONMENT}/chatbot/github-token"
SECRET_VALUE="{\"token\":\"${GITHUB_TOKEN}\"}"

echo "Creating GitHub token secret for environment: $ENVIRONMENT"
echo "Secret name: $SECRET_NAME"

# Create the secret
aws secretsmanager create-secret \
    --name "$SECRET_NAME" \
    --description "GitHub Personal Access Token for Amplify deployment in $ENVIRONMENT environment" \
    --secret-string "$SECRET_VALUE" \
    --tags '[
        {
            "Key": "Environment",
            "Value": "'$ENVIRONMENT'"
        },
        {
            "Key": "Project", 
            "Value": "faith-based-motivator-chatbot"
        },
        {
            "Key": "Component",
            "Value": "amplify"
        }
    ]' || {
    echo "Secret already exists, updating..."
    aws secretsmanager update-secret \
        --secret-id "$SECRET_NAME" \
        --secret-string "$SECRET_VALUE"
}

echo "GitHub token secret created/updated successfully!"
echo "You can now deploy the CDK stack with Amplify configuration."