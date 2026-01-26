# Faith-Based Motivator Chatbot - Design Document

## Architecture Overview

The faith-based motivator chatbot follows a modern cloud-native architecture using AWS services for scalability, security, and reliability. The system implements a two-step LLM pipeline for emotion classification and response generation, with asynchronous processing for prayer connect requests.

### High-Level Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────────┐
│   Web Frontend  │────│  Application     │────│   Amazon Bedrock    │
│  (React/Next.js)│    │  Load Balancer   │    │   (LLM + Guardrails)│
└─────────────────┘    └──────────────────┘    └─────────────────────┘
                                │
                       ┌────────▼────────┐
                       │   ECS Fargate   │
                       │   (API Service) │
                       └────────┬────────┘
                                │
        ┌───────────────────────┼───────────────────────┐
        │                       │                       │
┌───────▼────────┐    ┌────────▼────────┐    ┌────────▼────────┐
│   DynamoDB     │    │   SQS Queue     │    │  AWS Cognito    │
│ (User Data &   │    │ (Prayer Requests)│    │ (Authentication)│
│  Conversations)│    └────────┬────────┘    └─────────────────┘
└────────────────┘             │
                       ┌────────▼────────┐
                       │  Lambda Worker  │
                       │ (Telegram + SES)│
                       └─────────────────┘
```

## Component Design

### 1. Frontend Application
**Technology:** Reflex with static export
**Hosting:** S3 + CloudFront CDN
**Features:**
- Responsive chat interface
- AWS Cognito authentication integration
- Real-time message display
- Prayer connect consent flow

### 2. Backend API Service
**Technology:** FastAPI or similar Python framework
**Hosting:** ECS Fargate with Application Load Balancer
**Responsibilities:**
- Chat message processing
- Emotion classification pipeline
- Response generation
- User session management
- Prayer request initiation

### 3. Emotion Classification Pipeline

#### Step 1: Emotion Classification
```python
# Input: User message + conversation context
# Output: Structured JSON
{
    "primary_emotion": "anxiety",
    "secondary_emotion": "fear", 
    "confidence": 0.85,
    "risk_flags": ["mild_distress"],
    "crisis_indicators": []
}
```

#### Step 2: Response Generation
```python
# Input: Emotion classification + curated content
# Output: Structured response
{
    "empathy_statement": "I can sense you're feeling anxious...",
    "bible_verse": {
        "reference": "Philippians 4:6-7",
        "text": "Do not be anxious about anything...",
        "theme": "peace_and_trust"
    },
    "reflection": "God invites us to bring our worries to Him...",
    "action_step": "Take 3 deep breaths and speak this worry aloud to God",
    "prayer_connect_offer": true
}
```

### 4. Biblical Content Management

#### Emotion-to-Content Mapping
```yaml
anxiety:
  themes: [peace, trust, gods_presence, surrender]
  verses:
    - reference: "Philippians 4:6-7"
      text: "Do not be anxious about anything..."
      theme: "peace_and_trust"
    - reference: "Matthew 6:26"
      text: "Look at the birds of the air..."
      theme: "gods_provision"
  reflections:
    - "God invites us to bring our worries to Him in prayer"
    - "Anxiety often stems from trying to control what only God can handle"
  action_steps:
    - "Take 3 deep breaths and speak this worry aloud to God"
    - "Write down one thing you're grateful for today"
```

### 5. Prayer Connect Workflow

#### Consent Process
1. User receives encouragement response
2. System offers prayer connect option
3. Consent modal explains data sharing clearly
4. User provides explicit yes/no consent
5. Consent logged with timestamp and purpose

#### Asynchronous Processing
1. Prayer request ticket created in DynamoDB
2. Event published to SQS queue
3. Lambda worker processes request
4. Telegram message sent to prayer group
5. Confirmation email sent to user

#### Telegram Message Format
```
🙏 Prayer Connect Request

Request ID: PR-2024-001
Name: [First name or "Anonymous"]
Email: user@example.com
Timestamp: 2024-01-26 14:30 UTC

Guidelines:
- Respond within 24 hours when possible
- Send Google Meet link to the email above
- Keep conversations confidential
- Refer complex situations to pastoral team

Reply to this message when you've reached out.
```

### 6. Safety & Crisis Management

#### Crisis Detection Pipeline
```python
crisis_indicators = [
    "self_harm_intent",
    "suicide_ideation", 
    "immediate_danger",
    "abuse_disclosure",
    "severe_mental_health_crisis"
]

