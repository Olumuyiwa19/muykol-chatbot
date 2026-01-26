# Phase 1: Foundation & Infrastructure - Design Document

## Architecture Overview

Phase 1 establishes the foundational AWS infrastructure and core backend services that will support the entire faith-based motivator chatbot system. This phase focuses on security, scalability, and reliability from the ground up.

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        AWS Account                               │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                    VPC (10.0.0.0/16)                       │ │
│  │                                                             │ │
│  │  ┌─────────────────┐    ┌─────────────────┐                │ │
│  │  │  Public Subnet  │    │  Public Subnet  │                │ │
│  │  │   (10.0.1.0/24) │    │   (10.0.2.0/24) │                │ │
│  │  │      AZ-a       │    │      AZ-b       │                │ │
│  │  └─────────────────┘    └─────────────────┘                │ │
│  │                                                             │ │
│  │  ┌─────────────────┐    ┌─────────────────┐                │ │
│  │  │ Private Subnet  │    │ Private Subnet  │                │ │
│  │  │  (10.0.3.0/24)  │    │  (10.0.4.0/24)  │                │ │
│  │  │      AZ-a       │    │      AZ-b       │                │ │
│  │  │                 │    │                 │                │ │
│  │  │  ┌───────────┐  │    │  ┌───────────┐  │                │ │
│  │  │  │ECS Tasks  │  │    │  │ECS Tasks  │  │                │ │
│  │  │  │(Future)   │  │    │  │(Future)   │  │                │ │
│  │  │  └───────────┘  │    │  └───────────┘  │                │ │
│  │  └─────────────────┘    └─────────────────┘                │ │
│  │                                                             │ │
│  │  ┌─────────────────────────────────────────────────────────┐ │
│  │  │              VPC Endpoints                              │ │
│  │  │  • Bedrock Runtime  • DynamoDB  • SES                  │ │
│  │  │  • ECR (api/dkr)   • S3         • CloudWatch Logs     │ │
│  │  │  • Secrets Manager • STS        • KMS                 │ │
│  │  └─────────────────────────────────────────────────────────┘ │
│  └─────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   AWS Cognito   │    │   Amazon        │    │   Amazon SQS    │
│   User Pool     │    │   Bedrock       │    │   (Prayer       │
│                 │    │   (Claude/Titan)│    │   Requests)     │
└─────────────────┘    └─────────────────┘    └─────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                      DynamoDB Tables                            │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌───────────┐ │
│  │UserProfiles │ │Conversations│ │PrayerRequests│ │ConsentLogs│ │
│  └─────────────┘ └─────────────┘ └─────────────┘ └───────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## Component Design

### 1. AWS Infrastructure (CDK/Terraform)

#### VPC Configuration
```python
# VPC with multi-AZ setup
vpc_config = {
    "cidr_block": "10.0.0.0/16",
    "availability_zones": ["us-east-1a", "us-east-1b"],
    "public_subnets": ["10.0.1.0/24", "10.0.2.0/24"],
    "private_subnets": ["10.0.3.0/24", "10.0.4.0/24"],
    "enable_nat_gateway": False,  # Use VPC endpoints instead
    "enable_vpn_gateway": False
}
```

#### Security Groups
```python
# ECS Task Security Group (for future use)
ecs_security_group = {
    "name": "faith-chatbot-ecs-sg",
    "description": "Security group for ECS tasks",
    "ingress_rules": [
        {
            "from_port": 8000,
            "to_port": 8000,
            "protocol": "tcp",
            "source_security_group_id": "alb-sg"  # Only from ALB
        }
    ],
    "egress_rules": [
        {
            "from_port": 443,
            "to_port": 443,
            "protocol": "tcp",
            "cidr_blocks": ["0.0.0.0/0"]  # HTTPS to VPC endpoints
        }
    ]
}

# VPC Endpoint Security Group
vpc_endpoint_sg = {
    "name": "faith-chatbot-vpce-sg",
    "description": "Security group for VPC endpoints",
    "ingress_rules": [
        {
            "from_port": 443,
            "to_port": 443,
            "protocol": "tcp",
            "source_security_group_id": "ecs-sg"
        }
    ]
}
```

