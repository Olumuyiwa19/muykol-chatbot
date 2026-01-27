---
inclusion: fileMatch
fileMatchPattern: "**/*.{py,ts,js,yaml,yml,json,tf}"
---

# AWS Architecture Patterns for Faith Chatbot

## Terraform State Management

### Terraform Cloud Configuration
```hcl
# main.tf
terraform {
  required_version = ">= 1.0"
  
  cloud {
    organization = "muykol-chatbot"
    
    workspaces {
      tags = ["muykol-chatbot", "aws"]
    }
  }
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# AWS Provider with default tags
provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project     = "muykol-chatbot"
      Environment = var.environment
      ManagedBy   = "terraform-cloud"
    }
  }
}
```

### Workspace Management
- **muykol-chatbot-dev**: Development environment
- **muykol-chatbot-staging**: Staging environment  
- **muykol-chatbot-prod**: Production environment

Each workspace manages its own state with:
- Remote execution in Terraform Cloud
- Encrypted state storage
- Team access controls
- Audit logging

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
```

## CI/CD Pipeline Patterns

### Feature Branch Validation Architecture
```yaml
# Infrastructure CI - Feature Branch Validation
name: Infrastructure CI - Validation
on:
  pull_request:
    branches: [main, develop]
    paths: ['infrastructure/**']

permissions:
  id-token: write
  contents: read
  pull-requests: write
  security-events: write

jobs:
  terraform-validate:
    - terraform fmt -check -recursive
    - terraform init -backend=false
    - terraform validate
  
  security-scan:
    - Checkov security scan with SARIF output
    - Upload results to GitHub Security tab
    - Comment PR with security findings
  
  terraform-plan:
    - terraform plan (no apply)
    - Generate plan summary for PR comment
    - Validate infrastructure changes

# Application CI - Feature Branch Validation
name: Application CI - Validation
on:
  pull_request:
    branches: [main, develop]
    paths: ['app/**', 'tests/**', 'requirements*.txt', 'Dockerfile']

jobs:
  code-quality:
    - black --check (code formatting)
    - isort --check-only (import sorting)
    - flake8 (linting)
    - mypy (type checking)
    - CodeQL security analysis
    - bandit (security scanning)
    - safety check (dependency vulnerabilities)
  
  unit-tests:
    - pytest with coverage (>80% required)
    - Upload coverage to Codecov
  
  integration-tests:
    - pytest with LocalStack services
    - Service interaction validation
  
  docker-build:
    - Docker build with Buildx
    - Trivy vulnerability scanning
    - SARIF upload to GitHub Security
```

### Main Branch Deployment Architecture
```yaml
# Infrastructure CD - Main Branch Deployment
name: Infrastructure CD - Deployment
on:
  push:
    branches: [main]
    paths: ['infrastructure/**']

jobs:
  deploy-infrastructure:
    environment: production
    steps:
      - terraform init
      - terraform plan -var-file="environments/prod.tfvars"
      - terraform apply (if changes detected)
      - State backup to S3
      - Drift detection validation
      - Failure notification via GitHub Issues

# Application CD - Main Branch Deployment
name: Application CD - Deployment
on:
  push:
    branches: [main]
    paths: ['app/**', 'tests/**', 'requirements*.txt', 'Dockerfile']

jobs:
  build-and-push:
    - Docker build and push to ECR
    - Final Trivy security scan
    - Image metadata extraction
  
  deploy-staging:
    environment: staging
    - ECS service update
    - Health check validation
    - Smoke tests execution
  
  deploy-production:
    environment: production
    - ECS service deployment (rolling/blue-green/canary)
    - Comprehensive health validation
    - Performance baseline checks
    - Rollback capability

# Coordinated Pipeline - Change Detection and Orchestration
name: Coordinated CI/CD Pipeline
on:
  push:
    branches: [main]

jobs:
  detect-changes:
    - Use dorny/paths-filter to detect infrastructure vs application changes
  
  deploy-infrastructure:
    needs: detect-changes
    if: infrastructure changes detected
    uses: ./.github/workflows/infrastructure-cd.yml
  
  deploy-application:
    needs: [detect-changes, deploy-infrastructure]
    if: application changes detected
    uses: ./.github/workflows/application-cd.yml
  
  post-deployment-validation:
    needs: [deploy-infrastructure, deploy-application]
    - End-to-end system testing
    - Performance regression detection
    - Infrastructure drift validation
    - Comprehensive health reporting
```

### Security Scanning Integration
```yaml
# Checkov Infrastructure Security Scanning
- name: Run Checkov Security Scan
  uses: bridgecrewio/checkov-action@master
  with:
    directory: infrastructure/
    framework: terraform
    output_format: sarif
    output_file_path: checkov-results.sarif
    download_external_modules: true
    soft_fail: false
    skip_check: CKV_AWS_79,CKV_AWS_61  # Skip specific checks if needed

# CodeQL Application Security Analysis
- name: Initialize CodeQL
  uses: github/codeql-action/init@v3
  with:
    languages: python
    queries: security-and-quality

