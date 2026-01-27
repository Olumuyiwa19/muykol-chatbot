#!/bin/bash
# Deploy to development environment

set -e

echo "🚀 Deploying to Development Environment..."

# Set environment variables
export CDK_ENVIRONMENT=dev

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

# Deploy the stack
echo "🚀 Deploying CDK stack for development..."
cdk deploy chatbot-dev \
    --context environment=dev \
    --require-approval never \
    --progress events

echo "✅ Development deployment completed!"
echo "📋 Stack outputs:"
aws cloudformation describe-stacks \
    --stack-name chatbot-dev \
    --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue]' \
    --output table