#!/bin/bash

# GitHub OIDC Provider Setup for muykol-chatbot Terraform Infrastructure
# This script creates the OIDC provider and IAM roles using AWS CLI
# Aligned with the Terraform infrastructure in muykol-chatbot-infra/

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

# Configuration - Update these values for your setup
PROJECT_NAME="muykol-chatbot"
GITHUB_REPO="olumuyiwa19/muykol-chatbot"
OIDC_PROVIDER_URL="https://token.actions.githubusercontent.com"
TERRAFORM_STATE_BUCKET="muykol-chatbot-terraform-state"  # Update if different

# Role names aligned with Terraform configuration
INFRASTRUCTURE_ROLE_NAME="${PROJECT_NAME}-github-actions-infrastructure-role"
DEPLOYMENT_ROLE_NAME="${PROJECT_NAME}-github-actions-deployment-role"

print_header "🚀 Setting up GitHub OIDC for muykol-chatbot Terraform Infrastructure"
echo

# Validate configuration
if [[ "$GITHUB_REPO" == "olumuyiwa19/muykol-chatbot" ]]; then
    print_error "Please update GITHUB_REPO variable with your actual GitHub username!"
    echo "Edit this script and change: GITHUB_REPO=\"olumuyiwa19/muykol-chatbot\""
    exit 1
fi

print_status "Configuration:"
print_status "  Project: $PROJECT_NAME"
print_status "  GitHub Repository: $GITHUB_REPO"
print_status "  Terraform State Bucket: $TERRAFORM_STATE_BUCKET"
echo

# Step 1: Create OIDC Identity Provider
print_status "Creating GitHub OIDC Identity Provider..."

# Check if OIDC provider already exists
EXISTING_PROVIDER=$(aws iam list-open-id-connect-providers --query "OpenIDConnectProviderList[?contains(Arn, 'token.actions.githubusercontent.com')].Arn" --output text 2>/dev/null || echo "")

if [[ -n "$EXISTING_PROVIDER" ]]; then
    print_warning "OIDC provider already exists: $EXISTING_PROVIDER"
    OIDC_PROVIDER_ARN="$EXISTING_PROVIDER"
else
    # Create the OIDC provider with updated thumbprints
    OIDC_PROVIDER_ARN=$(aws iam create-open-id-connect-provider \
        --url "$OIDC_PROVIDER_URL" \
        --client-id-list sts.amazonaws.com \
        --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1 1c58a3a8518e8759bf075b76b750d4f2df264fcd \
        --tags Key=Name,Value="${PROJECT_NAME}-github-actions-oidc" \
        --query 'OpenIDConnectProviderArn' \
        --output text)
    
    print_status "Created OIDC provider: $OIDC_PROVIDER_ARN"
fi

# Step 2: Create Infrastructure Role Trust Policy
print_status "Creating Infrastructure IAM role trust policy..."

cat > infrastructure-trust-policy.json << EOF
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
                    "token.actions.githubusercontent.com:sub": "repo:$GITHUB_REPO:*"
                }
            }
        }
    ]
}
EOF

# Step 3: Create Deployment Role Trust Policy (main branch only)
print_status "Creating Deployment IAM role trust policy..."

cat > deployment-trust-policy.json << EOF
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
                    "token.actions.githubusercontent.com:sub": "repo:$GITHUB_REPO:ref:refs/heads/main"
                }
            }
        }
    ]
}
EOF

# Step 4: Create Infrastructure IAM Role
print_status "Creating Infrastructure IAM role for GitHub Actions..."

if aws iam get-role --role-name "$INFRASTRUCTURE_ROLE_NAME" >/dev/null 2>&1; then
    print_warning "Infrastructure role $INFRASTRUCTURE_ROLE_NAME already exists, updating trust policy..."
    aws iam update-assume-role-policy --role-name "$INFRASTRUCTURE_ROLE_NAME" --policy-document file://infrastructure-trust-policy.json
