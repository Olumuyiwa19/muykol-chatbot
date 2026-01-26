---
inclusion: fileMatch
fileMatchPattern: "**/*.{py,ts,js,yaml,yml,json,tf,cdktf}"
---

# AWS Architecture Patterns for Faith Chatbot

## VPC and Networking Patterns

### Private Subnet Architecture
```yaml
# Use this pattern for ECS Fargate tasks
PrivateSubnet:
  Type: AWS::EC2::Subnet
  Properties:
    VpcId: !Ref VPC
    AvailabilityZone: !Select [0, !GetAZs '']
    CidrBlock: 10.0.1.0/24
    MapPublicIpOnLaunch: false
```

### VPC Endpoints for AWS Services
Always use VPC endpoints to avoid NAT Gateway costs and improve security:
```python
# Required VPC endpoints for this project
vpc_endpoints = [
    "com.amazonaws.region.bedrock-runtime",
    "com.amazonaws.region.dynamodb",
    "com.amazonaws.region.sqs",
    "com.amazonaws.region.ses",
    "com.amazonaws.region.logs",
    "com.amazonaws.region.ecr.dkr",
    "com.amazonaws.region.ecr.api"
]
```

## ECS Fargate Best Practices

### Task Definition Security
```json
{
  "family": "faith-chatbot-api",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "512",
  "memory": "1024",
  "executionRoleArn": "arn:aws:iam::account:role/ecsTaskExecutionRole",
  "taskRoleArn": "arn:aws:iam::account:role/faithChatbotTaskRole",
  "containerDefinitions": [{
    "name": "api",
    "image": "account.dkr.ecr.region.amazonaws.com/faith-chatbot:latest",
    "portMappings": [{"containerPort": 8000, "protocol": "tcp"}],
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-group": "/ecs/faith-chatbot",
        "awslogs-region": "us-east-1",
        "awslogs-stream-prefix": "ecs"
      }
    },
    "environment": [
      {"name": "AWS_DEFAULT_REGION", "value": "us-east-1"},
      {"name": "ENVIRONMENT", "value": "production"}
    ],
    "secrets": [
      {"name": "TELEGRAM_BOT_TOKEN", "valueFrom": "arn:aws:secretsmanager:region:account:secret:telegram-bot-token"}
    ]
  }]
}
```

### Auto Scaling Configuration
```python
# ECS Service Auto Scaling
auto_scaling_target = {
    "ServiceNamespace": "ecs",
    "ResourceId": "service/faith-chatbot-cluster/faith-chatbot-service",
    "ScalableDimension": "ecs:service:DesiredCount",
    "MinCapacity": 2,
    "MaxCapacity": 10
}

scaling_policy = {
    "PolicyName": "CPUScalingPolicy",
    "PolicyType": "TargetTrackingScaling",
    "TargetTrackingScalingPolicyConfiguration": {
        "TargetValue": 70.0,
        "PredefinedMetricSpecification": {
            "PredefinedMetricType": "ECSServiceAverageCPUUtilization"
        },
        "ScaleOutCooldown": 300,
        "ScaleInCooldown": 300
    }
}
```

## DynamoDB Design Patterns

### Table Design for Chat Application
```python
# UserProfile Table
user_profile_table = {
    "TableName": "FaithChatbot-UserProfiles",
    "KeySchema": [
        {"AttributeName": "user_id", "KeyType": "HASH"}
    ],
    "AttributeDefinitions": [
        {"AttributeName": "user_id", "AttributeType": "S"},
        {"AttributeName": "email", "AttributeType": "S"}
    ],
    "GlobalSecondaryIndexes": [{
        "IndexName": "EmailIndex",
        "KeySchema": [{"AttributeName": "email", "KeyType": "HASH"}],
        "Projection": {"ProjectionType": "ALL"}
    }],
    "BillingMode": "ON_DEMAND",
    "PointInTimeRecoverySpecification": {"PointInTimeRecoveryEnabled": True}
}

# ConversationSession Table with TTL
conversation_table = {
    "TableName": "FaithChatbot-Conversations",
    "KeySchema": [
        {"AttributeName": "session_id", "KeyType": "HASH"}
    ],
    "AttributeDefinitions": [
        {"AttributeName": "session_id", "AttributeType": "S"},
        {"AttributeName": "user_id", "AttributeType": "S"}
    ],
    "GlobalSecondaryIndexes": [{
        "IndexName": "UserIndex",
        "KeySchema": [{"AttributeName": "user_id", "KeyType": "HASH"}],
        "Projection": {"ProjectionType": "ALL"}
    }],
    "TimeToLiveSpecification": {
        "AttributeName": "ttl",
        "Enabled": True
    }
}
```

