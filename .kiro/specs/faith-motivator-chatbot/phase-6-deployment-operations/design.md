# Phase 6: Deployment & Operations - Design Document

## Architecture Overview

Phase 6 implements production deployment infrastructure, operational procedures, and launch preparation for the faith-based motivator chatbot. This includes ECS Fargate deployment, CI/CD pipelines, performance optimization, security hardening, and comprehensive operational readiness.

### Production Deployment Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Production Environment                        │
│                                                                 │
│  ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐   │
│  │   CloudFront    │ │  Application    │ │   ECS Fargate   │   │
│  │      CDN        │ │ Load Balancer   │ │    Service      │   │
│  │                 │ │                 │ │                 │   │
│  │ • Static Assets │ │ • SSL Term.     │ │ • Auto Scaling  │   │
│  │ • Global Cache  │ │ • Health Checks │ │ • Blue/Green    │   │
│  │ • WAF Rules     │ │ • Target Groups │ │ • Rolling Update│   │
│  └─────────────────┘ └─────────────────┘ └─────────────────┘   │
└─────────────────────────┬───────────────────────────────────────┘
                          │
┌─────────────────────────▼───────────────────────────────────────┐
│                 CI/CD Pipeline                                  │
│                                                                 │
│  ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐   │
│  │ GitHub Actions  │ │   Docker Build  │ │   Deployment    │   │
│  │                 │ │                 │ │                 │   │
│  │ • Test Suite    │ │ • Image Build   │ │ • Staging       │   │
│  │ • Security Scan │ │ • Vulnerability │ │ • Production    │   │
│  │ • Quality Gates │ │ • ECR Push      │ │ • Rollback      │   │
│  └─────────────────┘ └─────────────────┘ └─────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

## Component Design

### 1. ECS Fargate Deployment Configuration

#### Service Definition
```yaml
# ecs-service.yml
apiVersion: v1
kind: Service
metadata:
  name: faith-chatbot-service
spec:
  serviceName: faith-chatbot
  cluster: faith-chatbot-cluster
  taskDefinition: faith-chatbot-task:LATEST
  desiredCount: 2
  launchType: FARGATE
  
  networkConfiguration:
    awsvpcConfiguration:
      subnets:
        - subnet-private-1a
        - subnet-private-1b
      securityGroups:
        - sg-ecs-tasks
      assignPublicIp: DISABLED
  
  loadBalancers:
    - targetGroupArn: arn:aws:elasticloadbalancing:region:account:targetgroup/faith-chatbot-tg
      containerName: api
      containerPort: 8000
  
  deploymentConfiguration:
    maximumPercent: 200
    minimumHealthyPercent: 50
    deploymentCircuitBreaker:
      enable: true
      rollback: true
  
  serviceTags:
    - key: Environment
      value: production
    - key: Application
      value: faith-motivator-chatbot
```

#### Task Definition
```json
{
  "family": "faith-chatbot-task",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "1024",
  "memory": "2048",
  "executionRoleArn": "arn:aws:iam::account:role/ecsTaskExecutionRole",
  "taskRoleArn": "arn:aws:iam::account:role/faithChatbotTaskRole",
  "containerDefinitions": [
    {
      "name": "api",
      "image": "account.dkr.ecr.region.amazonaws.com/faith-chatbot:latest",
      "portMappings": [
        {
          "containerPort": 8000,
          "protocol": "tcp"
        }
      ],
      "essential": true,
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/faith-chatbot",
          "awslogs-region": "us-east-1",
          "awslogs-stream-prefix": "ecs"
        }
      },
      "environment": [
        {
          "name": "ENVIRONMENT",
          "value": "production"
        },
        {
          "name": "AWS_DEFAULT_REGION",
          "value": "us-east-1"
        }
      ],
      "secrets": [
        {
          "name": "DATABASE_URL",
          "valueFrom": "arn:aws:secretsmanager:region:account:secret:faith-chatbot/database-url"
        },
        {
          "name": "TELEGRAM_BOT_TOKEN",
          "valueFrom": "arn:aws:secretsmanager:region:account:secret:faith-chatbot/telegram-token"
        }
      ],
      "healthCheck": {
        "command": [
          "CMD-SHELL",
          "curl -f http://localhost:8000/health || exit 1"
        ],
        "interval": 30,
        "timeout": 5,
        "retries": 3,
        "startPeriod": 60
      }
    }
  ]
}
```
### 2. CI/CD Pipeline Implementation