else
    aws iam create-role \
        --role-name "$INFRASTRUCTURE_ROLE_NAME" \
        --assume-role-policy-document file://infrastructure-trust-policy.json \
        --description "IAM role for GitHub Actions Terraform infrastructure management" \
        --tags Key=Name,Value="$INFRASTRUCTURE_ROLE_NAME"
    
    print_status "Created Infrastructure IAM role: $INFRASTRUCTURE_ROLE_NAME"
fi

# Step 5: Create Deployment IAM Role
print_status "Creating Deployment IAM role for GitHub Actions..."

if aws iam get-role --role-name "$DEPLOYMENT_ROLE_NAME" >/dev/null 2>&1; then
    print_warning "Deployment role $DEPLOYMENT_ROLE_NAME already exists, updating trust policy..."
    aws iam update-assume-role-policy --role-name "$DEPLOYMENT_ROLE_NAME" --policy-document file://deployment-trust-policy.json
else
    aws iam create-role \
        --role-name "$DEPLOYMENT_ROLE_NAME" \
        --assume-role-policy-document file://deployment-trust-policy.json \
        --description "IAM role for GitHub Actions application deployment" \
        --tags Key=Name,Value="$DEPLOYMENT_ROLE_NAME"
    
    print_status "Created Deployment IAM role: $DEPLOYMENT_ROLE_NAME"
fi

# Step 6: Create Infrastructure Management Policy
print_status "Creating Infrastructure management policy..."

cat > infrastructure-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:*",
                "vpc:*",
                "iam:*",
                "dynamodb:*",
                "sqs:*",
                "cognito-idp:*",
                "bedrock:*",
                "logs:*",
                "secretsmanager:*",
                "kms:*",
                "s3:*",
                "sts:GetCallerIdentity",
                "ecs:*",
                "elasticloadbalancing:*",
                "application-autoscaling:*",
                "cloudwatch:*",
                "sns:*"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:PutObject",
                "s3:DeleteObject"
            ],
            "Resource": [
                "arn:aws:s3:::$TERRAFORM_STATE_BUCKET/*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::$TERRAFORM_STATE_BUCKET"
            ]
        }
    ]
}
EOF

# Step 7: Create Application Deployment Policy
print_status "Creating Application deployment policy..."

cat > deployment-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ecr:GetAuthorizationToken",
                "ecr:BatchCheckLayerAvailability",
                "ecr:GetDownloadUrlForLayer",
                "ecr:BatchGetImage",
                "ecr:PutImage",
                "ecr:InitiateLayerUpload",
                "ecr:UploadLayerPart",
                "ecr:CompleteLayerUpload"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ecs:UpdateService",
                "ecs:DescribeServices",
                "ecs:DescribeTaskDefinition",
                "ecs:RegisterTaskDefinition"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "iam:PassRole"
            ],
            "Resource": [
                "arn:aws:iam::*:role/${PROJECT_NAME}-ecs-task-role",
                "arn:aws:iam::*:role/${PROJECT_NAME}-ecs-task-execution-role"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:GetObject",
                "s3:DeleteObject"
            ],
            "Resource": [
                "arn:aws:s3:::${PROJECT_NAME}-frontend-assets/*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "cloudfront:CreateInvalidation"
            ],
            "Resource": "*"
        }
    ]
}
EOF

# Step 8: Attach policies to Infrastructure role
print_status "Attaching policies to Infrastructure role..."

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
INFRASTRUCTURE_POLICY_ARN="arn:aws:iam::$ACCOUNT_ID:policy/${PROJECT_NAME}-github-actions-infrastructure-policy"

# Create or update infrastructure policy
if aws iam get-policy --policy-arn "$INFRASTRUCTURE_POLICY_ARN" >/dev/null 2>&1; then
    print_warning "Infrastructure policy already exists, creating new version..."
    aws iam create-policy-version \
        --policy-arn "$INFRASTRUCTURE_POLICY_ARN" \
        --policy-document file://infrastructure-policy.json \
        --set-as-default >/dev/null
else
    aws iam create-policy \
        --policy-name "${PROJECT_NAME}-github-actions-infrastructure-policy" \
        --policy-document file://infrastructure-policy.json \
        --description "Infrastructure management permissions for GitHub Actions" >/dev/null
    
    print_status "Created infrastructure policy: $INFRASTRUCTURE_POLICY_ARN"