#### VPC Endpoints
```python
vpc_endpoints = [
    {
        "service": "com.amazonaws.us-east-1.bedrock-runtime",
        "type": "Interface",
        "policy": {
            "Version": "2012-10-17",
            "Statement": [{
                "Effect": "Allow",
                "Principal": "*",
                "Action": [
                    "bedrock:InvokeModel",
                    "bedrock:InvokeModelWithResponseStream"
                ],
                "Resource": "*",
                "Condition": {
                    "StringEquals": {
                        "aws:PrincipalArn": "arn:aws:iam::ACCOUNT:role/FaithChatbotTaskRole"
                    }
                }
            }]
        }
    },
    {
        "service": "com.amazonaws.us-east-1.dynamodb",
        "type": "Gateway",
        "policy": {
            "Version": "2012-10-17",
            "Statement": [{
                "Effect": "Allow",
                "Principal": "*",
                "Action": [
                    "dynamodb:GetItem",
                    "dynamodb:PutItem",
                    "dynamodb:UpdateItem",
                    "dynamodb:Query",
                    "dynamodb:Scan"
                ],
                "Resource": "arn:aws:dynamodb:us-east-1:ACCOUNT:table/FaithChatbot-*"
            }]
        }
    }
]
```

### 2. AWS Cognito Configuration

#### User Pool Setup
```python
cognito_user_pool = {
    "pool_name": "FaithChatbotUsers",
    "alias_attributes": ["email"],
    "auto_verified_attributes": ["email"],
    "password_policy": {
        "minimum_length": 8,
        "require_uppercase": True,
        "require_lowercase": True,
        "require_numbers": True,
        "require_symbols": False
    },
    "mfa_configuration": "OPTIONAL",
    "account_recovery_setting": {
        "recovery_mechanisms": [
            {"name": "verified_email", "priority": 1}
        ]
    }
}

# User Pool Client for web application
user_pool_client = {
    "client_name": "FaithChatbotWebClient",
    "user_pool_id": "user_pool_id",
    "generate_secret": False,  # Public client for web
    "auth_flows": ["ALLOW_USER_SRP_AUTH", "ALLOW_REFRESH_TOKEN_AUTH"],
    "oauth_flows": ["code"],
    "oauth_scopes": ["openid", "email", "profile"],
    "callback_urls": ["https://app.faithchatbot.com/auth/callback"],
    "logout_urls": ["https://app.faithchatbot.com/auth/logout"],
    "supported_identity_providers": ["COGNITO"]
}

# Hosted UI Domain
hosted_ui_domain = {
    "domain": "auth.faithchatbot.com",
    "certificate_arn": "arn:aws:acm:us-east-1:ACCOUNT:certificate/CERT_ID"
}
```

### 3. DynamoDB Table Design

#### UserProfile Table
```python
user_profile_table = {
    "table_name": "FaithChatbot-UserProfiles",
    "billing_mode": "ON_DEMAND",
    "hash_key": "user_id",
    "attributes": [
        {"name": "user_id", "type": "S"},
        {"name": "email", "type": "S"}
    ],
    "global_secondary_indexes": [
        {
            "index_name": "EmailIndex",
            "hash_key": "email",
            "projection_type": "ALL"
        }
    ],
    "point_in_time_recovery": True,
    "server_side_encryption": {
        "enabled": True,
        "kms_key_id": "alias/aws/dynamodb"
    }
}

# Sample record structure
user_profile_record = {
    "user_id": "user_123",
    "email": "user@example.com",
    "first_name": "John",
    "created_at": "2024-01-26T10:00:00Z",
    "last_active": "2024-01-26T14:30:00Z",
    "preferences": {
        "notification_email": True,
        "prayer_connect_enabled": True
    },
    "consent_history": [
        {
            "action": "prayer_connect_consent",
            "timestamp": "2024-01-26T14:25:00Z",
            "granted": True
        }
    ]
}
```

#### ConversationSession Table
```python
conversation_session_table = {
    "table_name": "FaithChatbot-ConversationSessions",
    "billing_mode": "ON_DEMAND",
    "hash_key": "session_id",
    "attributes": [
        {"name": "session_id", "type": "S"},
        {"name": "user_id", "type": "S"}
    ],
    "global_secondary_indexes": [
        {
            "index_name": "UserIndex",
            "hash_key": "user_id",
            "projection_type": "ALL"
        }
    ],
    "ttl_attribute": "ttl",  # Auto-cleanup after 30 days
    "point_in_time_recovery": True
}

# Sample record structure
conversation_record = {
    "session_id": "session_456",
    "user_id": "user_123",
    "created_at": "2024-01-26T14:00:00Z",
    "updated_at": "2024-01-26T14:30:00Z",
    "ttl": 1706544000,  # 30 days from creation
    "messages": [
        {
            "id": "msg_1",
            "timestamp": "2024-01-26T14:00:00Z",
            "role": "user",
            "content": "I'm feeling anxious about work",
            "emotion_classification": {
                "primary_emotion": "anxiety",
                "confidence": 0.85,
                "risk_flags": ["mild_distress"]
            }
        },
        {
            "id": "msg_2",
            "timestamp": "2024-01-26T14:01:00Z",
            "role": "assistant",
            "content": "I understand you're feeling anxious...",
            "bible_verse": {
                "reference": "Philippians 4:6-7",
                "text": "Do not be anxious about anything..."
            }
        }
    ]
}
```

