#!/bin/bash

echo "Creating SQS queues for Faith Motivator Chatbot..."

# Wait for SQS service to be ready
echo "Waiting for SQS service to be ready..."
until curl -s http://localhost:4566/_localstack/health | grep -q '"sqs": "available"'; do
    echo "Waiting for SQS service..."
    sleep 2
done

echo "SQS service is ready. Creating queues..."

# Dead Letter Queue (create first)
echo "Creating Dead Letter Queue..."
awslocal sqs create-queue \
  --queue-name FaithChatbot-PrayerRequests-DLQ \
  --attributes MessageRetentionPeriod=1209600 \
  --region us-east-1

# Get DLQ ARN for main queue configuration
DLQ_URL=$(awslocal sqs get-queue-url --queue-name FaithChatbot-PrayerRequests-DLQ --region us-east-1 --output text --query 'QueueUrl')
DLQ_ARN=$(awslocal sqs get-queue-attributes --queue-url $DLQ_URL --attribute-names QueueArn --region us-east-1 --output text --query 'Attributes.QueueArn')

echo "DLQ ARN: $DLQ_ARN"

# Prayer Requests Queue with DLQ configuration
echo "Creating Prayer Requests Queue..."
awslocal sqs create-queue \
  --queue-name FaithChatbot-PrayerRequests \
  --attributes '{
    "VisibilityTimeoutSeconds": "300",
    "MessageRetentionPeriod": "1209600",
    "ReceiveMessageWaitTimeSeconds": "20",
    "RedrivePolicy": "{\"deadLetterTargetArn\":\"'$DLQ_ARN'\",\"maxReceiveCount\":3}"
  }' \
  --region us-east-1

# Email Notifications Queue
echo "Creating Email Notifications Queue..."
awslocal sqs create-queue \
  --queue-name FaithChatbot-EmailNotifications \
  --attributes '{
    "VisibilityTimeoutSeconds": "300",
    "MessageRetentionPeriod": "1209600",
    "ReceiveMessageWaitTimeSeconds": "20"
  }' \
  --region us-east-1

# Data Export Queue
echo "Creating Data Export Queue..."
awslocal sqs create-queue \
  --queue-name FaithChatbot-DataExport \
  --attributes '{
    "VisibilityTimeoutSeconds": "900",
    "MessageRetentionPeriod": "1209600",
    "ReceiveMessageWaitTimeSeconds": "20"
  }' \
  --region us-east-1

echo "✅ SQS queues created successfully!"

# List created queues
echo "Listing created queues:"
awslocal sqs list-queues --region us-east-1

# Display queue URLs for reference
echo ""
echo "Queue URLs:"
echo "Prayer Requests: $(awslocal sqs get-queue-url --queue-name FaithChatbot-PrayerRequests --region us-east-1 --output text --query 'QueueUrl')"
echo "Prayer Requests DLQ: $(awslocal sqs get-queue-url --queue-name FaithChatbot-PrayerRequests-DLQ --region us-east-1 --output text --query 'QueueUrl')"
echo "Email Notifications: $(awslocal sqs get-queue-url --queue-name FaithChatbot-EmailNotifications --region us-east-1 --output text --query 'QueueUrl')"
echo "Data Export: $(awslocal sqs get-queue-url --queue-name FaithChatbot-DataExport --region us-east-1 --output text --query 'QueueUrl')"