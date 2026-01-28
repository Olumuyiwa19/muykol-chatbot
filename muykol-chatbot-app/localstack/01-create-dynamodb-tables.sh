#!/bin/bash

echo "Creating DynamoDB tables for Faith Motivator Chatbot..."

# Wait for LocalStack to be ready
echo "Waiting for LocalStack to be ready..."
until curl -s http://localhost:4566/_localstack/health | grep -q '"dynamodb": "available"'; do
    echo "Waiting for DynamoDB service..."
    sleep 2
done

echo "LocalStack is ready. Creating tables..."

# User Profiles Table
echo "Creating User Profiles table..."
awslocal dynamodb create-table \
  --table-name FaithChatbot-UserProfiles \
  --attribute-definitions \
    AttributeName=user_id,AttributeType=S \
    AttributeName=email,AttributeType=S \
  --key-schema \
    AttributeName=user_id,KeyType=HASH \
  --global-secondary-indexes \
    IndexName=EmailIndex,KeySchema=[{AttributeName=email,KeyType=HASH}],Projection={ProjectionType=ALL},ProvisionedThroughput={ReadCapacityUnits=5,WriteCapacityUnits=5} \
  --provisioned-throughput \
    ReadCapacityUnits=5,WriteCapacityUnits=5 \
  --region us-east-1

# Conversation Sessions Table
echo "Creating Conversation Sessions table..."
awslocal dynamodb create-table \
  --table-name FaithChatbot-ConversationSessions \
  --attribute-definitions \
    AttributeName=session_id,AttributeType=S \
    AttributeName=user_id,AttributeType=S \
    AttributeName=created_at,AttributeType=S \
  --key-schema \
    AttributeName=session_id,KeyType=HASH \
  --global-secondary-indexes \
    IndexName=UserIndex,KeySchema=[{AttributeName=user_id,KeyType=HASH},{AttributeName=created_at,KeyType=RANGE}],Projection={ProjectionType=ALL},ProvisionedThroughput={ReadCapacityUnits=5,WriteCapacityUnits=5} \
  --provisioned-throughput \
    ReadCapacityUnits=5,WriteCapacityUnits=5 \
  --region us-east-1

# Chat Messages Table
echo "Creating Chat Messages table..."
awslocal dynamodb create-table \
  --table-name FaithChatbot-ChatMessages \
  --attribute-definitions \
    AttributeName=session_id,AttributeType=S \
    AttributeName=message_id,AttributeType=S \
    AttributeName=timestamp,AttributeType=S \
  --key-schema \
    AttributeName=session_id,KeyType=HASH \
    AttributeName=message_id,KeyType=RANGE \
  --local-secondary-indexes \
    IndexName=TimestampIndex,KeySchema=[{AttributeName=session_id,KeyType=HASH},{AttributeName=timestamp,KeyType=RANGE}],Projection={ProjectionType=ALL} \
  --provisioned-throughput \
    ReadCapacityUnits=5,WriteCapacityUnits=5 \
  --region us-east-1

# Prayer Requests Table
echo "Creating Prayer Requests table..."
awslocal dynamodb create-table \
  --table-name FaithChatbot-PrayerRequests \
  --attribute-definitions \
    AttributeName=request_id,AttributeType=S \
    AttributeName=user_id,AttributeType=S \
    AttributeName=status,AttributeType=S \
    AttributeName=created_at,AttributeType=S \
  --key-schema \
    AttributeName=request_id,KeyType=HASH \
  --global-secondary-indexes \
    IndexName=UserIndex,KeySchema=[{AttributeName=user_id,KeyType=HASH},{AttributeName=created_at,KeyType=RANGE}],Projection={ProjectionType=ALL},ProvisionedThroughput={ReadCapacityUnits=5,WriteCapacityUnits=5} \
    IndexName=StatusIndex,KeySchema=[{AttributeName=status,KeyType=HASH},{AttributeName=created_at,KeyType=RANGE}],Projection={ProjectionType=ALL},ProvisionedThroughput={ReadCapacityUnits=5,WriteCapacityUnits=5} \
  --provisioned-throughput \
    ReadCapacityUnits=5,WriteCapacityUnits=5 \
  --region us-east-1

# Consent Logs Table
echo "Creating Consent Logs table..."
awslocal dynamodb create-table \
  --table-name FaithChatbot-ConsentLogs \
  --attribute-definitions \
    AttributeName=log_id,AttributeType=S \
    AttributeName=user_id,AttributeType=S \
    AttributeName=timestamp,AttributeType=S \
  --key-schema \
    AttributeName=log_id,KeyType=HASH \
  --global-secondary-indexes \
    IndexName=UserIndex,KeySchema=[{AttributeName=user_id,KeyType=HASH},{AttributeName=timestamp,KeyType=RANGE}],Projection={ProjectionType=ALL},ProvisionedThroughput={ReadCapacityUnits=5,WriteCapacityUnits=5} \
  --provisioned-throughput \
    ReadCapacityUnits=5,WriteCapacityUnits=5 \
  --region us-east-1

echo "✅ DynamoDB tables created successfully!"

# List created tables
echo "Listing created tables:"
awslocal dynamodb list-tables --region us-east-1