---
inclusion: always
---

# Implementation Architecture Standards

## Current Implementation Overview

The muykol-chatbot has evolved into a production-ready faith-based motivator chatbot with the following architecture:

### Technology Stack
- **Backend**: FastAPI with Python 3.9+
- **Frontend**: Reflex (Python-based React framework)
- **Infrastructure**: Terraform (not CDK)
- **Database**: DynamoDB for chat history and user data
- **Authentication**: AWS Cognito integration
- **Deployment**: ECS Fargate with Application Load Balancer
- **CI/CD**: GitHub Actions with OIDC

### Current Implementation Structure

```
muykol-chatbot-app/
├── backend/                    # FastAPI application
│   ├── main.py                # Application entry point
│   ├── models/                # Pydantic models
│   ├── services/              # Business logic
│   ├── repositories/          # Data access layer
│   ├── routers/               # API endpoints
│   ├── middleware/            # Rate limiting, CORS
│   └── tests/                 # Comprehensive test suite
├── frontend/                  # Reflex application
│   ├── chatbot_app.py         # Main app component
│   ├── components/            # UI components
│   ├── state/                 # Application state management
│   ├── services/              # API integration
│   └── tests/                 # Frontend tests
├── lambda/                    # AWS Lambda functions
│   ├── backup_dynamodb.py     # Data backup
│   ├── user_data_export.py    # GDPR compliance
│   └── backup_metadata_tracker.py
└── scripts/                   # Deployment scripts
```

## Architecture Principles

### 1. Separation of Concerns
- **Backend**: Pure API service with business logic
- **Frontend**: Stateful UI with Reflex components
- **Infrastructure**: Terraform modules for reusability
- **Lambda**: Event-driven processing for background tasks

### 2. Security-First Design
- **Authentication**: AWS Cognito with JWT tokens
- **Authorization**: Role-based access control
- **Rate Limiting**: Redis-based with sliding window
- **Data Protection**: Encryption at rest and in transit
- **Input Validation**: Comprehensive request validation

### 3. Scalability Patterns
- **Containerized Services**: Docker with ECS Fargate
- **Auto-scaling**: Based on CPU and memory metrics
- **Load Balancing**: Application Load Balancer with health checks
- **Caching**: Redis for session and rate limit data
- **Async Processing**: SQS for prayer connect requests

### 4. Observability Standards
- **Structured Logging**: JSON format with correlation IDs
- **Health Checks**: Comprehensive endpoint monitoring
- **Metrics**: CloudWatch custom metrics
- **Tracing**: Request correlation across services
- **Error Handling**: Graceful degradation with user feedback

## Implementation Standards

### Backend Standards (FastAPI)
```python
# Service layer pattern
class ChatbotService:
    def __init__(self, bedrock_client, chat_history_service):
        self.bedrock_client = bedrock_client
        self.chat_history_service = chat_history_service
    
    async def process_message(self, message: str, user_id: str) -> ChatResponse:
        # Emotion classification -> Response generation pipeline
        pass

# Repository pattern for data access
class ChatHistoryRepository:
    async def save_message(self, message: ChatMessage) -> None:
        # DynamoDB operations with error handling
        pass
```

### Frontend Standards (Reflex)
```python
# State management with Reflex
class ChatState(rx.State):
    messages: list[dict] = []
    current_message: str = ""
    
    async def send_message(self):
        # API integration with error handling
        pass

# Component composition
def chat_component() -> rx.Component:
    return rx.vstack(
        message_history(),
        message_input(),
        spacing="4"
    )
```

### Infrastructure Standards (Terraform)
```hcl
# Modular infrastructure
module "vpc" {
  source = "./modules/vpc"
  environment = var.environment
}

module "ecs_cluster" {
  source = "./modules/ecs"
  vpc_id = module.vpc.vpc_id
  environment = var.environment
}
```

## Development Workflow

### 1. Local Development
- **Docker Compose**: Full stack local development
- **Environment Variables**: `.env` files for configuration
- **Hot Reload**: Both frontend and backend support
- **Testing**: Pytest with comprehensive coverage

### 2. CI/CD Pipeline
- **GitHub Actions**: Automated testing and deployment
- **OIDC Integration**: Secure AWS access without long-lived credentials
- **Multi-environment**: Dev, staging, production deployments
- **Infrastructure as Code**: Terraform state management

### 3. Quality Assurance
- **Code Quality**: Pre-commit hooks with linting
- **Security Scanning**: Bandit, Semgrep integration
- **Dependency Management**: Regular security updates
- **Performance Testing**: Load testing with realistic scenarios

## Deployment Architecture

### Production Environment
```
Internet Gateway
    ↓
Application Load Balancer (HTTPS)
    ↓
ECS Fargate Cluster
├── Backend Service (FastAPI)
├── Frontend Service (Reflex)
└── Worker Service (Background tasks)
    ↓
├── DynamoDB (Chat history)
├── Redis (Rate limiting)
├── SQS (Prayer requests)
└── Lambda (Data processing)
```

### Security Layers
1. **WAF**: Web Application Firewall
2. **VPC**: Private subnets for services
3. **Security Groups**: Least privilege access
4. **IAM Roles**: Service-specific permissions
5. **Secrets Manager**: Secure configuration storage

## Monitoring and Alerting

### Key Metrics
- **Response Time**: 95th percentile < 3 seconds
- **Error Rate**: < 1% of requests
- **Availability**: 99.9% uptime SLA
- **User Satisfaction**: Feedback scoring

### Alert Conditions
- High error rates or response times
- Service health check failures
- Resource utilization thresholds
- Security events or anomalies

## Compliance and Privacy

### Data Protection
- **GDPR Compliance**: User data export and deletion
- **Data Minimization**: Only collect necessary information
- **Consent Management**: Explicit user consent tracking
- **Audit Logging**: All data access logged

### Content Safety
- **Input Filtering**: Harmful content detection
- **Output Validation**: Theological accuracy checks
- **Crisis Detection**: Mental health resource routing
- **Community Guidelines**: Clear usage policies

This architecture supports the faith-based motivator chatbot's mission while maintaining enterprise-grade security, scalability, and reliability standards.