fi

# Attach infrastructure policy
aws iam attach-role-policy \
    --role-name "$INFRASTRUCTURE_ROLE_NAME" \
    --policy-arn "$INFRASTRUCTURE_POLICY_ARN"

# Step 9: Attach policies to Deployment role
print_status "Attaching policies to Deployment role..."

DEPLOYMENT_POLICY_ARN="arn:aws:iam::$ACCOUNT_ID:policy/${PROJECT_NAME}-github-actions-deployment-policy"

# Create or update deployment policy
if aws iam get-policy --policy-arn "$DEPLOYMENT_POLICY_ARN" >/dev/null 2>&1; then
    print_warning "Deployment policy already exists, creating new version..."
    aws iam create-policy-version \
        --policy-arn "$DEPLOYMENT_POLICY_ARN" \
        --policy-document file://deployment-policy.json \
        --set-as-default >/dev/null
else
    aws iam create-policy \
        --policy-name "${PROJECT_NAME}-github-actions-deployment-policy" \
        --policy-document file://deployment-policy.json \
        --description "Application deployment permissions for GitHub Actions" >/dev/null
    
    print_status "Created deployment policy: $DEPLOYMENT_POLICY_ARN"
fi

# Attach deployment policy
aws iam attach-role-policy \
    --role-name "$DEPLOYMENT_ROLE_NAME" \
    --policy-arn "$DEPLOYMENT_POLICY_ARN"

# Step 10: Get role ARNs
INFRASTRUCTURE_ROLE_ARN="arn:aws:iam::$ACCOUNT_ID:role/$INFRASTRUCTURE_ROLE_NAME"
DEPLOYMENT_ROLE_ARN="arn:aws:iam::$ACCOUNT_ID:role/$DEPLOYMENT_ROLE_NAME"

print_status "Setup completed successfully!"
echo
print_header "✅ GitHub OIDC Provider Setup Complete!"
echo
print_status "OIDC Provider ARN: $OIDC_PROVIDER_ARN"
print_status "Infrastructure Role ARN: $INFRASTRUCTURE_ROLE_ARN"
print_status "Deployment Role ARN: $DEPLOYMENT_ROLE_ARN"
echo
print_header "📋 Next Steps:"
echo
print_status "1. Add the following secrets to your GitHub repository:"
echo "   Secret Name: AWS_GITHUB_ACTIONS_ROLE_ARN"
echo "   Secret Value: $INFRASTRUCTURE_ROLE_ARN"
echo
echo "   (Optional) For deployment workflows:"
echo "   Secret Name: AWS_DEPLOYMENT_ROLE_ARN"
echo "   Secret Value: $DEPLOYMENT_ROLE_ARN"
echo
print_status "2. Add secrets via GitHub CLI:"
echo "   gh secret set AWS_GITHUB_ACTIONS_ROLE_ARN --body '$INFRASTRUCTURE_ROLE_ARN'"
echo "   gh secret set AWS_DEPLOYMENT_ROLE_ARN --body '$DEPLOYMENT_ROLE_ARN'"
echo
print_status "3. Or add via GitHub web interface:"
echo "   Repository Settings > Secrets and variables > Actions > New repository secret"
echo
print_header "🔧 Terraform Integration:"
echo
print_status "This setup is compatible with your Terraform infrastructure:"
echo "   - Infrastructure managed via: muykol-chatbot-infra/"
echo "   - State stored in: $TERRAFORM_STATE_BUCKET"
echo "   - GitHub Actions workflows: .github/workflows/"
echo
print_status "Your CI/CD pipeline is now ready for Terraform deployments!"

# Cleanup temporary files
rm -f infrastructure-trust-policy.json deployment-trust-policy.json infrastructure-policy.json deployment-policy.json

print_status "Cleanup completed."
echo
print_header "🎉 Setup Complete! Your muykol-chatbot infrastructure is ready for GitHub Actions!"