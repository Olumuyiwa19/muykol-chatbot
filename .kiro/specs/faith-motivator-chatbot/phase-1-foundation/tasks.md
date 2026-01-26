# Phase 1: Foundation & Infrastructure - Implementation Tasks

## 1. AWS Infrastructure Setup

### 1.1 Create AWS CDK/Terraform infrastructure code
- [ ] 1.1.1 VPC with private/public subnets across multiple AZs
  - Create VPC with CIDR 10.0.0.0/16
  - Configure public subnets (10.0.1.0/24, 10.0.2.0/24) in AZ-a and AZ-b
  - Configure private subnets (10.0.3.0/24, 10.0.4.0/24) in AZ-a and AZ-b
  - Set up Internet Gateway for public subnets
  - Configure route tables for public and private subnets
- [ ] 1.1.2 VPC endpoints for AWS services (Bedrock, DynamoDB, SES, etc.)
  - Create interface endpoints for Bedrock Runtime, SES, ECR (api/dkr), CloudWatch Logs, Secrets Manager, STS, KMS
  - Create gateway endpoints for DynamoDB and S3
  - Configure endpoint policies to restrict access to required resources only
  - Set up security groups for VPC endpoints allowing access from ECS tasks
- [ ] 1.1.3 Security groups with least privilege access
  - Create ECS task security group allowing inbound on port 8000 from ALB only
  - Create ALB security group allowing inbound HTTPS from internet
  - Create VPC endpoint security group allowing HTTPS from ECS tasks
  - Configure egress rules following least privilege principle
- [ ] 1.1.4 IAM roles and policies for all services
  - Create ECS task execution role with ECR and CloudWatch Logs permissions
  - Create ECS task role with Bedrock, DynamoDB, and SQS permissions
  - Create Lambda execution role for prayer request processing (future use)
  - Implement least privilege policies for all roles

### 1.2 Set up AWS Cognito User Pool
- [ ] 1.2.1 Configure Hosted UI with custom domain
  - Create Cognito User Pool with email as username
  - Configure password policy (8+ chars, uppercase, lowercase, numbers)
  - Set up custom domain (auth.faithchatbot.com) with SSL certificate
  - Configure Hosted UI branding and customization
- [ ] 1.2.2 Implement Authorization Code + PKCE flow
  - Create User Pool Client for web application (public client)
  - Configure OAuth flows to use Authorization Code with PKCE
  - Set callback URLs for local development and production
  - Configure logout URLs and session timeout settings
- [ ] 1.2.3 Configure JWT token settings and validation
  - Set access token expiration to 1 hour
  - Set refresh token expiration to 30 days
  - Configure token validation settings
  - Set up JWKS endpoint for token verification

### 1.3 Create DynamoDB tables
- [ ] 1.3.1 UserProfile table with GSI for email lookup
  - Create table with user_id as hash key
  - Add Global Secondary Index on email attribute
  - Configure on-demand billing mode
  - Enable point-in-time recovery and encryption at rest
- [ ] 1.3.2 ConversationSession table with TTL for cleanup
  - Create table with session_id as hash key
  - Add GSI on user_id for user conversation lookup
  - Configure TTL attribute for automatic cleanup after 30 days
  - Enable point-in-time recovery and encryption at rest
- [ ] 1.3.3 PrayerRequest table with status tracking
  - Create table with request_id as hash key
  - Add GSI on user_id and status for efficient queries
  - Configure on-demand billing mode
  - Enable point-in-time recovery and encryption at rest
- [ ] 1.3.4 ConsentLog table for audit trail
  - Create table with log_id as hash key
  - Add GSI on user_id for user consent history lookup
  - Configure on-demand billing mode
  - Enable point-in-time recovery and encryption at rest

### 1.4 Set up SQS queue for prayer requests
- [ ] 1.4.1 Main queue with dead letter queue
  - Create FaithChatbot-PrayerRequests queue with KMS encryption
  - Create FaithChatbot-PrayerRequests-DLQ dead letter queue
  - Configure redrive policy with max receive count of 3
  - Set up queue permissions for ECS tasks to send messages
- [ ] 1.4.2 Configure message retention and visibility timeout
  - Set message retention period to 14 days
  - Configure visibility timeout to 5 minutes
  - Enable long polling with 20-second wait time
  - Set up CloudWatch alarms for queue depth and DLQ messages