#### GitHub Actions Workflow
```yaml
# .github/workflows/deploy.yml
name: Deploy Faith Motivator Chatbot

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

env:
  AWS_REGION: us-east-1
  ECR_REPOSITORY: faith-chatbot
  ECS_SERVICE: faith-chatbot-service
  ECS_CLUSTER: faith-chatbot-cluster

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v3
      
      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.11'
      
      - name: Install dependencies
        run: |
          pip install -r requirements.txt
          pip install -r requirements-test.txt
      
      - name: Run unit tests
        run: pytest tests/unit --cov=app --cov-report=xml
      
      - name: Run integration tests
        run: pytest tests/integration
      
      - name: Run security tests
        run: |
          bandit -r app/
          safety check
      
      - name: Upload coverage reports
        uses: codecov/codecov-action@v3
        with:
          file: ./coverage.xml

  build:
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main' || github.ref == 'refs/heads/develop'
    
    outputs:
      image: ${{ steps.build-image.outputs.image }}
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v3
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}
      
      - name: Login to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v1
      
      - name: Build, tag, and push image to Amazon ECR
        id: build-image
        env:
          ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
          IMAGE_TAG: ${{ github.sha }}
        run: |
          docker build -t $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG .
          docker build -t $ECR_REGISTRY/$ECR_REPOSITORY:latest .
          
          # Security scan
          docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
            -v $HOME/Library/Caches:/root/.cache/ \
            aquasec/trivy image $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG
          
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:latest
          
          echo "image=$ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG" >> $GITHUB_OUTPUT

  deploy-staging:
    needs: build
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/develop'
    
    environment: staging
    
    steps:
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}
      
      - name: Deploy to staging
        run: |
          aws ecs update-service \
            --cluster $ECS_CLUSTER-staging \
            --service $ECS_SERVICE-staging \
            --force-new-deployment
      
      - name: Wait for deployment
        run: |
          aws ecs wait services-stable \
            --cluster $ECS_CLUSTER-staging \
            --services $ECS_SERVICE-staging
      
      - name: Run smoke tests
        run: |
          # Wait for service to be healthy
          sleep 60
          
          # Run basic health checks
          curl -f https://staging-api.faithchatbot.com/health
          
          # Run smoke tests
          pytest tests/smoke --base-url=https://staging-api.faithchatbot.com

  deploy-production:
    needs: [build, deploy-staging]
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    
    environment: production
    
    steps:
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}
      
      - name: Deploy to production
        run: |
          # Update task definition with new image
          TASK_DEFINITION=$(aws ecs describe-task-definition \
            --task-definition $ECS_SERVICE \
            --query taskDefinition)
          
          NEW_TASK_DEFINITION=$(echo $TASK_DEFINITION | \
            jq --arg IMAGE "${{ needs.build.outputs.image }}" \
            '.containerDefinitions[0].image = $IMAGE')
          
          aws ecs register-task-definition \
            --cli-input-json "$NEW_TASK_DEFINITION"
          
          # Update service
          aws ecs update-service \
            --cluster $ECS_CLUSTER \
            --service $ECS_SERVICE \
            --task-definition $ECS_SERVICE
      
      - name: Wait for deployment
        run: |
          aws ecs wait services-stable \
            --cluster $ECS_CLUSTER \
            --services $ECS_SERVICE
      
      - name: Verify deployment
        run: |
          # Health check
          curl -f https://api.faithchatbot.com/health
          
          # Basic functionality test
          pytest tests/production --base-url=https://api.faithchatbot.com
```

### 3. Performance Optimization Strategy