## Amazon Bedrock Integration Patterns

### Bedrock Client Configuration
```python
import boto3
from botocore.config import Config

# Configure Bedrock client with retry and timeout settings
bedrock_config = Config(
    region_name='us-east-1',
    retries={'max_attempts': 3, 'mode': 'adaptive'},
    max_pool_connections=50
)

bedrock_client = boto3.client('bedrock-runtime', config=bedrock_config)

# Emotion classification prompt template
EMOTION_CLASSIFICATION_PROMPT = """
Human: Analyze the following conversation message and classify the user's emotional state.

Message: "{message}"
Context: "{context}"

Respond with a JSON object containing:
- primary_emotion: one of [anxiety, joy, sadness, anger, fear, shame, hope, peace]
- secondary_emotion: optional secondary emotion
- confidence: float between 0.0 and 1.0
- risk_flags: array of risk indicators
- crisis_indicators: array of crisis signals if any

JSON Response:
"""

def classify_emotion(message: str, context: str = "") -> dict:
    prompt = EMOTION_CLASSIFICATION_PROMPT.format(
        message=message, 
        context=context
    )
    
    response = bedrock_client.invoke_model(
        modelId="anthropic.claude-3-sonnet-20240229-v1:0",
        body=json.dumps({
            "anthropic_version": "bedrock-2023-05-31",
            "max_tokens": 1000,
            "messages": [{"role": "user", "content": prompt}]
        })
    )
    
    return json.loads(response['body'].read())
```

### Bedrock Guardrails Configuration
```python
# Guardrails configuration for content filtering
guardrails_config = {
    "guardrailIdentifier": "faith-chatbot-guardrails",
    "guardrailVersion": "1",
    "contentPolicyConfig": {
        "filtersConfig": [
            {
                "type": "SEXUAL",
                "inputStrength": "HIGH",
                "outputStrength": "HIGH"
            },
            {
                "type": "VIOLENCE",
                "inputStrength": "HIGH", 
                "outputStrength": "HIGH"
            },
            {
                "type": "HATE",
                "inputStrength": "HIGH",
                "outputStrength": "HIGH"
            },
            {
                "type": "INSULTS",
                "inputStrength": "MEDIUM",
                "outputStrength": "MEDIUM"
            }
        ]
    },
    "sensitiveInformationPolicyConfig": {
        "piiEntitiesConfig": [
            {"type": "EMAIL", "action": "BLOCK"},
            {"type": "PHONE", "action": "BLOCK"},
            {"type": "SSN", "action": "BLOCK"}
        ]
    }
}
```

## SQS and Lambda Patterns

### SQS Queue Configuration
```python
# Prayer request queue with dead letter queue
prayer_request_queue = {
    "QueueName": "faith-chatbot-prayer-requests",
    "Attributes": {
        "VisibilityTimeoutSeconds": "300",
        "MessageRetentionPeriod": "1209600",  # 14 days
        "RedrivePolicy": json.dumps({
            "deadLetterTargetArn": "arn:aws:sqs:region:account:prayer-requests-dlq",
            "maxReceiveCount": 3
        })
    }
}

# Dead letter queue
dlq = {
    "QueueName": "faith-chatbot-prayer-requests-dlq",
    "Attributes": {
        "MessageRetentionPeriod": "1209600"  # 14 days
    }
}
```

### Lambda Function for Prayer Processing
```python
import json
import boto3
import requests
from typing import Dict, Any

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """Process prayer requests from SQS queue"""
    
    telegram_client = TelegramClient()
    ses_client = boto3.client('ses')
    
    for record in event['Records']:
        try:
            prayer_request = json.loads(record['body'])
            
            # Send to Telegram
            telegram_message = format_telegram_message(prayer_request)
            telegram_client.send_message(telegram_message)
            
            # Send confirmation email
            send_confirmation_email(ses_client, prayer_request)
            
            # Update request status
            update_prayer_request_status(prayer_request['request_id'], 'sent')
            
        except Exception as e:
            logger.error(f"Failed to process prayer request: {e}")
            # Message will be retried or sent to DLQ
            raise
    
    return {"statusCode": 200, "body": "Processed successfully"}
```

## Security Patterns