### 1.5 Configure Amazon Bedrock access
- [ ] 1.5.1 Enable required models (Claude, Titan, etc.)
  - Request access to Anthropic Claude 3 Sonnet model
  - Request access to Amazon Titan models if needed
  - Verify model availability in target region (us-east-1)
  - Test model invocation with sample requests
- [ ] 1.5.2 Set up Bedrock Guardrails for content filtering
  - Create guardrails configuration for content filtering
  - Configure filters for sexual content, violence, hate speech, and insults
  - Set up PII detection and blocking for sensitive information
  - Test guardrails with sample harmful and sensitive content
- [ ] 1.5.3 Configure model access policies
  - Create IAM policies restricting model access to specific models only
  - Configure resource-based policies if available
  - Set up CloudTrail logging for Bedrock API calls
  - Implement cost controls and usage monitoring

## 2. Backend API Development

### 2.1 Create FastAPI application structure
- [ ] 2.1.1 Set up project structure with proper modules
  - Initialize Python project with proper directory structure
  - Create app/, tests/, and configuration directories
  - Set up models/, services/, routers/, and utils/ modules
  - Configure Python virtual environment and dependencies
- [ ] 2.1.2 Configure environment variables and settings
  - Create Pydantic Settings class for configuration management
  - Set up environment-specific configuration files
  - Configure AWS credentials and region settings
  - Implement secure secrets management for sensitive values
- [ ] 2.1.3 Implement health check endpoint
  - Create /health endpoint returning system status
  - Include dependency health checks (DynamoDB, Bedrock connectivity)
  - Add version information and deployment timestamp
  - Configure health check for ECS target group
- [ ] 2.1.4 Set up structured logging with correlation IDs
  - Configure structlog for JSON-formatted logging
  - Implement correlation ID generation and propagation
  - Set up CloudWatch Logs integration
  - Add request/response logging middleware with sensitive data filtering

### 2.2 Implement authentication middleware
- [ ] 2.2.1 JWT token validation middleware
  - Create middleware to validate Cognito JWT tokens
  - Implement JWKS key retrieval and caching
  - Add token expiration and signature validation
  - Handle authentication errors with proper HTTP status codes
- [ ] 2.2.2 User session management
  - Create user context from validated JWT tokens
  - Implement user information extraction from token claims
  - Set up session state management for API requests
  - Add user lookup and profile creation if needed
- [ ] 2.2.3 Protected route decorators
  - Create dependency for protecting authenticated routes
  - Implement role-based access control if needed
  - Add optional authentication for public endpoints
  - Configure CORS settings for frontend integration

### 2.3 Create database access layer
- [ ] 2.3.1 DynamoDB client with connection pooling
  - Initialize boto3 DynamoDB client with proper configuration
  - Implement connection pooling and retry logic
  - Add error handling for DynamoDB exceptions
  - Configure client for VPC endpoint usage
- [ ] 2.3.2 User profile CRUD operations
  - Implement create_user_profile function
  - Implement get_user_profile and get_user_by_email functions
  - Implement update_user_profile function
  - Add proper error handling and validation
- [ ] 2.3.3 Conversation session management
  - Implement create_conversation_session function
  - Implement get_conversation_session and list_user_conversations functions
  - Implement update_conversation_session with message appending
  - Add TTL management for automatic cleanup
- [ ] 2.3.4 Prayer request operations
  - Implement create_prayer_request function
  - Implement get_prayer_request and list_user_prayer_requests functions
  - Implement update_prayer_request_status function
  - Add consent logging integration

## 3. Emotion Classification System

### 3.1 Design emotion taxonomy and mapping
- [ ] 3.1.1 Define 8-12 primary emotions with descriptions
  - Create PrimaryEmotion enum with anxiety, joy, sadness, anger, fear, shame, hope, peace, grief, loneliness, gratitude, confusion
  - Document each emotion with clear definitions and examples
  - Create RiskFlag enum for distress levels and crisis indicators
  - Define emotion classification confidence thresholds
- [ ] 3.1.2 Create emotion-to-theme mapping structure
  - Design BiblicalContent model with themes, verses, reflections, actions
  - Create emotion-to-theme mappings (e.g., anxiety → peace, trust, gods_presence)
  - Define theme categories and their relationships
  - Create validation rules for content structure