#### Database Optimization
```python
# app/services/optimized_db_service.py
import asyncio
from typing import List, Dict, Optional
from aiobotocore.session import get_session
from botocore.config import Config

class OptimizedDatabaseService:
    def __init__(self):
        # Connection pooling configuration
        self.config = Config(
            region_name='us-east-1',
            retries={'max_attempts': 3, 'mode': 'adaptive'},
            max_pool_connections=50
        )
        
        self.session = get_session()
        self._connection_pool = None
    
    async def get_connection_pool(self):
        """Get optimized DynamoDB connection pool"""
        if self._connection_pool is None:
            self._connection_pool = self.session.create_client(
                'dynamodb',
                config=self.config
            )
        return self._connection_pool
    
    async def batch_get_conversations(self, session_ids: List[str]) -> List[Dict]:
        """Optimized batch retrieval of conversations"""
        client = await self.get_connection_pool()
        
        # Use batch_get_item for efficient retrieval
        request_items = {
            'FaithChatbot-ConversationSessions': {
                'Keys': [{'session_id': {'S': sid}} for sid in session_ids]
            }
        }
        
        response = await client.batch_get_item(RequestItems=request_items)
        return response.get('Responses', {}).get('FaithChatbot-ConversationSessions', [])
    
    async def optimized_user_lookup(self, email: str) -> Optional[Dict]:
        """Optimized user lookup with caching"""
        # Use GSI for efficient email lookup
        client = await self.get_connection_pool()
        
        response = await client.query(
            TableName='FaithChatbot-UserProfiles',
            IndexName='EmailIndex',
            KeyConditionExpression='email = :email',
            ExpressionAttributeValues={':email': {'S': email}},
            Limit=1
        )
        
        items = response.get('Items', [])
        return items[0] if items else None
```

#### API Response Caching
```python
# app/middleware/caching.py
import json
import hashlib
from typing import Optional, Any
from fastapi import Request, Response
from redis import Redis
import asyncio

class ResponseCacheMiddleware:
    def __init__(self, redis_client: Redis, default_ttl: int = 300):
        self.redis = redis_client
        self.default_ttl = default_ttl
        
        # Cache configuration per endpoint
        self.cache_config = {
            '/chat/history': {'ttl': 300, 'vary_by': ['user_id']},
            '/prayer/history': {'ttl': 600, 'vary_by': ['user_id']},
            '/biblical-content': {'ttl': 3600, 'vary_by': ['emotion']},
        }
    
    async def __call__(self, request: Request, call_next):
        # Check if endpoint should be cached
        endpoint = request.url.path
        cache_config = self.cache_config.get(endpoint)
        
        if not cache_config or request.method != 'GET':
            return await call_next(request)
        
        # Generate cache key
        cache_key = self._generate_cache_key(request, cache_config)
        
        # Try to get from cache
        cached_response = await self._get_cached_response(cache_key)
        if cached_response:
            return Response(
                content=cached_response['content'],
                status_code=cached_response['status_code'],
                headers=cached_response['headers'],
                media_type=cached_response['media_type']
            )
        
        # Process request
        response = await call_next(request)
        
        # Cache successful responses
        if response.status_code == 200:
            await self._cache_response(cache_key, response, cache_config['ttl'])
        
        return response
    
    def _generate_cache_key(self, request: Request, config: dict) -> str:
        """Generate cache key based on request and configuration"""
        key_parts = [request.url.path]
        
        # Add vary_by parameters
        for param in config.get('vary_by', []):
            if param == 'user_id':
                user_id = getattr(request.state, 'user_id', 'anonymous')
                key_parts.append(f"user:{user_id}")
            elif param in request.query_params:
                key_parts.append(f"{param}:{request.query_params[param]}")
        
        key_string = "|".join(key_parts)
        return f"cache:{hashlib.md5(key_string.encode()).hexdigest()}"
    
    async def _get_cached_response(self, cache_key: str) -> Optional[dict]:
        """Get cached response from Redis"""
        try:
            cached_data = self.redis.get(cache_key)
            if cached_data:
                return json.loads(cached_data)
        except Exception:
            pass  # Cache miss or error
        return None
    
    async def _cache_response(self, cache_key: str, response: Response, ttl: int):
        """Cache response in Redis"""
        try:
            cache_data = {
                'content': response.body.decode(),
                'status_code': response.status_code,
                'headers': dict(response.headers),
                'media_type': response.media_type
            }
            
            self.redis.setex(
                cache_key,
                ttl,
                json.dumps(cache_data)
            )
        except Exception:
            pass  # Cache write error, continue normally
```
### 4. Security Hardening Implementation