if any(indicator in classification.risk_flags for indicator in crisis_indicators):
    return generate_crisis_response()
```

#### Crisis Response Template
```python
{
    "immediate_resources": [
        "National Suicide Prevention Lifeline: 988",
        "Crisis Text Line: Text HOME to 741741",
        "Emergency Services: 911"
    ],
    "supportive_message": "Your life has value and meaning to God...",
    "next_steps": [
        "Please reach out to a trusted friend or family member",
        "Consider contacting a mental health professional",
        "We're here to pray with you - would you like to connect?"
    ],
    "disclaimer": "This service is not a replacement for professional help"
}
```

## Data Models

### User Profile
```python
class UserProfile:
    user_id: str
    email: str
    first_name: Optional[str]
    created_at: datetime
    last_active: datetime
    consent_history: List[ConsentRecord]
    preferences: UserPreferences
```

### Conversation Session
```python
class ConversationSession:
    session_id: str
    user_id: str
    messages: List[Message]
    emotion_history: List[EmotionClassification]
    created_at: datetime
    updated_at: datetime
```

### Prayer Request
```python
class PrayerRequest:
    request_id: str
    user_id: str
    user_email: str
    status: str  # pending, sent, responded, closed
    telegram_message_id: Optional[str]
    created_at: datetime
    responded_at: Optional[datetime]
```

## Security Design

### Authentication & Authorization
- AWS Cognito User Pool with Hosted UI
- Authorization Code + PKCE flow for web security
- JWT token validation on all API endpoints
- Session management with secure cookies

### Data Protection
- All data encrypted at rest (DynamoDB, S3)
- TLS 1.3 for all communications
- VPC endpoints for private AWS service access
- No NAT Gateway - fully private backend network

### Content Safety
- Amazon Bedrock Guardrails for input/output filtering
- Sensitive information detection and redaction
- Harmful content blocking
- Crisis content special handling

### Privacy Controls
- Data minimization - collect only necessary information
- Explicit consent for all data sharing
- Audit logging for all consent actions
- User data access and deletion capabilities

## Scalability & Performance

### Auto-Scaling Strategy
- ECS Service auto-scaling based on CPU/memory utilization
- DynamoDB on-demand scaling for variable workloads
- CloudFront CDN for global content delivery
- SQS for decoupling and handling traffic spikes

### Performance Targets
- Chat response time: < 3 seconds (95th percentile)
- Emotion classification: < 2 seconds
- Prayer request processing: < 30 seconds (asynchronous)
- System availability: 99.9% uptime

### Caching Strategy
- CloudFront for static assets
- Application-level caching for biblical content
- DynamoDB DAX for hot data (if needed)
- Browser caching for chat interface assets

## Monitoring & Observability

### Logging Strategy
- Structured JSON logging throughout application
- CloudWatch Logs for centralized log aggregation
- Request tracing with correlation IDs
- Sensitive data exclusion from logs

### Metrics & Alarms
- Application metrics: response times, error rates, user engagement
- Infrastructure metrics: CPU, memory, network utilization
- Business metrics: emotion classification accuracy, prayer connect rates
- Security metrics: authentication failures, suspicious activity

### Health Checks
- ECS service health checks on `/health` endpoint
- ALB target group health monitoring
- DynamoDB and Bedrock service availability checks
- End-to-end synthetic monitoring

## Testing Strategy

### Unit Testing
- Individual function and class testing
- Emotion classification accuracy validation
- Biblical content mapping verification
- Crisis detection algorithm testing

### Integration Testing
- API endpoint testing with real AWS services
- Authentication flow validation
- Database operations testing
- External service integration (Telegram, SES)

### Property-Based Testing Framework
**Testing Library:** Hypothesis (Python)

## Correctness Properties

Based on the requirements analysis, the following properties must hold:

### P1: Authentication Security Properties
**Validates: Requirements 1.2, 1.4**
```python
@given(jwt_token=valid_jwt_tokens())
def test_jwt_token_integrity(jwt_token):
    """JWT tokens must maintain integrity and proper expiration"""
    assert validate_jwt_token(jwt_token) == expected_validation_result(jwt_token)
    assert token_expiration_handled_correctly(jwt_token)