- [ ] 3.1.3 Design JSON schema for classification output
  - Create EmotionClassification Pydantic model
  - Define required fields: primary_emotion, confidence, risk_flags
  - Add optional fields: secondary_emotion, crisis_indicators, reasoning
  - Implement validation rules for confidence scores and risk flags

### 3.2 Implement Bedrock emotion classification
- [ ] 3.2.1 Create emotion classification prompt templates
  - Design system prompt for emotion classification task
  - Create user message template with context inclusion
  - Define output format requirements (JSON schema)
  - Add examples for few-shot learning if needed
- [ ] 3.2.2 Implement two-step LLM pipeline
  - Create BedrockService class for model interactions
  - Implement classify_emotion method with error handling
  - Add response parsing and validation
  - Configure model parameters (temperature, max_tokens)
- [ ] 3.2.3 Add confidence scoring and risk flag detection
  - Implement confidence score validation (0.0-1.0 range)
  - Create risk flag detection logic based on emotion and content
  - Add confidence threshold handling for uncertain classifications
  - Implement fallback classification for low confidence scores
- [ ] 3.2.4 Implement crisis indicator detection
  - Create crisis keyword detection patterns
  - Implement severity assessment for crisis situations
  - Add crisis indicator categorization (self_harm, suicide_ideation, etc.)
  - Create escalation triggers for high-risk classifications

### 3.3 Create biblical content database
- [ ] 3.3.1 Curate emotion-to-scripture mappings
  - Research and compile relevant Bible verses for each emotion
  - Create initial content for anxiety, sadness, fear, anger, and hope
  - Ensure theological accuracy and pastoral review
  - Organize verses by themes and emotional relevance
- [ ] 3.3.2 Create reflection and action step content
  - Write personal reflection prompts for each emotion/verse combination
  - Create practical action steps (prayer, breathing, journaling)
  - Ensure action steps are specific and achievable
  - Add variety to avoid repetitive responses
- [ ] 3.3.3 Implement content retrieval system
  - Create BiblicalContentService for content management
  - Implement get_content_for_emotion method
  - Add content randomization to avoid repetitive responses
  - Create content validation and quality checks
- [ ] 3.3.4 Add content quality validation
  - Implement content structure validation
  - Add theological accuracy checks where possible
  - Create content review workflow for pastoral approval
  - Add content versioning and update mechanisms

## Testing Requirements

### Unit Tests
- [ ] Test AWS infrastructure deployment and configuration
- [ ] Test Cognito authentication flow and JWT validation
- [ ] Test DynamoDB table operations and data integrity
- [ ] Test emotion classification accuracy with sample data
- [ ] Test biblical content retrieval and mapping
- [ ] Test API endpoints with authentication and error handling

### Integration Tests
- [ ] Test end-to-end infrastructure deployment
- [ ] Test Cognito integration with FastAPI authentication
- [ ] Test Bedrock model access and response parsing
- [ ] Test DynamoDB operations through VPC endpoints
- [ ] Test SQS message publishing and queue configuration

### Property-Based Tests
- [ ] Test JWT token validation across various token formats
- [ ] Test emotion classification consistency with diverse inputs
- [ ] Test DynamoDB operations with various data types and sizes
- [ ] Test content retrieval system with all emotion types

## Success Criteria
- All AWS infrastructure deploys successfully via IaC
- Cognito authentication works end-to-end with JWT validation
- DynamoDB tables support all required operations with proper indexing
- Emotion classification achieves >80% accuracy on test dataset
- Biblical content database contains minimum 5 entries per emotion
- API health checks pass and authentication middleware works correctly
- All unit and integration tests pass
- Infrastructure follows AWS security best practices
- System is ready for Phase 2 chat functionality development

## Dependencies
- AWS account with appropriate service limits and permissions
- Domain name for Cognito custom domain configuration
- SSL certificate for custom domain (ACM)
- Pastoral staff availability for biblical content review
- Test dataset for emotion classification validation

## Estimated Timeline
- Infrastructure setup: 1-2 weeks
- Backend API development: 1-2 weeks  
- Emotion classification system: 2-3 weeks
- Biblical content curation: 1-2 weeks (parallel with development)
- Testing and validation: 1 week
- **Total: 6-10 weeks**