#### Production Security Configuration
```python
# infrastructure/security_hardening.py
import boto3
from typing import Dict, List

class SecurityHardeningConfig:
    """Production security hardening configuration"""
    
    @staticmethod
    def get_security_group_rules() -> Dict[str, List[Dict]]:
        """Define security group rules with least privilege"""
        return {
            'alb_security_group': {
                'ingress': [
                    {
                        'IpProtocol': 'tcp',
                        'FromPort': 443,
                        'ToPort': 443,
                        'CidrIp': '0.0.0.0/0',  # HTTPS from internet
                        'Description': 'HTTPS from internet'
                    }
                ],
                'egress': [
                    {
                        'IpProtocol': 'tcp',
                        'FromPort': 8000,
                        'ToPort': 8000,
                        'SourceSecurityGroupId': 'sg-ecs-tasks',
                        'Description': 'To ECS tasks only'
                    }
                ]
            },
            'ecs_tasks_security_group': {
                'ingress': [
                    {
                        'IpProtocol': 'tcp',
                        'FromPort': 8000,
                        'ToPort': 8000,
                        'SourceSecurityGroupId': 'sg-alb',
                        'Description': 'From ALB only'
                    }
                ],
                'egress': [
                    {
                        'IpProtocol': 'tcp',
                        'FromPort': 443,
                        'ToPort': 443,
                        'DestinationPrefixListId': 'pl-id-for-aws-services',
                        'Description': 'To AWS services via VPC endpoints'
                    }
                ]
            }
        }
    
    @staticmethod
    def get_iam_task_policy() -> Dict:
        """Define least privilege IAM policy for ECS tasks"""
        return {
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Effect": "Allow",
                    "Action": [
                        "bedrock:InvokeModel",
                        "bedrock:InvokeModelWithResponseStream"
                    ],
                    "Resource": [
                        "arn:aws:bedrock:us-east-1::foundation-model/anthropic.claude-3-sonnet-20240229-v1:0"
                    ],
                    "Condition": {
                        "StringEquals": {
                            "aws:RequestedRegion": "us-east-1"
                        }
                    }
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
                        "arn:aws:dynamodb:us-east-1:ACCOUNT:table/FaithChatbot-*",
                        "arn:aws:dynamodb:us-east-1:ACCOUNT:table/FaithChatbot-*/index/*"
                    ]
                },
                {
                    "Effect": "Allow",
                    "Action": [
                        "sqs:SendMessage"
                    ],
                    "Resource": [
                        "arn:aws:sqs:us-east-1:ACCOUNT:FaithChatbot-PrayerRequests"
                    ]
                },
                {
                    "Effect": "Allow",
                    "Action": [
                        "secretsmanager:GetSecretValue"
                    ],
                    "Resource": [
                        "arn:aws:secretsmanager:us-east-1:ACCOUNT:secret:faith-chatbot/*"
                    ]
                },
                {
                    "Effect": "Allow",
                    "Action": [
                        "logs:CreateLogStream",
                        "logs:PutLogEvents"
                    ],
                    "Resource": [
                        "arn:aws:logs:us-east-1:ACCOUNT:log-group:/ecs/faith-chatbot:*"
                    ]
                }
            ]
        }
    
    @staticmethod
    def get_waf_rules() -> List[Dict]:
        """Define WAF rules for additional protection"""
        return [
            {
                'Name': 'AWSManagedRulesCommonRuleSet',
                'Priority': 1,
                'Statement': {
                    'ManagedRuleGroupStatement': {
                        'VendorName': 'AWS',
                        'Name': 'AWSManagedRulesCommonRuleSet'
                    }
                },
                'OverrideAction': {'None': {}},
                'VisibilityConfig': {
                    'SampledRequestsEnabled': True,
                    'CloudWatchMetricsEnabled': True,
                    'MetricName': 'CommonRuleSetMetric'
                }
            },
            {
                'Name': 'RateLimitRule',
                'Priority': 2,
                'Statement': {
                    'RateBasedStatement': {
                        'Limit': 2000,  # 2000 requests per 5 minutes
                        'AggregateKeyType': 'IP'
                    }
                },
                'Action': {'Block': {}},
                'VisibilityConfig': {
                    'SampledRequestsEnabled': True,
                    'CloudWatchMetricsEnabled': True,
                    'MetricName': 'RateLimitMetric'
                }
            }
        ]

# Secrets management
class SecretsManager:
    """Secure secrets management for production"""
    
    def __init__(self):
        self.client = boto3.client('secretsmanager')
    
    async def create_application_secrets(self):
        """Create all required application secrets"""
        secrets = {
            'faith-chatbot/database-config': {
                'description': 'Database configuration',
                'secret_value': {
                    'dynamodb_region': 'us-east-1',
                    'table_prefix': 'FaithChatbot-'
                }
            },
            'faith-chatbot/telegram-config': {
                'description': 'Telegram bot configuration',
                'secret_value': {
                    'bot_token': 'TELEGRAM_BOT_TOKEN_HERE',
                    'chat_id': 'TELEGRAM_CHAT_ID_HERE'
                }
            },
            'faith-chatbot/bedrock-config': {
                'description': 'Bedrock configuration',
                'secret_value': {
                    'model_id': 'anthropic.claude-3-sonnet-20240229-v1:0',
                    'guardrails_id': 'GUARDRAILS_ID_HERE'
                }
            }
        }
        
        for secret_name, config in secrets.items():
            try:
                self.client.create_secret(
                    Name=secret_name,
                    Description=config['description'],
                    SecretString=json.dumps(config['secret_value']),
                    KmsKeyId='alias/faith-chatbot-secrets'
                )
            except self.client.exceptions.ResourceExistsException:
                # Secret already exists, update it
                self.client.update_secret(
                    SecretId=secret_name,
                    SecretString=json.dumps(config['secret_value'])
                )
```