```

### P2: Emotion Classification Consistency
**Validates: Requirements 2.2, 2.3**
```python
@given(message=conversation_messages(), context=conversation_contexts())
def test_emotion_classification_consistency(message, context):
    """Emotion classification must be consistent and include required fields"""
    result = classify_emotion(message, context)
    assert has_required_emotion_fields(result)
    assert confidence_score_in_valid_range(result.confidence)
    assert classification_is_deterministic(message, context, result)
```

### P3: Response Format Compliance
**Validates: Requirements 3.3, 3.6**
```python
@given(emotion_data=emotion_classifications())
def test_response_format_compliance(emotion_data):
    """All responses must include actionable steps and avoid medical claims"""
    response = generate_response(emotion_data)
    assert has_actionable_step(response)
    assert not contains_medical_claims(response)
    assert follows_response_schema(response)
```

### P4: Consent and Data Privacy
**Validates: Requirements 4.2, 7.1, 7.2**
```python
@given(user_action=user_consent_actions())
def test_consent_and_privacy_compliance(user_action):
    """No data sharing without explicit consent, conversation content never shared"""
    if not user_action.consent_given:
        assert no_data_shared(user_action)
    
    telegram_message = create_prayer_request_message(user_action)
    assert not contains_conversation_content(telegram_message)
    assert only_contains_approved_fields(telegram_message)
```

### P5: Asynchronous Processing Reliability
**Validates: Requirements 4.5**
```python
@given(prayer_request=prayer_requests())
def test_async_processing_reliability(prayer_request):
    """Prayer requests must not block chat interface and be processed reliably"""
    start_time = time.time()
    chat_response = process_chat_with_prayer_request(prayer_request)
    processing_time = time.time() - start_time
    
    assert processing_time < MAX_CHAT_RESPONSE_TIME
    assert prayer_request_queued_successfully(prayer_request)
```

### P6: Crisis Detection Accuracy
**Validates: Requirements 6.1**
```python
@given(message=crisis_and_normal_messages())
def test_crisis_detection_accuracy(message):
    """Crisis detection must accurately identify high-risk situations"""
    classification = classify_emotion(message)
    expected_crisis_level = determine_expected_crisis_level(message)
    
    assert crisis_detection_matches_expectation(classification, expected_crisis_level)
    if is_crisis_message(message):
        assert has_crisis_response_elements(classification)
```

### P7: Content Filtering Effectiveness
**Validates: Requirements 7.5**
```python
@given(content=sensitive_and_normal_content())
def test_content_filtering_effectiveness(content):
    """Bedrock Guardrails must filter sensitive information effectively"""
    filtered_content = apply_bedrock_guardrails(content)
    
    assert not contains_sensitive_information(filtered_content)
    assert maintains_core_meaning(content, filtered_content)
```

### P8: Audit Trail Completeness
**Validates: Requirements 7.3**
```python
@given(user_interaction=user_interactions_with_consent())
def test_audit_trail_completeness(user_interaction):
    """All consent actions must be logged with proper timestamps"""
    process_user_interaction(user_interaction)
    
    if involves_consent(user_interaction):
        audit_record = get_audit_record(user_interaction.id)
        assert audit_record is not None
        assert has_valid_timestamp(audit_record)
        assert contains_required_consent_fields(audit_record)
```

## Deployment Strategy

### Environment Progression
1. **Development:** Local development with LocalStack for AWS services
2. **Staging:** Full AWS environment with production-like configuration
3. **Production:** Multi-AZ deployment with full monitoring and backup

### Infrastructure as Code
- Terraform for infrastructure provisioning
- Environment-specific configuration management
- Automated deployment pipelines with GitHub Actions
- Blue-green deployment strategy for zero-downtime updates

### Rollback Strategy
- ECS service rollback capability
- Database migration rollback procedures
- Feature flags for gradual feature rollout
- Monitoring-based automatic rollback triggers

## Future Enhancements

### Phase 2 Features
- RAG implementation with Amazon Bedrock Knowledge Bases
- Advanced analytics and user behavior insights
- Mobile native applications (iOS/Android)
- Multi-language support for global reach

### Phase 3 Features
- Voice and video chat capabilities
- Integration with church management systems
- Advanced AI-powered pastoral care insights
- Community prayer group management features

This design provides a solid foundation for building a secure, scalable, and effective faith-based motivator chatbot that serves users with biblical encouragement while maintaining the highest standards of safety and privacy.