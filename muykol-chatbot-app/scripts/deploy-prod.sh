#!/bin/bash
# Deploy to production environment

set -e

echo "🚀 Deploying to Production Environment..."

# Set environment variables
export CDK_ENVIRONMENT=prod

# Change to the project directory
cd "$(dirname "$0")/.."

# Install dependencies if needed
if [ ! -d "venv" ]; then
    echo "📦 Creating virtual environment..."
    python3 -m venv venv
fi

echo "📦 Activating virtual environment..."
source venv/bin/activate

echo "📦 Installing dependencies..."
pip install -r requirements.txt

# Bootstrap CDK if needed (only run once per account/region)
echo "🔧 Checking CDK bootstrap status..."
if ! aws sts get-caller-identity > /dev/null 2>&1; then
    echo "❌ AWS credentials not configured. Please run 'aws configure' first."
    exit 1
fi

# Confirm production deployment
echo "⚠️  You are about to deploy to PRODUCTION environment."
read -p "Are you sure you want to continue? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "❌ Production deployment cancelled."
    exit 1
fi

# Deploy the stack
echo "🚀 Deploying CDK stack for production..."
cdk deploy chatbot-prod \
    --context environment=prod \
    --require-approval never \
    --progress events

echo "✅ Production deployment completed!"
echo "📋 Stack outputs:"
aws cloudformation describe-stacks \
    --stack-name chatbot-prod \
    --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue]' \
    --output table