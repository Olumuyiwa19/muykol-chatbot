#!/bin/bash

# GitHub OIDC Provider Setup using AWS CLI
# This script creates the OIDC provider and IAM role using CLI commands instead of CloudFormation

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Configuration
GITHUB_REPO="Olumuyiwa19/muykol-chatbot"
OIDC_PROVIDER_URL="https://token.actions.githubusercontent.com"
ROLE_NAME="GitHubActions-ChatbotDeployment-Role"

print_header "🚀 Setting up GitHub OIDC Provider using AWS CLI"
echo

# Step 1: Create OIDC Identity Provider
print_status "Creating GitHub OIDC Identity Provider..."

# Check if OIDC provider already exists
EXISTING_PROVIDER=$(aws iam list-open-id-connect-providers --query "OpenIDConnectProviderList[?contains(Arn, 'token.actions.githubusercontent.com')].Arn" --output text 2>/dev/null || echo "")

if [[ -n "$EXISTING_PROVIDER" ]]; then
    print_warning "OIDC provider already exists: $EXISTING_PROVIDER"
    OIDC_PROVIDER_ARN="$EXISTING_PROVIDER"
else
    # Create the OIDC provider
    OIDC_PROVIDER_ARN=$(aws iam create-open-id-connect-provider \
        --url "$OIDC_PROVIDER_URL" \
        --client-id-list sts.amazonaws.com \
        --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1 1c58a3a8518e8759bf075b76b750d4f2df264fcd \
        --query 'OpenIDConnectProviderArn' \
        --output text)
    
    print_status "Created OIDC provider: $OIDC_PROVIDER_ARN"
fi

# Step 2: Create Trust Policy Document
print_status "Creating IAM role trust policy..."

cat > trust-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "$OIDC_PROVIDER_ARN"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringEquals": {
                    "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
                },
                "StringLike": {
                    "token.actions.githubusercontent.com:sub": [
                        "repo:$GITHUB_REPO:ref:refs/heads/main",
                        "repo:$GITHUB_REPO:ref:refs/heads/develop",
                        "repo:$GITHUB_REPO:ref:refs/heads/release/*",
                        "repo:$GITHUB_REPO:pull_request"
                    ]
                }
            }
        }
    ]
}
EOF

# Step 3: Create IAM Role
print_status "Creating IAM role for GitHub Actions..."

# Check if role already exists
if aws iam get-role --role-name "$ROLE_NAME" >/dev/null 2>&1; then
    print_warning "Role $ROLE_NAME already exists, updating trust policy..."
    aws iam update-assume-role-policy --role-name "$ROLE_NAME" --policy-document file://trust-policy.json
else
    aws iam create-role \
        --role-name "$ROLE_NAME" \
        --assume-role-policy-document file://trust-policy.json \
        --description "IAM role for GitHub Actions CI/CD pipeline"
    
    print_status "Created IAM role: $ROLE_NAME"
fi

# Step 4: Attach PowerUser policy
print_status "Attaching PowerUserAccess policy..."
aws iam attach-role-policy \
    --role-name "$ROLE_NAME" \
    --policy-arn "arn:aws:iam::aws:policy/PowerUserAccess"

# Step 5: Create and attach custom policy for additional permissions
print_status "Creating custom deployment policy..."

cat > deployment-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "iam:GetRole",
                "iam:PassRole",
                "iam:CreateRole",
                "iam:AttachRolePolicy",
                "iam:DetachRolePolicy",
                "iam:PutRolePolicy",
                "iam:DeleteRolePolicy",
                "iam:GetRolePolicy",
                "iam:CreateInstanceProfile",
                "iam:AddRoleToInstanceProfile",
                "iam:RemoveRoleFromInstanceProfile",
                "iam:DeleteInstanceProfile",
                "iam:TagRole",
                "iam:UntagRole"
            ],
            "Resource": [
                "arn:aws:iam::*:role/cdk-*",
                "arn:aws:iam::*:role/*-chatbot-*",
                "arn:aws:iam::*:instance-profile/*-chatbot-*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "sts:GetCallerIdentity"
            ],
            "Resource": "*"
        }
    ]
}
EOF

# Check if policy already exists
POLICY_ARN="arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/GitHubActions-ChatbotDeployment-Policy"

if aws iam get-policy --policy-arn "$POLICY_ARN" >/dev/null 2>&1; then
    print_warning "Policy already exists, updating..."
    # Create new version
    aws iam create-policy-version \
        --policy-arn "$POLICY_ARN" \
        --policy-document file://deployment-policy.json \
        --set-as-default
else
    # Create new policy
    aws iam create-policy \
        --policy-name "GitHubActions-ChatbotDeployment-Policy" \
        --policy-document file://deployment-policy.json \
        --description "Additional permissions for GitHub Actions chatbot deployment"
    
    print_status "Created custom policy: $POLICY_ARN"
fi

# Attach custom policy to role
aws iam attach-role-policy \
    --role-name "$ROLE_NAME" \
    --policy-arn "$POLICY_ARN"

# Step 6: Get role ARN
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ROLE_ARN="arn:aws:iam::$ACCOUNT_ID:role/$ROLE_NAME"

print_status "Setup completed successfully!"
echo
print_header "✅ GitHub OIDC Provider Setup Complete!"
echo
print_status "OIDC Provider ARN: $OIDC_PROVIDER_ARN"
print_status "IAM Role ARN: $ROLE_ARN"
echo
print_header "📋 Next Steps:"
echo "1. Add the following secret to your GitHub repository:"
echo "   Secret Name: AWS_ROLE_ARN"
echo "   Secret Value: $ROLE_ARN"
echo
echo "2. You can add this secret via:"
echo "   - GitHub web interface: Settings > Secrets and variables > Actions"
echo "   - GitHub CLI: gh secret set AWS_ROLE_ARN --body '$ROLE_ARN'"
echo
print_status "Your CI/CD pipeline is now ready to use!"

# Cleanup temporary files
rm -f trust-policy.json deployment-policy.json

print_status "Cleanup completed."