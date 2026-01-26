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

### Property-Based Testing Focus
- Test emotion classification consistency across diverse inputs
- Verify consent and privacy compliance under all scenarios
- Validate crisis detection accuracy with edge cases
- Ensure content filtering effectiveness across content types

### Quality Assurance Standards
- All biblical content must be fact-checked by theological reviewers
- Crisis response workflows must be tested with realistic scenarios
- User interface must be accessible (WCAG 2.1 AA compliance)
- Performance testing under realistic load conditions

## Community Integration Guidelines

### Telegram Prayer Group Management
- Provide clear guidelines for community volunteers
- Include response time expectations (24-48 hours)
- Maintain confidentiality standards for all interactions
- Regular training for community members on appropriate responses

### Email Communication Standards
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

### Content Quality Assurance
- Regular review of AI-generated responses for theological accuracy
- User feedback integration for continuous improvement
- Periodic update of biblical content database
- Community volunteer feedback incorporation

## Compliance and Legal Considerations

### Data Protection
- Comply with applicable privacy laws (GDPR, CCPA, etc.)
- Maintain clear privacy policy and terms of service
- Provide user data access and deletion capabilities
- Regular compliance audits and documentation

### Liability Management
- Clear disclaimers about service limitations
- Professional liability considerations for crisis situations
- Regular legal review of terms and conditions
- Insurance coverage for technology and professional liability

These standards ensure that the faith-based motivator chatbot serves users with excellence while maintaining the highest standards of safety, privacy, and theological integrity.