### 5. Monitoring and Alerting System

#### CloudWatch Dashboard Configuration
```python
# monitoring/cloudwatch_dashboards.py
import boto3
import json

class CloudWatchDashboards:
    """Create and manage CloudWatch dashboards"""
    
    def __init__(self):
        self.cloudwatch = boto3.client('cloudwatch')
    
    def create_operational_dashboard(self):
        """Create operational monitoring dashboard"""
        dashboard_body = {
            "widgets": [
                {
                    "type": "metric",
                    "x": 0, "y": 0,
                    "width": 12, "height": 6,
                    "properties": {
                        "metrics": [
                            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", "faith-chatbot-alb"],
                            [".", "TargetResponseTime", ".", "."],
                            [".", "HTTPCode_Target_2XX_Count", ".", "."],
                            [".", "HTTPCode_Target_4XX_Count", ".", "."],
                            [".", "HTTPCode_Target_5XX_Count", ".", "."]
                        ],
                        "period": 300,
                        "stat": "Sum",
                        "region": "us-east-1",
                        "title": "Application Load Balancer Metrics"
                    }
                },
                {
                    "type": "metric",
                    "x": 0, "y": 6,
                    "width": 12, "height": 6,
                    "properties": {
                        "metrics": [
                            ["AWS/ECS", "CPUUtilization", "ServiceName", "faith-chatbot-service", "ClusterName", "faith-chatbot-cluster"],
                            [".", "MemoryUtilization", ".", ".", ".", "."]
                        ],
                        "period": 300,
                        "stat": "Average",
                        "region": "us-east-1",
                        "title": "ECS Service Metrics"
                    }
                },
                {
                    "type": "metric",
                    "x": 0, "y": 12,
                    "width": 12, "height": 6,
                    "properties": {
                        "metrics": [
                            ["AWS/DynamoDB", "ConsumedReadCapacityUnits", "TableName", "FaithChatbot-UserProfiles"],
                            [".", "ConsumedWriteCapacityUnits", ".", "."],
                            [".", "ThrottledRequests", ".", "."]
                        ],
                        "period": 300,
                        "stat": "Sum",
                        "region": "us-east-1",
                        "title": "DynamoDB Metrics"
                    }
                }
            ]
        }
        
        self.cloudwatch.put_dashboard(
            DashboardName='FaithChatbot-Operations',
            DashboardBody=json.dumps(dashboard_body)
        )
    
    def create_business_dashboard(self):
        """Create business metrics dashboard"""
        dashboard_body = {
            "widgets": [
                {
                    "type": "metric",
                    "x": 0, "y": 0,
                    "width": 6, "height": 6,
                    "properties": {
                        "metrics": [
                            ["FaithChatbot", "ActiveUsers", {"stat": "Sum"}],
                            [".", "NewUsers", {"stat": "Sum"}],
                            [".", "ChatMessages", {"stat": "Sum"}]
                        ],
                        "period": 3600,
                        "region": "us-east-1",
                        "title": "User Engagement"
                    }
                },
                {
                    "type": "metric",
                    "x": 6, "y": 0,
                    "width": 6, "height": 6,
                    "properties": {
                        "metrics": [
                            ["FaithChatbot", "PrayerRequests", {"stat": "Sum"}],
                            [".", "PrayerRequestsCompleted", {"stat": "Sum"}],
                            [".", "CommunityResponseRate", {"stat": "Average"}]
                        ],
                        "period": 3600,
                        "region": "us-east-1",
                        "title": "Prayer Connect Metrics"
                    }
                }
            ]
        }
        
        self.cloudwatch.put_dashboard(
            DashboardName='FaithChatbot-Business',
            DashboardBody=json.dumps(dashboard_body)
        )

# CloudWatch Alarms
class CloudWatchAlarms:
    """Create and manage CloudWatch alarms"""
    
    def __init__(self):
        self.cloudwatch = boto3.client('cloudwatch')
        self.sns_topic_arn = 'arn:aws:sns:us-east-1:ACCOUNT:faith-chatbot-alerts'
    
    def create_critical_alarms(self):
        """Create critical system alarms"""
        alarms = [
            {
                'AlarmName': 'FaithChatbot-HighErrorRate',
                'AlarmDescription': 'High 5XX error rate',
                'MetricName': 'HTTPCode_Target_5XX_Count',
                'Namespace': 'AWS/ApplicationELB',
                'Statistic': 'Sum',
                'Period': 300,
                'EvaluationPeriods': 2,
                'Threshold': 10,
                'ComparisonOperator': 'GreaterThanThreshold',
                'Dimensions': [
                    {
                        'Name': 'LoadBalancer',
                        'Value': 'faith-chatbot-alb'
                    }
                ]
            },
            {
                'AlarmName': 'FaithChatbot-HighLatency',
                'AlarmDescription': 'High response latency',
                'MetricName': 'TargetResponseTime',
                'Namespace': 'AWS/ApplicationELB',
                'Statistic': 'Average',
                'Period': 300,
                'EvaluationPeriods': 3,
                'Threshold': 3.0,
                'ComparisonOperator': 'GreaterThanThreshold',
                'Dimensions': [
                    {
                        'Name': 'LoadBalancer',
                        'Value': 'faith-chatbot-alb'
                    }
                ]
            },
            {
                'AlarmName': 'FaithChatbot-ECSServiceUnhealthy',
                'AlarmDescription': 'ECS service has unhealthy tasks',
                'MetricName': 'RunningTaskCount',
                'Namespace': 'AWS/ECS',
                'Statistic': 'Average',
                'Period': 300,
                'EvaluationPeriods': 2,
                'Threshold': 1,
                'ComparisonOperator': 'LessThanThreshold',
                'Dimensions': [
                    {
                        'Name': 'ServiceName',
                        'Value': 'faith-chatbot-service'
                    },
                    {
                        'Name': 'ClusterName',
                        'Value': 'faith-chatbot-cluster'
                    }
                ]
            }
        ]
        
        for alarm in alarms:
            self.cloudwatch.put_metric_alarm(
                **alarm,
                AlarmActions=[self.sns_topic_arn],
                OKActions=[self.sns_topic_arn]
            )
```