#### PrayerRequest Table
```python
prayer_request_table = {
    "table_name": "FaithChatbot-PrayerRequests",
    "billing_mode": "ON_DEMAND",
    "hash_key": "request_id",
    "attributes": [
        {"name": "request_id", "type": "S"},
        {"name": "user_id", "type": "S"},
        {"name": "status", "type": "S"}
    ],
    "global_secondary_indexes": [
        {
            "index_name": "UserIndex",
            "hash_key": "user_id",
            "projection_type": "ALL"
        },
        {
            "index_name": "StatusIndex",
            "hash_key": "status",
            "projection_type": "ALL"
        }
    ]
}

# Sample record structure
prayer_request_record = {
    "request_id": "pr_789",
    "user_id": "user_123",
    "user_email": "user@example.com",
    "status": "pending",  # pending, sent, responded, closed
    "created_at": "2024-01-26T14:25:00Z",
    "telegram_message_id": None,
    "responded_at": None,
    "consent_timestamp": "2024-01-26T14:25:00Z"
}
```

#### ConsentLog Table
```python
consent_log_table = {
    "table_name": "FaithChatbot-ConsentLogs",
    "billing_mode": "ON_DEMAND",
    "hash_key": "log_id",
    "attributes": [
        {"name": "log_id", "type": "S"},
        {"name": "user_id", "type": "S"}
    ],
    "global_secondary_indexes": [
        {
            "index_name": "UserIndex",
            "hash_key": "user_id",
            "projection_type": "ALL"
        }
    ]
}

# Sample record structure
consent_log_record = {
    "log_id": "consent_101",
    "user_id": "user_123",
    "action": "prayer_connect_consent",
    "timestamp": "2024-01-26T14:25:00Z",
    "granted": True,
    "purpose": "Share email with prayer team for Google Meet invitation",
    "ip_address": "192.168.1.100",
    "user_agent": "Mozilla/5.0..."
}
```

### 4. SQS Configuration

#### Prayer Request Queue
```python
prayer_request_queue = {
    "queue_name": "FaithChatbot-PrayerRequests",
    "visibility_timeout_seconds": 300,
    "message_retention_period": 1209600,  # 14 days
    "receive_message_wait_time_seconds": 20,  # Long polling
    "redrive_policy": {
        "dead_letter_target_arn": "arn:aws:sqs:us-east-1:ACCOUNT:FaithChatbot-PrayerRequests-DLQ",
        "max_receive_count": 3
    },
    "kms_master_key_id": "alias/aws/sqs"
}

# Dead Letter Queue
prayer_request_dlq = {
    "queue_name": "FaithChatbot-PrayerRequests-DLQ",
    "message_retention_period": 1209600  # 14 days
}

# Sample message structure
prayer_request_message = {
    "request_id": "pr_789",
    "user_id": "user_123",
    "user_email": "user@example.com",
    "user_name": "John",
    "timestamp": "2024-01-26T14:25:00Z",
    "consent_confirmed": True
}
```

### 5. FastAPI Application Structure

#### Project Structure
```
faith_chatbot_api/
├── app/
│   ├── __init__.py
│   ├── main.py                 # FastAPI application entry point
│   ├── config.py              # Configuration management
│   ├── dependencies.py        # Dependency injection
│   ├── middleware/
│   │   ├── __init__.py
│   │   ├── auth.py            # JWT authentication middleware
│   │   └── logging.py         # Request logging middleware
│   ├── models/
│   │   ├── __init__.py
│   │   ├── user.py            # User data models
│   │   ├── conversation.py    # Conversation models
│   │   └── prayer.py          # Prayer request models
│   ├── services/
│   │   ├── __init__.py
│   │   ├── auth_service.py    # Authentication logic
│   │   ├── db_service.py      # Database operations
│   │   ├── bedrock_service.py # Bedrock integration
│   │   └── emotion_service.py # Emotion classification
│   ├── routers/
│   │   ├── __init__.py
│   │   ├── health.py          # Health check endpoints
│   │   ├── auth.py            # Authentication endpoints
│   │   └── chat.py            # Chat endpoints (Phase 2)
│   └── utils/
│       ├── __init__.py
│       ├── logger.py          # Structured logging
│       └── exceptions.py      # Custom exceptions
├── tests/
│   ├── __init__.py
│   ├── test_auth.py
│   ├── test_db.py
│   └── test_emotion.py
├── requirements.txt
├── Dockerfile
└── docker-compose.yml
```

