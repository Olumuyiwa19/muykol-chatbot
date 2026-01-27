#!/bin/bash

# Setup script for Faith-Based Motivator Chatbot development environment

set -e

echo "🚀 Setting up Faith-Based Motivator Chatbot development environment..."

# Check Python version
python_version=$(python3 --version 2>&1 | awk '{print $2}' | cut -d. -f1,2)
required_version="3.11"

if [ "$(printf '%s\n' "$required_version" "$python_version" | sort -V | head -n1)" != "$required_version" ]; then
    echo "❌ Python 3.11+ is required. Current version: $python_version"
    exit 1
fi

echo "✅ Python version check passed: $python_version"

# Create virtual environment if it doesn't exist
if [ ! -d "venv" ]; then
    echo "📦 Creating Python virtual environment..."
    python3 -m venv venv
else
    echo "✅ Virtual environment already exists"
fi

# Activate virtual environment
echo "🔧 Activating virtual environment..."
source venv/bin/activate

# Upgrade pip
echo "⬆️ Upgrading pip..."
pip install --upgrade pip

# Install root dependencies
echo "📚 Installing root dependencies..."
pip install -r requirements.txt

# Install backend dependencies
echo "🔧 Installing backend dependencies..."
cd backend
pip install -r requirements.txt
cd ..

# Install frontend dependencies
echo "🎨 Installing frontend dependencies..."
cd frontend
pip install -r requirements.txt
cd ..

# Copy environment file if it doesn't exist
if [ ! -f ".env" ]; then
    echo "📝 Creating .env file from template..."
    cp .env.example .env
    echo "⚠️ Please edit .env file with your configuration"
else
    echo "✅ .env file already exists"
fi

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "⚠️ Docker is not running. Please start Docker to use docker-compose"
else
    echo "✅ Docker is running"
fi

# Check if AWS CLI is configured
if ! aws sts get-caller-identity > /dev/null 2>&1; then
    echo "⚠️ AWS CLI is not configured. Run 'aws configure' to set up your credentials"
else
    echo "✅ AWS CLI is configured"
fi

# Check if CDK is installed
if ! command -v cdk &> /dev/null; then
    echo "⚠️ AWS CDK CLI is not installed. Install with: npm install -g aws-cdk"
else
    echo "✅ AWS CDK CLI is installed: $(cdk --version)"
fi

echo ""
echo "🎉 Setup complete!"
echo ""
echo "Next steps:"
echo "1. Activate the virtual environment: source venv/bin/activate"
echo "2. Edit .env file with your configuration"
echo "3. Run locally with: docker-compose up --build"
echo "4. Deploy to AWS with: cdk deploy ChatbotStackDev"
echo ""
echo "Access points:"
echo "- Frontend: http://localhost:3000"
echo "- Backend API: http://localhost:8000"
echo "- API Docs: http://localhost:8000/docs"