#!/bin/bash

echo "Setting up Secrets Manager for Faith Motivator Chatbot..."

# Wait for Secrets Manager service to be ready
echo "Waiting for Secrets Manager service to be ready..."
until curl -s http://localhost:4566/_localstack/health | grep -q '"secretsmanager": "available"'; do
    echo "Waiting for Secrets Manager service..."
    sleep 2
done

echo "Secrets Manager service is ready. Creating secrets..."

# Database configuration secret
echo "Creating database configuration secret..."
awslocal secretsmanager create-secret \
  --name "faith-chatbot/database-config" \
  --description "Database configuration for Faith Motivator Chatbot" \
  --secret-string '{
    "host": "localhost",
    "port": 5432,
    "database": "faithchatbot_dev",
    "username": "dev",
    "password": "devpass"
  }' \
  --region us-east-1

# API keys secret
echo "Creating API keys secret..."
awslocal secretsmanager create-secret \
  --name "faith-chatbot/api-keys" \
  --description "API keys for external services" \
  --secret-string '{
    "openai_api_key": "sk-dev-key-for-local-testing",
    "telegram_bot_token": "dev-telegram-token",
    "sentry_dsn": "https://dev-sentry-dsn@sentry.io/project"
  }' \
  --region us-east-1

# JWT configuration secret
echo "Creating JWT configuration secret..."
awslocal secretsmanager create-secret \
  --name "faith-chatbot/jwt-config" \
  --description "JWT configuration for authentication" \
  --secret-string '{
    "secret_key": "dev-jwt-secret-key-change-in-production-32chars",
    "algorithm": "HS256",
    "expiration_hours": 24
  }' \
  --region us-east-1

# Email configuration secret
echo "Creating email configuration secret..."
awslocal secretsmanager create-secret \
  --name "faith-chatbot/email-config" \
  --description "Email service configuration" \
  --secret-string '{
    "smtp_host": "localhost",
    "smtp_port": 587,
    "smtp_username": "noreply@faithchatbot.local",
    "smtp_password": "dev-email-password",
    "sender_email": "noreply@faithchatbot.local",
    "sender_name": "Faith Motivator Chatbot"
  }' \
  --region us-east-1

# Third-party integrations secret
echo "Creating third-party integrations secret..."
awslocal secretsmanager create-secret \
  --name "faith-chatbot/integrations" \
  --description "Third-party service integrations" \
  --secret-string '{
    "google_oauth_client_id": "dev-google-client-id",
    "google_oauth_client_secret": "dev-google-client-secret",
    "facebook_app_id": "dev-facebook-app-id",
    "facebook_app_secret": "dev-facebook-app-secret"
  }' \
  --region us-east-1

echo "✅ Secrets created successfully!"

# List created secrets
echo "Listing created secrets:"
awslocal secretsmanager list-secrets --region us-east-1

echo "✅ Secrets Manager setup completed successfully!"