#### Configuration Management
```python
# app/config.py
from pydantic import BaseSettings
from typing import Optional

class Settings(BaseSettings):
    # AWS Configuration
    aws_region: str = "us-east-1"
    aws_access_key_id: Optional[str] = None
    aws_secret_access_key: Optional[str] = None
    
    # Cognito Configuration
    cognito_user_pool_id: str
    cognito_client_id: str
    cognito_region: str = "us-east-1"
    
    # DynamoDB Configuration
    dynamodb_user_table: str = "FaithChatbot-UserProfiles"
    dynamodb_conversation_table: str = "FaithChatbot-ConversationSessions"
    dynamodb_prayer_table: str = "FaithChatbot-PrayerRequests"
    dynamodb_consent_table: str = "FaithChatbot-ConsentLogs"
    
    # Bedrock Configuration
    bedrock_model_id: str = "anthropic.claude-3-sonnet-20240229-v1:0"
    bedrock_guardrails_id: Optional[str] = None
    
    # SQS Configuration
    sqs_prayer_queue_url: str
    
    # Application Configuration
    environment: str = "development"
    log_level: str = "INFO"
    cors_origins: list = ["http://localhost:3000"]
    
    class Config:
        env_file = ".env"

settings = Settings()
```

### 6. Emotion Classification System

#### Emotion Taxonomy
```python
# app/models/emotion.py
from enum import Enum
from typing import List, Optional
from pydantic import BaseModel

class PrimaryEmotion(str, Enum):
    ANXIETY = "anxiety"
    JOY = "joy"
    SADNESS = "sadness"
    ANGER = "anger"
    FEAR = "fear"
    SHAME = "shame"
    HOPE = "hope"
    PEACE = "peace"
    GRIEF = "grief"
    LONELINESS = "loneliness"
    GRATITUDE = "gratitude"
    CONFUSION = "confusion"

class RiskFlag(str, Enum):
    MILD_DISTRESS = "mild_distress"
    MODERATE_DISTRESS = "moderate_distress"
    SEVERE_DISTRESS = "severe_distress"
    CRISIS_INDICATORS = "crisis_indicators"

class EmotionClassification(BaseModel):
    primary_emotion: PrimaryEmotion
    secondary_emotion: Optional[PrimaryEmotion] = None
    confidence: float  # 0.0 to 1.0
    risk_flags: List[RiskFlag] = []
    crisis_indicators: List[str] = []
    reasoning: Optional[str] = None
```

#### Bedrock Integration
```python
# app/services/bedrock_service.py
import json
import boto3
from typing import Dict, Any
from app.models.emotion import EmotionClassification
from app.config import settings

class BedrockService:
    def __init__(self):
        self.client = boto3.client(
            'bedrock-runtime',
            region_name=settings.aws_region
        )
        self.model_id = settings.bedrock_model_id
    
    async def classify_emotion(self, message: str, context: str = "") -> EmotionClassification:
        """Classify emotion using Bedrock Claude model"""
        
        prompt = self._build_classification_prompt(message, context)
        
        try:
            response = self.client.invoke_model(
                modelId=self.model_id,
                body=json.dumps({
                    "anthropic_version": "bedrock-2023-05-31",
                    "max_tokens": 1000,
                    "messages": [{"role": "user", "content": prompt}],
                    "temperature": 0.1  # Low temperature for consistent classification
                })
            )
            
            response_body = json.loads(response['body'].read())
            classification_json = self._extract_json_from_response(
                response_body['content'][0]['text']
            )
            
            return EmotionClassification(**classification_json)
            
        except Exception as e:
            # Log error and return default classification
            logger.error(f"Emotion classification failed: {e}")
            return EmotionClassification(
                primary_emotion=PrimaryEmotion.CONFUSION,
                confidence=0.0,
                risk_flags=[RiskFlag.MILD_DISTRESS]
            )
    
    def _build_classification_prompt(self, message: str, context: str) -> str:
        """Build emotion classification prompt"""
        return f"""
Human: You are an emotion classification system for a faith-based support chatbot. 
Analyze the following message and classify the user's emotional state.

Message: "{message}"
Context: "{context}"

Respond with a JSON object containing:
- primary_emotion: one of [anxiety, joy, sadness, anger, fear, shame, hope, peace, grief, loneliness, gratitude, confusion]
- secondary_emotion: optional secondary emotion from the same list
- confidence: float between 0.0 and 1.0
- risk_flags: array of risk indicators [mild_distress, moderate_distress, severe_distress, crisis_indicators]
- crisis_indicators: array of specific crisis signals if any (e.g., ["self_harm_mention", "suicide_ideation"])
- reasoning: brief explanation of the classification

JSON Response:
"""
```

