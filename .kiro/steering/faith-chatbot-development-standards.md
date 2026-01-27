---
inclusion: always
---

# Faith-Based Chatbot Development Standards

## Biblical Content Guidelines

### Scripture Selection Principles
- **Contextual Relevance**: Choose verses that directly address the user's emotional state
- **Avoid "Verse Roulette"**: Never select random verses without considering context
- **Theological Accuracy**: Ensure interpretations align with mainstream Christian theology
- **Cultural Sensitivity**: Consider diverse denominational perspectives when possible

### Content Curation Standards
- All biblical content must be reviewed by pastoral staff before implementation
- Maintain a curated database of emotion-to-scripture mappings
- Include reflection prompts that help users apply biblical truths personally
- Provide actionable steps that are practical and spiritually grounding

## Safety and Ethical Guidelines

### Crisis Response Protocol
- **Immediate Safety**: Always prioritize user safety over theological discussion
- **Professional Boundaries**: Clearly state limitations - not medical or professional counseling
- **Resource Provision**: Maintain updated list of crisis resources (suicide hotlines, etc.)
- **Escalation Path**: Have clear procedures for high-risk situations

### Privacy and Consent Standards
- **Explicit Consent**: Never share user information without clear, informed consent
- **Data Minimization**: Collect and share only necessary information
- **Transparency**: Clearly explain what data is shared and with whom
- **Audit Trail**: Log all consent actions with timestamps for accountability

## Current Implementation Alignment

### Technology Stack Validation
The current FastAPI + Reflex implementation aligns with our standards:
- **Backend**: FastAPI provides robust API framework with automatic documentation
- **Frontend**: Reflex enables Python-based UI development maintaining consistency
- **Infrastructure**: Terraform provides infrastructure as code with better state management than CDK
- **Authentication**: AWS Cognito integration provides enterprise-grade security

### Architecture Compliance
Current implementation follows our architectural principles:
- **Separation of Concerns**: Clear backend/frontend/infrastructure boundaries
- **Security-First**: Comprehensive authentication, authorization, and rate limiting
- **Scalability**: ECS Fargate with auto-scaling capabilities
- **Observability**: Structured logging and health monitoring

## Technical Implementation Standards

### AWS Security Best Practices
- Use least privilege IAM policies for all services
- Implement VPC endpoints to avoid internet traffic for AWS services
- Enable encryption at rest for all data storage (DynamoDB, S3)
- Use AWS Secrets Manager for sensitive configuration

### Content Filtering Requirements
- Implement Amazon Bedrock Guardrails for all user input and AI output
- Filter sensitive personal information (SSN, credit cards, etc.)
- Block harmful or inappropriate content
- Maintain logs of filtered content for quality improvement

### Performance Standards
- Chat responses must complete within 3 seconds (95th percentile)
- System must handle concurrent users without degradation
- Implement proper error handling and graceful degradation
- Use structured logging with correlation IDs for troubleshooting

## Testing Requirements

### Current Test Coverage
The implementation includes comprehensive testing:
- **Unit Tests**: Backend services and repositories
- **Integration Tests**: API endpoints and database operations
- **Frontend Tests**: Component and state management testing
- **End-to-End Tests**: Full user workflow validation

### Quality Assurance Standards
- All biblical content must be fact-checked by theological reviewers
- Crisis response workflows must be tested with realistic scenarios
- User interface must be accessible (WCAG 2.1 AA compliance)
- Performance testing under realistic load conditions

## Community Integration Guidelines

### Prayer Connect Implementation
Current implementation supports:
- **Consent Management**: Explicit user consent for prayer sharing
- **Data Export**: GDPR-compliant user data export functionality
- **Background Processing**: SQS-based asynchronous prayer request handling
- **Community Integration**: Email and Telegram integration for prayer groups

### Communication Standards
- Use professional, compassionate tone in all communications
- Include clear instructions for Google Meet link sharing
- Provide escalation contacts for complex situations
- Maintain templates for consistent messaging

## Monitoring and Maintenance

### Operational Excellence
- Monitor emotion classification accuracy with human-labeled validation
- Track user satisfaction through feedback mechanisms
- Maintain uptime SLA of 99.9% or higher
- Regular security audits and penetration testing

### Current Monitoring Implementation
- **Health Checks**: Comprehensive endpoint monitoring
- **Structured Logging**: JSON format with correlation IDs
- **Error Tracking**: Graceful error handling with user feedback
- **Performance Metrics**: Response time and throughput monitoring

## Compliance and Legal Considerations

### Data Protection Implementation
Current implementation provides:
- **GDPR Compliance**: User data export and deletion endpoints
- **Privacy Controls**: Explicit consent tracking and management
- **Audit Logging**: All data access and modifications logged
- **Data Minimization**: Only necessary data collection and storage

### Liability Management
- Clear disclaimers about service limitations
- Professional liability considerations for crisis situations
- Regular legal review of terms and conditions
- Insurance coverage for technology and professional liability

## Development Workflow Standards

### Current CI/CD Implementation
- **GitHub Actions**: Automated testing and deployment pipeline
- **OIDC Integration**: Secure AWS access without long-lived credentials
- **Multi-Environment**: Separate dev, staging, and production environments
- **Infrastructure as Code**: Terraform state management with remote backend

### Code Quality Standards
- **Pre-commit Hooks**: Automated linting and formatting
- **Security Scanning**: Bandit and Semgrep integration
- **Dependency Management**: Regular security updates and vulnerability scanning
- **Code Review**: Required pull request reviews before merging

These standards ensure that the faith-based motivator chatbot serves users with excellence while maintaining the highest standards of safety, privacy, and theological integrity. The current implementation demonstrates strong alignment with these principles.