- name: Perform CodeQL Analysis
  uses: github/codeql-action/analyze@v3
  with:
    category: "/language:python"

# Trivy Container Security Scanning
- name: Run Trivy vulnerability scanner
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: 'faith-chatbot:${{ github.sha }}'
    format: 'sarif'
    output: 'trivy-results.sarif'
    exit-code: '1'
    severity: 'CRITICAL,HIGH'
```

### OIDC Authentication Configuration
```hcl
# GitHub Actions OIDC Provider
resource "aws_iam_openid_connect_provider" "github_actions" {
  url = "https://token.actions.githubusercontent.com"
  
  client_id_list = ["sts.amazonaws.com"]
  
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd"
  ]
}

# Infrastructure Role with Repository-Specific Trust Policy
resource "aws_iam_role" "github_actions_infrastructure" {
  name = "GitHubActions-Infrastructure-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github_actions.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:YOUR_ORG/faith-motivator-chatbot:*"
          }
        }
      }
    ]
  })
}

# Application Deployment Role with Branch-Specific Trust Policy
resource "aws_iam_role" "github_actions_deployment" {
  name = "GitHubActions-Deployment-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github_actions.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:YOUR_ORG/faith-motivator-chatbot:ref:refs/heads/main"
          }
        }
      }
    ]
  })
}
```
```hcl
# OIDC Identity Provider for GitHub Actions
resource "aws_iam_openid_connect_provider" "github_actions" {
  url = "https://token.actions.githubusercontent.com"
  
  client_id_list = [
    "sts.amazonaws.com"
  ]
  
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd"
  ]

  tags = {
    Name = "github-actions-oidc"
  }
}

# IAM Role for GitHub Actions (Infrastructure)
resource "aws_iam_role" "github_actions_infrastructure" {
  name = "GitHubActions-Infrastructure-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github_actions.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:YOUR_ORG/faith-motivator-chatbot:*"
          }
        }
      }
    ]
  })

  tags = {
    Name = "github-actions-infrastructure-role"
  }
}

# IAM Role for GitHub Actions (Application Deployment)
resource "aws_iam_role" "github_actions_deployment" {
  name = "GitHubActions-Deployment-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github_actions.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:YOUR_ORG/faith-motivator-chatbot:ref:refs/heads/main"
          }
        }
      }
    ]
  })

  tags = {
    Name = "github-actions-deployment-role"
  }
}

# Infrastructure Management Policy
resource "aws_iam_role_policy" "github_actions_infrastructure_policy" {
  name = "GitHubActions-Infrastructure-Policy"
  role = aws_iam_role.github_actions_infrastructure.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
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
          "sts:GetCallerIdentity"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          "${aws_s3_bucket.terraform_state.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.terraform_state.arn
        ]
      }
    ]
  })
}

# Application Deployment Policy
resource "aws_iam_role_policy" "github_actions_deployment_policy" {
  name = "GitHubActions-Deployment-Policy"
  role = aws_iam_role.github_actions_deployment.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecs:UpdateService",
          "ecs:DescribeServices",
          "ecs:DescribeTaskDefinition",
          "ecs:RegisterTaskDefinition"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = [
          "arn:aws:iam::*:role/faithChatbotTaskRole",
          "arn:aws:iam::*:role/ecsTaskExecutionRole"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject"
        ]
        Resource = [
          "arn:aws:s3:::faith-chatbot-frontend-assets/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "cloudfront:CreateInvalidation"
        ]
        Resource = "*"
      }
    ]
  })
}
```

## VPC and Networking Patterns

### Private Subnet Architecture
```hcl
# Use this pattern for ECS Fargate tasks
resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.main.id
  availability_zone = data.aws_availability_zones.available.names[0]
  cidr_block        = "172.20.3.0/24"
  
  map_public_ip_on_launch = false

  tags = {
    Name = "private-subnet"
  }
}
```

### VPC Endpoints for AWS Services
Always use VPC endpoints to avoid NAT Gateway costs and improve security:
```hcl
# Required VPC endpoints for this project
variable "vpc_endpoints" {
  description = "List of VPC endpoints to create"
  type        = list(string)
  default = [
    "com.amazonaws.region.bedrock-runtime",
    "com.amazonaws.region.dynamodb",
    "com.amazonaws.region.sqs",
    "com.amazonaws.region.ses",
    "com.amazonaws.region.logs",
    "com.amazonaws.region.ecr.dkr",
    "com.amazonaws.region.ecr.api"
  ]
}
```

## ECS Fargate Best Practices

### Task Definition Security
```hcl
resource "aws_ecs_task_definition" "faith_chatbot_api" {
  family                   = "faith-chatbot-api"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn           = aws_iam_role.faith_chatbot_task_role.arn

  container_definitions = jsonencode([
    {
      name  = "api"
      image = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com/faith-chatbot:latest"
      
      portMappings = [
        {
          containerPort = 8000
          protocol      = "tcp"
        }
      ]
      
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/faith-chatbot"
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "ecs"
        }
      }
      
      environment = [
        {
          name  = "AWS_DEFAULT_REGION"
          value = data.aws_region.current.name
        },
        {
          name  = "ENVIRONMENT"
          value = "production"
        }
      ]
      
      secrets = [
        {
          name      = "TELEGRAM_BOT_TOKEN"
          valueFrom = aws_secretsmanager_secret.telegram_bot_token.arn
        }
      ]
    }
  ])
}
```

### Auto Scaling Configuration
```hcl
# ECS Service Auto Scaling Target
resource "aws_appautoscaling_target" "ecs_target" {
  service_namespace  = "ecs"
  resource_id        = "service/${aws_ecs_cluster.faith_chatbot.name}/${aws_ecs_service.faith_chatbot.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  min_capacity       = 2
  max_capacity       = 10
}

