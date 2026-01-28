#!/bin/bash

echo "Setting up Cognito User Pool for Faith Motivator Chatbot..."

# Wait for Cognito service to be ready
echo "Waiting for Cognito service to be ready..."
until curl -s http://localhost:4566/_localstack/health | grep -q '"cognito-idp": "available"'; do
    echo "Waiting for Cognito service..."
    sleep 2
done

echo "Cognito service is ready. Creating User Pool..."

# Create User Pool
echo "Creating User Pool..."
USER_POOL_RESPONSE=$(awslocal cognito-idp create-user-pool \
  --pool-name "FaithChatbot-UserPool-Dev" \
  --policies '{
    "PasswordPolicy": {
      "MinimumLength": 8,
      "RequireUppercase": true,
      "RequireLowercase": true,
      "RequireNumbers": true,
      "RequireSymbols": false
    }
  }' \
  --username_attributes email \
  --auto_verified_attributes email \
  --email_configuration '{
    "EmailSendingAccount": "COGNITO_DEFAULT"
  }' \
  --verification_message_template '{
    "DefaultEmailOption": "CONFIRM_WITH_CODE",
    "EmailSubject": "Faith Motivator - Verify your email",
    "EmailMessage": "Welcome to Faith Motivator! Your verification code is {####}"
  }' \
  --user_pool_add_ons '{
    "AdvancedSecurityMode": "OFF"
  }' \
  --schema '[
    {
      "Name": "email",
      "AttributeDataType": "String",
      "Required": true,
      "Mutable": true
    },
    {
      "Name": "given_name",
      "AttributeDataType": "String",
      "Required": false,
      "Mutable": true
    },
    {
      "Name": "family_name",
      "AttributeDataType": "String",
      "Required": false,
      "Mutable": true
    },
    {
      "Name": "prayer_connect_consent",
      "AttributeDataType": "String",
      "Required": false,
      "Mutable": true
    }
  ]' \
  --region us-east-1)

USER_POOL_ID=$(echo $USER_POOL_RESPONSE | jq -r '.UserPool.Id')
echo "User Pool ID: $USER_POOL_ID"

# Create User Pool Client
echo "Creating User Pool Client..."
CLIENT_RESPONSE=$(awslocal cognito-idp create-user-pool-client \
  --user-pool-id $USER_POOL_ID \
  --client-name "FaithChatbot-WebClient-Dev" \
  --generate-secret false \
  --prevent-user-existence-errors ENABLED \
  --enable-token-revocation true \
  --allowed-o-auth-flows code \
  --allowed-o-auth-flows-user-pool-client true \
  --allowed-o-auth-scopes email openid profile \
  --callback-urls '["http://localhost:3000/auth/callback","http://localhost:8000/auth/callback"]' \
  --logout-urls '["http://localhost:3000/","http://localhost:8000/"]' \
  --supported-identity-providers COGNITO \
  --access-token-validity 60 \
  --id-token-validity 60 \
  --refresh-token-validity 43200 \
  --token-validity-units '{
    "AccessToken": "minutes",
    "IdToken": "minutes",
    "RefreshToken": "minutes"
  }' \
  --read-attributes email email_verified given_name family_name custom:prayer_connect_consent \
  --write-attributes email given_name family_name custom:prayer_connect_consent \
  --explicit-auth-flows ALLOW_USER_SRP_AUTH ALLOW_REFRESH_TOKEN_AUTH \
  --region us-east-1)

CLIENT_ID=$(echo $CLIENT_RESPONSE | jq -r '.UserPoolClient.ClientId')
echo "User Pool Client ID: $CLIENT_ID"

# Create User Pool Domain
echo "Creating User Pool Domain..."
awslocal cognito-idp create-user-pool-domain \
  --domain "auth-faithchatbot-dev" \
  --user-pool-id $USER_POOL_ID \
  --region us-east-1

echo "✅ Cognito User Pool setup completed successfully!"

# Create test users
echo "Creating test users..."

# Test user 1
echo "Creating test user: testuser@faithchatbot.local"
awslocal cognito-idp admin-create-user \
  --user-pool-id $USER_POOL_ID \
  --username "testuser@faithchatbot.local" \
  --user-attributes Name=email,Value=testuser@faithchatbot.local Name=given_name,Value=Test Name=family_name,Value=User Name=email_verified,Value=true \
  --temporary-password "TempPass123!" \
  --message-action SUPPRESS \
  --region us-east-1

# Set permanent password for test user
awslocal cognito-idp admin-set-user-password \
  --user-pool-id $USER_POOL_ID \
  --username "testuser@faithchatbot.local" \
  --password "TestPass123!" \
  --permanent \
  --region us-east-1

# Test user 2
echo "Creating test user: john.doe@faithchatbot.local"
awslocal cognito-idp admin-create-user \
  --user-pool-id $USER_POOL_ID \
  --username "john.doe@faithchatbot.local" \
  --user-attributes Name=email,Value=john.doe@faithchatbot.local Name=given_name,Value=John Name=family_name,Value=Doe Name=email_verified,Value=true \
  --temporary-password "TempPass123!" \
  --message-action SUPPRESS \
  --region us-east-1

awslocal cognito-idp admin-set-user-password \
  --user-pool-id $USER_POOL_ID \
  --username "john.doe@faithchatbot.local" \
  --password "TestPass123!" \
  --permanent \
  --region us-east-1

echo "✅ Test users created successfully!"

# Display configuration for environment variables
echo ""
echo "=== Cognito Configuration for Environment Variables ==="
echo "AWS_COGNITO_USER_POOL_ID=$USER_POOL_ID"
echo "AWS_COGNITO_CLIENT_ID=$CLIENT_ID"
echo "AWS_COGNITO_DOMAIN=auth-faithchatbot-dev"
echo "AWS_COGNITO_HOSTED_UI_URL=http://localhost:4566/auth-faithchatbot-dev"
echo ""
echo "Test Users:"
echo "  Email: testuser@faithchatbot.local"
echo "  Password: TestPass123!"
echo ""
echo "  Email: john.doe@faithchatbot.local"
echo "  Password: TestPass123!"
echo ""

# Save configuration to file for easy reference
cat > /tmp/cognito-config.env << EOF
# Cognito Configuration for LocalStack
export AWS_COGNITO_USER_POOL_ID=$USER_POOL_ID
export AWS_COGNITO_CLIENT_ID=$CLIENT_ID
export AWS_COGNITO_DOMAIN=auth-faithchatbot-dev
export AWS_COGNITO_HOSTED_UI_URL=http://localhost:4566/auth-faithchatbot-dev
EOF

echo "Configuration saved to /tmp/cognito-config.env"
echo "✅ Cognito setup completed successfully!"