### 7. Biblical Content Database

#### Content Structure
```python
# app/models/biblical_content.py
from typing import List, Dict
from pydantic import BaseModel

class BiblicalVerse(BaseModel):
    reference: str
    text: str
    theme: str
    translation: str = "NIV"

class BiblicalContent(BaseModel):
    emotion: str
    themes: List[str]
    verses: List[BiblicalVerse]
    reflections: List[str]
    action_steps: List[str]
    prayers: List[str]

# Sample content database
BIBLICAL_CONTENT_DB: Dict[str, BiblicalContent] = {
    "anxiety": BiblicalContent(
        emotion="anxiety",
        themes=["peace", "trust", "gods_presence", "surrender"],
        verses=[
            BiblicalVerse(
                reference="Philippians 4:6-7",
                text="Do not be anxious about anything, but in every situation, by prayer and petition, with thanksgiving, present your requests to God. And the peace of God, which transcends all understanding, will guard your hearts and your minds in Christ Jesus.",
                theme="peace_and_trust"
            ),
            BiblicalVerse(
                reference="Matthew 6:26",
                text="Look at the birds of the air; they do not sow or reap or store away in barns, and yet your heavenly Father feeds them. Are you not much more valuable than they?",
                theme="gods_provision"
            )
        ],
        reflections=[
            "God invites us to bring our worries to Him in prayer, knowing that His peace surpasses our understanding.",
            "Anxiety often stems from trying to control what only God can handle. Trust in His provision and care."
        ],
        action_steps=[
            "Take 3 deep breaths and speak this worry aloud to God in prayer",
            "Write down one thing you're grateful for today",
            "Read Psalm 23 slowly and meditate on God's care for you"
        ],
        prayers=[
            "Lord, I bring my anxious thoughts to You. Help me trust in Your perfect plan and find peace in Your presence."
        ]
    )
    # Additional emotions will be added in implementation
}
```

## Security Design

### IAM Roles and Policies

#### ECS Task Role
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
        "arn:aws:bedrock:us-east-1::foundation-model/anthropic.claude-3-sonnet-20240229-v1:0"
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
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": [
        "arn:aws:logs:us-east-1:ACCOUNT:log-group:/ecs/faith-chatbot:*"
      ]
    }
  ]
}
```

### Encryption Strategy
- DynamoDB: Server-side encryption with AWS managed keys
- SQS: KMS encryption for message content
- Secrets Manager: Automatic encryption for sensitive configuration
- CloudWatch Logs: Encryption at rest enabled

## Testing Strategy

### Unit Testing Framework
```python
# tests/test_emotion_classification.py
import pytest
from app.services.emotion_service import EmotionService
from app.models.emotion import PrimaryEmotion, RiskFlag

class TestEmotionClassification:
    
    @pytest.fixture
    def emotion_service(self):
        return EmotionService()
    
    def test_anxiety_classification(self, emotion_service):
        """Test anxiety emotion classification"""
        message = "I'm really worried about my job interview tomorrow"
        result = emotion_service.classify_emotion(message)
        
        assert result.primary_emotion == PrimaryEmotion.ANXIETY
        assert result.confidence > 0.7
        assert RiskFlag.MILD_DISTRESS in result.risk_flags
    
    def test_crisis_detection(self, emotion_service):
        """Test crisis indicator detection"""
        message = "I don't want to be here anymore"
        result = emotion_service.classify_emotion(message)
        
        assert RiskFlag.CRISIS_INDICATORS in result.risk_flags
        assert len(result.crisis_indicators) > 0
```

## Deployment Strategy

### Infrastructure as Code
- Use AWS CDK (Python) for infrastructure definition
- Environment-specific parameter files
- Automated deployment via GitHub Actions
- State management with CDK/CloudFormation

### Environment Configuration
```yaml
# environments/dev.yaml
environment: development
vpc_cidr: "10.0.0.0/16"
cognito_domain: "auth-dev.faithchatbot.com"
log_level: "DEBUG"

# environments/prod.yaml
environment: production
vpc_cidr: "10.1.0.0/16"
cognito_domain: "auth.faithchatbot.com"
log_level: "INFO"
```

This foundation phase establishes the secure, scalable infrastructure needed to support the entire faith-based motivator chatbot system, with proper authentication, data storage, and AI/ML capabilities.