### IAM Role for ECS Task
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "bedrock:InvokeModel",
        "bedrock:InvokeModelWithResponseStream"
      ],
      "Resource": [
        "arn:aws:bedrock:*::foundation-model/anthropic.claude-3-sonnet-20240229-v1:0"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
        "dynamodb:Query"
      ],
      "Resource": [
        "arn:aws:dynamodb:region:account:table/FaithChatbot-*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "sqs:SendMessage"
      ],
      "Resource": [
        "arn:aws:sqs:region:account:faith-chatbot-prayer-requests"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": [
        "arn:aws:logs:region:account:log-group:/ecs/faith-chatbot:*"
      ]
    }
  ]
}
```

### Security Group Configuration
```python
# ALB Security Group
alb_security_group = {
    "GroupDescription": "Security group for Faith Chatbot ALB",
    "SecurityGroupIngress": [
        {
            "IpProtocol": "tcp",
            "FromPort": 443,
            "ToPort": 443,
            "CidrIp": "0.0.0.0/0"  # HTTPS from anywhere
        }
    ],
    "SecurityGroupEgress": [
        {
            "IpProtocol": "tcp",
            "FromPort": 8000,
            "ToPort": 8000,
            "SourceSecurityGroupId": "sg-ecs-tasks"  # Only to ECS tasks
        }
    ]
}

# ECS Tasks Security Group
ecs_security_group = {
    "GroupDescription": "Security group for Faith Chatbot ECS tasks",
    "SecurityGroupIngress": [
        {
            "IpProtocol": "tcp",
            "FromPort": 8000,
            "ToPort": 8000,
            "SourceSecurityGroupId": "sg-alb"  # Only from ALB
        }
    ],
    "SecurityGroupEgress": [
        {
            "IpProtocol": "tcp",
            "FromPort": 443,
            "ToPort": 443,
            "DestinationPrefixListId": "pl-id"  # AWS services via VPC endpoints
        }
    ]
}
```

## Monitoring and Logging Patterns

### CloudWatch Alarms
```python
# High error rate alarm
error_rate_alarm = {
    "AlarmName": "FaithChatbot-HighErrorRate",
    "AlarmDescription": "High error rate in API responses",
    "MetricName": "HTTPCode_Target_5XX_Count",
    "Namespace": "AWS/ApplicationELB",
    "Statistic": "Sum",
    "Period": 300,
    "EvaluationPeriods": 2,
    "Threshold": 10,
    "ComparisonOperator": "GreaterThanThreshold",
    "AlarmActions": ["arn:aws:sns:region:account:alerts-topic"]
}

# High response time alarm
latency_alarm = {
    "AlarmName": "FaithChatbot-HighLatency",
    "AlarmDescription": "High response latency",
    "MetricName": "TargetResponseTime",
    "Namespace": "AWS/ApplicationELB",
    "Statistic": "Average",
    "Period": 300,
    "EvaluationPeriods": 2,
    "Threshold": 3.0,
    "ComparisonOperator": "GreaterThanThreshold"
}
```

### Structured Logging
```python
import structlog
import uuid

# Configure structured logging
structlog.configure(
    processors=[
        structlog.stdlib.filter_by_level,
        structlog.stdlib.add_logger_name,
        structlog.stdlib.add_log_level,
        structlog.stdlib.PositionalArgumentsFormatter(),
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.StackInfoRenderer(),
        structlog.processors.format_exc_info,
        structlog.processors.UnicodeDecoder(),
        structlog.processors.JSONRenderer()
    ],
    context_class=dict,
    logger_factory=structlog.stdlib.LoggerFactory(),
    wrapper_class=structlog.stdlib.BoundLogger,
    cache_logger_on_first_use=True,
)

logger = structlog.get_logger()

# Usage in application
def process_chat_message(user_id: str, message: str):
    correlation_id = str(uuid.uuid4())
    
    logger.info(
        "Processing chat message",
        correlation_id=correlation_id,
        user_id=user_id,
        message_length=len(message)
    )
    
    try:
        # Process message
        result = classify_emotion(message)
        
        logger.info(
            "Emotion classification completed",
            correlation_id=correlation_id,
            primary_emotion=result.get('primary_emotion'),
            confidence=result.get('confidence')
        )
        
        return result
        
    except Exception as e:
        logger.error(
            "Failed to process chat message",
            correlation_id=correlation_id,
            error=str(e),
            exc_info=True
        )
        raise
```

These patterns provide a solid foundation for implementing the faith-based chatbot with AWS best practices for security, scalability, and observability.