# CPU-based scaling policy
resource "aws_appautoscaling_policy" "cpu_scaling" {
  name               = "CPUScalingPolicy"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value = 70.0
    
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    
    scale_out_cooldown = 300
    scale_in_cooldown  = 300
  }
}
```

## DynamoDB Design Patterns

### Table Design for Chat Application
```hcl
# UserProfile Table
resource "aws_dynamodb_table" "user_profiles" {
  name           = "FaithChatbot-UserProfiles"
  billing_mode   = "ON_DEMAND"
  hash_key       = "user_id"

  attribute {
    name = "user_id"
    type = "S"
  }

  attribute {
    name = "email"
    type = "S"
  }

  global_secondary_index {
    name     = "EmailIndex"
    hash_key = "email"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Name = "faith-chatbot-user-profiles"
  }
}

# ConversationSession Table with TTL
resource "aws_dynamodb_table" "conversations" {
  name           = "FaithChatbot-Conversations"
  billing_mode   = "ON_DEMAND"
  hash_key       = "session_id"

  attribute {
    name = "session_id"
    type = "S"
  }

  attribute {
    name = "user_id"
    type = "S"
  }

  global_secondary_index {
    name     = "UserIndex"
    hash_key = "user_id"
    projection_type = "ALL"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  tags = {
    Name = "faith-chatbot-conversations"
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
```hcl
# Prayer request queue with dead letter queue
resource "aws_sqs_queue" "prayer_requests" {
  name                       = "faith-chatbot-prayer-requests"
  visibility_timeout_seconds = 300
  message_retention_seconds  = 1209600  # 14 days
  
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.prayer_requests_dlq.arn
    maxReceiveCount     = 3
  })

  tags = {
    Name = "faith-chatbot-prayer-requests"
  }
}

# Dead letter queue
resource "aws_sqs_queue" "prayer_requests_dlq" {
  name                      = "faith-chatbot-prayer-requests-dlq"
  message_retention_seconds = 1209600  # 14 days

  tags = {
    Name = "faith-chatbot-prayer-requests-dlq"
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
```hcl
# ALB Security Group
resource "aws_security_group" "alb" {
  name_prefix = "faith-chatbot-alb-"
  description = "Security group for Faith Chatbot ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # HTTPS from anywhere
    description = "HTTPS from internet"
  }

  egress {
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_tasks.id]  # Only to ECS tasks
    description     = "To ECS tasks only"
  }

  tags = {
    Name = "faith-chatbot-alb-sg"
  }
}

# ECS Tasks Security Group
resource "aws_security_group" "ecs_tasks" {
  name_prefix = "faith-chatbot-ecs-"
  description = "Security group for Faith Chatbot ECS tasks"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]  # Only from ALB
    description     = "From ALB only"
  }

  egress {
    from_port              = 443
    to_port                = 443
    protocol               = "tcp"
    prefix_list_ids        = [data.aws_prefix_list.s3.id]  # AWS services via VPC endpoints
    description            = "To AWS services via VPC endpoints"
  }

  tags = {
    Name = "faith-chatbot-ecs-sg"
  }
}
```

## Monitoring and Logging Patterns

### CloudWatch Alarms
```hcl
# High error rate alarm
resource "aws_cloudwatch_metric_alarm" "high_error_rate" {
  alarm_name          = "FaithChatbot-HighErrorRate"
  alarm_description   = "High error rate in API responses"
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 2
  threshold           = 10
  comparison_operator = "GreaterThanThreshold"
  
  dimensions = {
    LoadBalancer = aws_lb.faith_chatbot.arn_suffix
  }
  
  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = {
    Name = "faith-chatbot-high-error-rate"
  }
}

# High response time alarm
resource "aws_cloudwatch_metric_alarm" "high_latency" {
  alarm_name          = "FaithChatbot-HighLatency"
  alarm_description   = "High response latency"
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = 3.0
  comparison_operator = "GreaterThanThreshold"
  
  dimensions = {
    LoadBalancer = aws_lb.faith_chatbot.arn_suffix
  }

  tags = {
    Name = "faith-chatbot-high-latency"
  }
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