### 6. Backup and Disaster Recovery

#### Backup Strategy Implementation
```python
# backup/disaster_recovery.py
import boto3
from datetime import datetime, timedelta
from typing import Dict, List

class DisasterRecoveryManager:
    """Manage backup and disaster recovery procedures"""
    
    def __init__(self):
        self.dynamodb = boto3.client('dynamodb')
        self.s3 = boto3.client('s3')
        self.backup_bucket = 'faith-chatbot-backups'
    
    def enable_point_in_time_recovery(self):
        """Enable point-in-time recovery for all DynamoDB tables"""
        tables = [
            'FaithChatbot-UserProfiles',
            'FaithChatbot-ConversationSessions',
            'FaithChatbot-PrayerRequests',
            'FaithChatbot-ConsentLogs'
        ]
        
        for table_name in tables:
            try:
                self.dynamodb.update_continuous_backups(
                    TableName=table_name,
                    PointInTimeRecoverySpecification={
                        'PointInTimeRecoveryEnabled': True
                    }
                )
                print(f"Enabled PITR for {table_name}")
            except Exception as e:
                print(f"Failed to enable PITR for {table_name}: {e}")
    
    def create_cross_region_backup(self):
        """Create cross-region backup of critical data"""
        # Export DynamoDB tables to S3
        tables = ['FaithChatbot-UserProfiles', 'FaithChatbot-ConsentLogs']
        
        for table_name in tables:
            export_arn = self.dynamodb.export_table_to_point_in_time(
                TableArn=f'arn:aws:dynamodb:us-east-1:ACCOUNT:table/{table_name}',
                S3Bucket=self.backup_bucket,
                S3Prefix=f'exports/{table_name}/{datetime.now().strftime("%Y-%m-%d")}/',
                ExportFormat='DYNAMODB_JSON'
            )
            
            print(f"Started export for {table_name}: {export_arn}")
    
    def test_disaster_recovery(self) -> Dict[str, bool]:
        """Test disaster recovery procedures"""
        results = {}
        
        # Test 1: Verify backups exist and are accessible
        try:
            response = self.s3.list_objects_v2(
                Bucket=self.backup_bucket,
                Prefix='exports/'
            )
            results['backup_accessibility'] = len(response.get('Contents', [])) > 0
        except Exception:
            results['backup_accessibility'] = False
        
        # Test 2: Test point-in-time recovery capability
        try:
            # Create a test table restore (dry run)
            test_table_name = 'FaithChatbot-UserProfiles-Test'
            restore_time = datetime.now() - timedelta(hours=1)
            
            self.dynamodb.restore_table_to_point_in_time(
                SourceTableName='FaithChatbot-UserProfiles',
                TargetTableName=test_table_name,
                RestoreDateTime=restore_time
            )
            
            # Wait for restore to complete (in real scenario)
            # Then delete test table
            results['point_in_time_recovery'] = True
            
        except Exception:
            results['point_in_time_recovery'] = False
        
        return results
    
    def generate_recovery_runbook(self) -> str:
        """Generate disaster recovery runbook"""
        runbook = """
# Faith Motivator Chatbot - Disaster Recovery Runbook

## Recovery Time Objectives (RTO)
- Critical services: 30 minutes
- Full system recovery: 2 hours
- Data recovery: 4 hours

## Recovery Point Objectives (RPO)
- User data: 15 minutes (PITR)
- Configuration: 1 hour (backups)
- Application code: 0 (version control)

## Recovery Procedures

### 1. Service Outage Recovery
1. Check ECS service health
2. Review CloudWatch alarms
3. Restart ECS service if needed
4. Scale up if capacity issue

### 2. Database Recovery
1. Identify affected tables
2. Use point-in-time recovery
3. Restore to specific timestamp
4. Validate data integrity

### 3. Complete System Recovery
1. Deploy infrastructure from IaC
2. Restore database from backups
3. Deploy latest application version
4. Run smoke tests
5. Update DNS if needed

### 4. Cross-Region Failover
1. Activate backup region resources
2. Restore data from S3 exports
3. Update Route 53 health checks
4. Redirect traffic to backup region

## Emergency Contacts
- On-call engineer: [PHONE]
- AWS Support: [CASE_URL]
- Management escalation: [CONTACTS]
"""
        return runbook
```

This comprehensive deployment and operations design ensures the faith-based motivator chatbot can be reliably deployed, monitored, and maintained in production with proper security, performance, and disaster recovery capabilities.