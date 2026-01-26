# Phase 4: Security & Compliance - Design Document

## Architecture Overview

Phase 4 implements comprehensive security measures, privacy controls, and compliance features across the entire faith-based motivator chatbot system. This includes content filtering, data protection, audit logging, monitoring, and regulatory compliance capabilities.

### Security Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Security & Compliance Layer                  │
│                                                                 │
│  ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐   │
│  │   Content       │ │   Privacy       │ │   Audit &       │   │
│  │   Filtering     │ │   Controls      │ │   Compliance    │   │
│  │                 │ │                 │ │                 │   │
│  │ • Bedrock       │ │ • Data Access   │ │ • Event Logging │   │
│  │   Guardrails    │ │ • Data Deletion │ │ • Compliance    │   │
│  │ • PII Detection │ │ • Consent Mgmt  │ │   Reporting     │   │
│  │ • Custom Rules  │ │ • Export/Import │ │ • Audit Trails  │   │
│  └─────────────────┘ └─────────────────┘ └─────────────────┘   │
└─────────────────────────┬───────────────────────────────────────┘
                          │
┌─────────────────────────▼───────────────────────────────────────┐
│                 Application Security Layer                      │
│                                                                 │
│  ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐   │
│  │ Rate Limiting & │ │ Authentication  │ │ Input/Output    │   │
│  │ Abuse Detection │ │ & Authorization │ │ Validation      │   │
│  │                 │ │                 │ │                 │   │
│  │ • API Limits    │ │ • JWT Validation│ │ • Schema Valid. │   │
│  │ • DDoS Protect  │ │ • RBAC          │ │ • Sanitization  │   │
│  │ • Anomaly Det.  │ │ • Session Mgmt  │ │ • Encoding      │   │
│  └─────────────────┘ └─────────────────┘ └─────────────────┘   │
└─────────────────────────┬───────────────────────────────────────┘
                          │
┌─────────────────────────▼───────────────────────────────────────┐
│                Infrastructure Security Layer                    │
│                                                                 │
│  ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐   │
│  │   Network       │ │   Data          │ │   Monitoring    │   │
│  │   Security      │ │   Protection    │ │   & Alerting    │   │
│  │                 │ │                 │ │                 │   │
│  │ • VPC/Subnets   │ │ • Encryption    │ │ • CloudWatch    │   │
│  │ • Security Grps │ │ • Key Mgmt      │ │ • GuardDuty     │   │
│  │ • WAF/Shield    │ │ • Backup/Recov  │ │ • Security Hub  │   │
│  └─────────────────┘ └─────────────────┘ └─────────────────┘   │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                    Compliance Framework                         │
│                                                                 │
│  ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐   │
│  │      GDPR       │ │      CCPA       │ │   Other Regs    │   │
│  │   Compliance    │ │   Compliance    │ │   (COPPA, etc)  │   │
│  │                 │ │                 │ │                 │   │
│  │ • Consent Mgmt  │ │ • Consumer      │ │ • Age Verify    │   │
│  │ • Data Rights   │ │   Rights        │ │ • Disclaimers   │   │
│  │ • Breach Notify │ │ • Opt-out       │ │ • Terms/Privacy │   │
│  └─────────────────┘ └─────────────────┘ └─────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

## Component Design

### 1. Content Filtering and Safety

#### Enhanced Bedrock Guardrails Configuration
```python
# app/services/content_filter_service.py
import boto3
import json
from typing import Dict, List, Optional, Tuple
from app.models.content import ContentFilterResult, FilterReason
from app.config import settings

class ContentFilterService:
    def __init__(self):
        self.bedrock_client = boto3.client('bedrock-runtime')
        self.guardrails_id = settings.bedrock_guardrails_id
        self.custom_filters = self._load_custom_filters()
    
    async def filter_input(self, content: str, user_id: str) -> ContentFilterResult:
        """Filter user input through multiple layers"""
        
        # Layer 1: Custom pre-filters
        custom_result = await self._apply_custom_filters(content)
        if custom_result.blocked:
            return custom_result
        
        # Layer 2: Bedrock Guardrails
        bedrock_result = await self._apply_bedrock_guardrails(content, "input")
        if bedrock_result.blocked:
            return bedrock_result
        
        # Layer 3: PII Detection
        pii_result = await self._detect_and_redact_pii(content)
        
        # Log filtering attempt
        await self._log_filter_attempt(user_id, content, [custom_result, bedrock_result, pii_result])
        
        return ContentFilterResult(
            blocked=False,
            filtered_content=pii_result.filtered_content,
            reasons=[],
            confidence=1.0
        )
    
    async def filter_output(self, content: str, context: Dict) -> ContentFilterResult:
        """Filter AI-generated output"""
        
        # Apply Bedrock Guardrails for output
        result = await self._apply_bedrock_guardrails(content, "output")
        
        # Additional theological content validation
        theological_result = await self._validate_theological_content(content)
        
        if result.blocked or theological_result.blocked:
            return ContentFilterResult(
                blocked=True,
                filtered_content="",
                reasons=result.reasons + theological_result.reasons,
                confidence=max(result.confidence, theological_result.confidence)
            )
        
        return ContentFilterResult(
            blocked=False,
            filtered_content=content,
            reasons=[],
            confidence=1.0
        )
    
    async def _apply_bedrock_guardrails(self, content: str, direction: str) -> ContentFilterResult:
        """Apply Amazon Bedrock Guardrails"""
        
        try:
            response = self.bedrock_client.apply_guardrail(
                guardrailIdentifier=self.guardrails_id,
                guardrailVersion="DRAFT",
                source=direction.upper(),
                content=[{
                    "text": {"text": content}
                }]
            )
            
            action = response.get('action', 'NONE')
            
            if action == 'GUARDRAIL_INTERVENED':
                return ContentFilterResult(
                    blocked=True,
                    filtered_content="",
                    reasons=[FilterReason.HARMFUL_CONTENT],
                    confidence=0.9,
                    details=response.get('assessments', [])
                )
            
            return ContentFilterResult(blocked=False, filtered_content=content)
            
        except Exception as e:
            logger.error(f"Bedrock Guardrails error: {e}")
            # Fail secure - block content if guardrails fail
            return ContentFilterResult(
                blocked=True,
                filtered_content="",
                reasons=[FilterReason.SYSTEM_ERROR],
                confidence=1.0
            )
    
    async def _detect_and_redact_pii(self, content: str) -> ContentFilterResult:
        """Detect and redact personally identifiable information"""
        
        import re
        
        # PII patterns
        patterns = {
            'ssn': r'\b\d{3}-?\d{2}-?\d{4}\b',
            'credit_card': r'\b\d{4}[- ]?\d{4}[- ]?\d{4}[- ]?\d{4}\b',
            'phone': r'\b\d{3}[- ]?\d{3}[- ]?\d{4}\b',
            'email': r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b'
        }
        
        filtered_content = content
        detected_pii = []
        
        for pii_type, pattern in patterns.items():
            matches = re.findall(pattern, content)
            if matches:
                detected_pii.append(pii_type)
                filtered_content = re.sub(pattern, f'[{pii_type.upper()}_REDACTED]', filtered_content)
        
        if detected_pii:
            return ContentFilterResult(
                blocked=False,  # Redact but don't block
                filtered_content=filtered_content,
                reasons=[FilterReason.PII_DETECTED],
                confidence=0.95,
                details={'detected_pii': detected_pii}
            )
        
        return ContentFilterResult(blocked=False, filtered_content=content)
    
    async def _validate_theological_content(self, content: str) -> ContentFilterResult:
        """Validate theological appropriateness of AI responses"""
        
        # Check for potentially problematic theological statements
        problematic_patterns = [
            r'god hates',
            r'you are condemned',
            r'unforgivable sin',
            r'god will punish you',
            r'you deserve hell'
        ]
        
        for pattern in problematic_patterns:
            if re.search(pattern, content.lower()):
                return ContentFilterResult(
                    blocked=True,
                    filtered_content="",
                    reasons=[FilterReason.THEOLOGICAL_CONCERN],
                    confidence=0.8
                )
        
        return ContentFilterResult(blocked=False, filtered_content=content)
    
    def _load_custom_filters(self) -> List[Dict]:
        """Load custom content filters"""
        return [
            {
                'name': 'profanity_filter',
                'patterns': ['damn', 'hell', 'shit'],  # Basic example
                'action': 'warn'
            },
            {
                'name': 'spam_filter',
                'patterns': [r'http[s]?://(?:[a-zA-Z]|[0-9]|[$-_@.&+]|[!*\\(\\),]|(?:%[0-9a-fA-F][0-9a-fA-F]))+'],
                'action': 'block'
            }
        ]
```

### 2. Privacy Management System

#### Privacy Service Implementation
```python
# app/services/privacy_service.py
import json
import asyncio
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Any
from app.services.db_service import DatabaseService
from app.models.privacy import DataExport, DeletionRequest, ConsentRecord

class PrivacyService:
    def __init__(self, db_service: DatabaseService):
        self.db_service = db_service
    
    async def export_user_data(self, user_id: str) -> DataExport:
        """Export all user data for GDPR/CCPA compliance"""
        
        export_data = {
            'user_profile': await self.db_service.get_user_profile(user_id),
            'conversations': await self.db_service.get_all_user_conversations(user_id),
            'prayer_requests': await self.db_service.get_all_user_prayer_requests(user_id),
            'consent_logs': await self.db_service.get_user_consent_logs(user_id),
            'audit_trail': await self.db_service.get_user_audit_trail(user_id)
        }
        
        # Create export record
        export_record = DataExport(
            export_id=f"export_{uuid.uuid4().hex[:8]}",
            user_id=user_id,
            requested_at=datetime.utcnow(),
            data=export_data,
            format="json"
        )
        
        # Log the export request
        await self._log_privacy_action(user_id, "data_export", export_record.export_id)
        
        return export_record
    
    async def delete_user_data(self, user_id: str, confirmation_token: str) -> DeletionRequest:
        """Delete all user data (Right to be Forgotten)"""
        
        # Verify confirmation token
        if not await self._verify_deletion_token(user_id, confirmation_token):
            raise ValueError("Invalid deletion confirmation token")
        
        deletion_request = DeletionRequest(
            deletion_id=f"del_{uuid.uuid4().hex[:8]}",
            user_id=user_id,
            requested_at=datetime.utcnow(),
            status="in_progress"
        )
        
        try:
            # Delete data in order (respecting foreign key constraints)
            await self.db_service.delete_user_conversations(user_id)
            await self.db_service.delete_user_prayer_requests(user_id)
            await self.db_service.delete_user_consent_logs(user_id)
            
            # Anonymize audit logs (keep for compliance but remove PII)
            await self.db_service.anonymize_user_audit_logs(user_id)
            
            # Finally delete user profile
            await self.db_service.delete_user_profile(user_id)
            
            deletion_request.status = "completed"
            deletion_request.completed_at = datetime.utcnow()
            
        except Exception as e:
            deletion_request.status = "failed"
            deletion_request.error = str(e)
            logger.error(f"Data deletion failed for user {user_id}: {e}")
            raise
        
        # Log the deletion (in separate audit system)
        await self._log_privacy_action(user_id, "data_deletion", deletion_request.deletion_id)
        
        return deletion_request
    
    async def revoke_consent(self, user_id: str, consent_type: str) -> ConsentRecord:
        """Revoke specific consent and stop related processing"""
        
        consent_record = ConsentRecord(
            consent_id=f"revoke_{uuid.uuid4().hex[:8]}",
            user_id=user_id,
            consent_type=consent_type,
            granted=False,
            timestamp=datetime.utcnow(),
            action="revoked"
        )
        
        # Store revocation
        await self.db_service.create_consent_log(consent_record)
        
        # Take action based on consent type
        if consent_type == "prayer_connect":
            await self._stop_prayer_connect_processing(user_id)
        elif consent_type == "data_processing":
            await self._limit_data_processing(user_id)
        
        await self._log_privacy_action(user_id, "consent_revoked", consent_type)
        
        return consent_record
    
    async def get_user_privacy_dashboard(self, user_id: str) -> Dict[str, Any]:
        """Get user's privacy dashboard with all privacy-related information"""
        
        return {
            'data_summary': await self._get_data_summary(user_id),
            'consent_status': await self._get_consent_status(user_id),
            'privacy_actions': await self._get_privacy_actions_history(user_id),
            'data_retention': await self._get_data_retention_info(user_id),
            'third_party_sharing': await self._get_sharing_status(user_id)
        }
    
    async def _verify_deletion_token(self, user_id: str, token: str) -> bool:
        """Verify deletion confirmation token"""
        # Implementation would check token validity and expiration
        return True  # Simplified for example
    
    async def _stop_prayer_connect_processing(self, user_id: str):
        """Stop all prayer connect processing for user"""
        # Cancel pending prayer requests
        await self.db_service.cancel_pending_prayer_requests(user_id)
        
        # Remove from future prayer connect offers
        await self.db_service.update_user_preferences(user_id, {
            'prayer_connect_enabled': False
        })
    
    async def _log_privacy_action(self, user_id: str, action: str, details: str):
        """Log privacy-related actions for audit"""
        await self.db_service.create_audit_log({
            'user_id': user_id,
            'action': action,
            'details': details,
            'timestamp': datetime.utcnow(),
            'category': 'privacy'
        })
```

### 3. Security Monitoring and Alerting

#### Security Monitoring Service
```python
# app/services/security_monitoring_service.py
import boto3
from datetime import datetime, timedelta
from typing import Dict, List, Optional
from app.models.security import SecurityEvent, ThreatLevel, SecurityMetrics

class SecurityMonitoringService:
    def __init__(self):
        self.cloudwatch = boto3.client('cloudwatch')
        self.sns = boto3.client('sns')
        self.security_topic_arn = settings.security_alerts_topic_arn
    
    async def log_security_event(
        self, 
        event_type: str, 
        user_id: Optional[str], 
        details: Dict,
        threat_level: ThreatLevel = ThreatLevel.LOW
    ):
        """Log security event and trigger alerts if necessary"""
        
        event = SecurityEvent(
            event_id=f"sec_{uuid.uuid4().hex[:8]}",
            event_type=event_type,
            user_id=user_id,
            timestamp=datetime.utcnow(),
            details=details,
            threat_level=threat_level,
            source_ip=details.get('ip_address'),
            user_agent=details.get('user_agent')
        )
        
        # Store event
        await self._store_security_event(event)
        
        # Send metrics to CloudWatch
        await self._send_security_metrics(event)
        
        # Check if alert is needed
        if threat_level in [ThreatLevel.HIGH, ThreatLevel.CRITICAL]:
            await self._send_security_alert(event)
        
        # Check for patterns that might indicate attack
        await self._analyze_security_patterns(event)
    
    async def detect_rate_limit_violations(self, user_id: str, endpoint: str) -> bool:
        """Detect if user is violating rate limits"""
        
        # Get recent requests for this user/endpoint
        recent_requests = await self._get_recent_requests(user_id, endpoint, minutes=1)
        
        # Define rate limits per endpoint
        rate_limits = {
            '/chat/message': 10,
            '/prayer/request': 3,
            '/auth/login': 5
        }
        
        limit = rate_limits.get(endpoint, 60)  # Default limit
        
        if len(recent_requests) > limit:
            await self.log_security_event(
                'rate_limit_violation',
                user_id,
                {
                    'endpoint': endpoint,
                    'request_count': len(recent_requests),
                    'limit': limit,
                    'time_window': '1_minute'
                },
                ThreatLevel.MEDIUM
            )
            return True
        
        return False
    
    async def detect_suspicious_activity(self, user_id: str, activity_data: Dict) -> List[str]:
        """Detect suspicious user activity patterns"""
        
        suspicious_indicators = []
        
        # Check for rapid account creation and usage
        if await self._is_new_account_high_activity(user_id):
            suspicious_indicators.append('new_account_high_activity')
        
        # Check for unusual geographic patterns
        if await self._detect_geographic_anomalies(user_id, activity_data.get('ip_address')):
            suspicious_indicators.append('geographic_anomaly')
        
        # Check for bot-like behavior
        if await self._detect_bot_behavior(user_id, activity_data):
            suspicious_indicators.append('bot_behavior')
        
        # Check for content injection attempts
        if await self._detect_injection_attempts(activity_data.get('content', '')):
            suspicious_indicators.append('injection_attempt')
        
        if suspicious_indicators:
            await self.log_security_event(
                'suspicious_activity',
                user_id,
                {
                    'indicators': suspicious_indicators,
                    'activity_data': activity_data
                },
                ThreatLevel.MEDIUM
            )
        
        return suspicious_indicators
    
    async def generate_security_report(self, start_date: datetime, end_date: datetime) -> Dict:
        """Generate security report for specified time period"""
        
        events = await self._get_security_events(start_date, end_date)
        
        report = {
            'period': {
                'start': start_date.isoformat(),
                'end': end_date.isoformat()
            },
            'summary': {
                'total_events': len(events),
                'by_threat_level': self._group_by_threat_level(events),
                'by_event_type': self._group_by_event_type(events),
                'unique_users_affected': len(set(e.user_id for e in events if e.user_id))
            },
            'top_threats': self._get_top_threats(events),
            'recommendations': self._generate_security_recommendations(events)
        }
        
        return report
    
    async def _send_security_alert(self, event: SecurityEvent):
        """Send security alert via SNS"""
        
        message = {
            'alert_type': 'security_event',
            'event_id': event.event_id,
            'event_type': event.event_type,
            'threat_level': event.threat_level.value,
            'timestamp': event.timestamp.isoformat(),
            'user_id': event.user_id,
            'details': event.details
        }
        
        try:
            self.sns.publish(
                TopicArn=self.security_topic_arn,
                Subject=f"Security Alert: {event.event_type} ({event.threat_level.value})",
                Message=json.dumps(message, indent=2)
            )
        except Exception as e:
            logger.error(f"Failed to send security alert: {e}")
    
    async def _analyze_security_patterns(self, event: SecurityEvent):
        """Analyze patterns that might indicate coordinated attacks"""
        
        # Look for multiple failed login attempts from same IP
        if event.event_type == 'failed_authentication':
            recent_failures = await self._get_recent_auth_failures(event.source_ip, minutes=5)
            if len(recent_failures) > 10:
                await self.log_security_event(
                    'brute_force_attempt',
                    None,
                    {
                        'source_ip': event.source_ip,
                        'failure_count': len(recent_failures),
                        'time_window': '5_minutes'
                    },
                    ThreatLevel.HIGH
                )
        
        # Look for content filtering bypass attempts
        if event.event_type == 'content_filtered':
            recent_attempts = await self._get_recent_filter_attempts(event.user_id, minutes=10)
            if len(recent_attempts) > 5:
                await self.log_security_event(
                    'filter_bypass_attempt',
                    event.user_id,
                    {
                        'attempt_count': len(recent_attempts),
                        'time_window': '10_minutes'
                    },
                    ThreatLevel.MEDIUM
                )
```

### 4. Compliance Management System

#### GDPR Compliance Service
```python
# app/services/gdpr_compliance_service.py
from datetime import datetime, timedelta
from typing import Dict, List, Optional
from app.models.compliance import GDPRRequest, ComplianceStatus, DataProcessingRecord

class GDPRComplianceService:
    def __init__(self, privacy_service: PrivacyService):
        self.privacy_service = privacy_service
    
    async def handle_data_subject_request(
        self, 
        user_id: str, 
        request_type: str, 
        details: Dict
    ) -> GDPRRequest:
        """Handle GDPR data subject requests"""
        
        request = GDPRRequest(
            request_id=f"gdpr_{uuid.uuid4().hex[:8]}",
            user_id=user_id,
            request_type=request_type,  # access, rectification, erasure, portability, restriction
            submitted_at=datetime.utcnow(),
            status="received",
            details=details
        )
        
        # Process based on request type
        if request_type == "access":
            await self._handle_access_request(request)
        elif request_type == "erasure":
            await self._handle_erasure_request(request)
        elif request_type == "portability":
            await self._handle_portability_request(request)
        elif request_type == "rectification":
            await self._handle_rectification_request(request)
        elif request_type == "restriction":
            await self._handle_restriction_request(request)
        
        return request
    
    async def assess_lawful_basis(self, processing_purpose: str, user_id: str) -> Dict:
        """Assess lawful basis for data processing under GDPR Article 6"""
        
        lawful_bases = {
            'chat_functionality': 'legitimate_interest',  # Article 6(1)(f)
            'prayer_connect': 'consent',  # Article 6(1)(a)
            'crisis_response': 'vital_interests',  # Article 6(1)(d)
            'legal_compliance': 'legal_obligation',  # Article 6(1)(c)
            'account_management': 'contract',  # Article 6(1)(b)
        }
        
        basis = lawful_bases.get(processing_purpose, 'consent')
        
        # Check if consent is still valid for consent-based processing
        if basis == 'consent':
            consent_valid = await self._check_consent_validity(user_id, processing_purpose)
            if not consent_valid:
                return {
                    'lawful_basis': None,
                    'status': 'invalid',
                    'action_required': 'obtain_new_consent'
                }
        
        return {
            'lawful_basis': basis,
            'status': 'valid',
            'article': self._get_article_reference(basis)
        }
    
    async def conduct_dpia(self, processing_activity: str) -> Dict:
        """Conduct Data Protection Impact Assessment"""
        
        # DPIA template based on GDPR Article 35
        dpia = {
            'activity': processing_activity,
            'conducted_at': datetime.utcnow(),
            'necessity_assessment': await self._assess_necessity(processing_activity),
            'proportionality_assessment': await self._assess_proportionality(processing_activity),
            'risk_assessment': await self._assess_privacy_risks(processing_activity),
            'safeguards': await self._identify_safeguards(processing_activity),
            'conclusion': None,
            'review_date': datetime.utcnow() + timedelta(days=365)
        }
        
        # Determine if processing can proceed
        high_risk_factors = dpia['risk_assessment']['high_risk_factors']
        if len(high_risk_factors) > 2:
            dpia['conclusion'] = 'high_risk_requires_consultation'
        elif len(high_risk_factors) > 0:
            dpia['conclusion'] = 'medium_risk_additional_safeguards'
        else:
            dpia['conclusion'] = 'low_risk_can_proceed'
        
        return dpia
    
    async def generate_compliance_report(self) -> Dict:
        """Generate GDPR compliance report"""
        
        return {
            'report_date': datetime.utcnow(),
            'data_processing_activities': await self._get_processing_activities(),
            'consent_management': await self._get_consent_statistics(),
            'data_subject_requests': await self._get_dsr_statistics(),
            'breach_incidents': await self._get_breach_statistics(),
            'privacy_by_design_measures': await self._get_privacy_measures(),
            'staff_training': await self._get_training_records(),
            'third_party_processors': await self._get_processor_agreements(),
            'recommendations': await self._generate_compliance_recommendations()
        }
    
    async def _handle_access_request(self, request: GDPRRequest):
        """Handle GDPR Article 15 - Right of access"""
        
        try:
            # Export all user data
            data_export = await self.privacy_service.export_user_data(request.user_id)
            
            request.status = "completed"
            request.completed_at = datetime.utcnow()
            request.response_data = {
                'export_id': data_export.export_id,
                'data_categories': list(data_export.data.keys()),
                'processing_purposes': await self._get_processing_purposes(request.user_id),
                'retention_periods': await self._get_retention_periods(),
                'third_party_recipients': await self._get_third_party_recipients(request.user_id)
            }
            
        except Exception as e:
            request.status = "failed"
            request.error = str(e)
    
    async def _handle_erasure_request(self, request: GDPRRequest):
        """Handle GDPR Article 17 - Right to erasure"""
        
        # Check if erasure is legally required or if there are grounds to refuse
        erasure_assessment = await self._assess_erasure_request(request)
        
        if erasure_assessment['can_erase']:
            try:
                deletion_request = await self.privacy_service.delete_user_data(
                    request.user_id, 
                    request.details.get('confirmation_token')
                )
                
                request.status = "completed"
                request.completed_at = datetime.utcnow()
                request.response_data = {
                    'deletion_id': deletion_request.deletion_id,
                    'data_deleted': True,
                    'retention_exceptions': erasure_assessment.get('exceptions', [])
                }
                
            except Exception as e:
                request.status = "failed"
                request.error = str(e)
        else:
            request.status = "refused"
            request.response_data = {
                'refusal_reason': erasure_assessment['refusal_reason'],
                'legal_basis': erasure_assessment['legal_basis']
            }
```

## Security Controls Implementation

### Rate Limiting and DDoS Protection
```python
# app/middleware/rate_limiting.py
from fastapi import Request, HTTPException
from fastapi.responses import JSONResponse
import redis
from datetime import datetime, timedelta

class RateLimitingMiddleware:
    def __init__(self):
        self.redis_client = redis.Redis(host=settings.redis_host, port=settings.redis_port)
        
        # Rate limits per endpoint
        self.rate_limits = {
            '/chat/message': {'requests': 10, 'window': 60},  # 10 per minute
            '/prayer/request': {'requests': 3, 'window': 86400},  # 3 per day
            '/auth/login': {'requests': 5, 'window': 300},  # 5 per 5 minutes
            'default': {'requests': 60, 'window': 60}  # 60 per minute default
        }
    
    async def __call__(self, request: Request, call_next):
        # Get user identifier (IP or user ID)
        user_id = getattr(request.state, 'user_id', None)
        client_ip = request.client.host
        identifier = user_id or client_ip
        
        # Get rate limit for this endpoint
        endpoint = request.url.path
        limit_config = self.rate_limits.get(endpoint, self.rate_limits['default'])
        
        # Check rate limit
        if await self._is_rate_limited(identifier, endpoint, limit_config):
            return JSONResponse(
                status_code=429,
                content={
                    "error": "Rate limit exceeded",
                    "retry_after": limit_config['window']
                }
            )
        
        # Record this request
        await self._record_request(identifier, endpoint, limit_config)
        
        response = await call_next(request)
        return response
    
    async def _is_rate_limited(self, identifier: str, endpoint: str, config: Dict) -> bool:
        key = f"rate_limit:{identifier}:{endpoint}"
        current_count = self.redis_client.get(key)
        
        if current_count is None:
            return False
        
        return int(current_count) >= config['requests']
    
    async def _record_request(self, identifier: str, endpoint: str, config: Dict):
        key = f"rate_limit:{identifier}:{endpoint}"
        
        # Increment counter
        pipe = self.redis_client.pipeline()
        pipe.incr(key)
        pipe.expire(key, config['window'])
        pipe.execute()
```

This comprehensive security and compliance design ensures the faith-based motivator chatbot meets the highest standards of data protection, content safety, and regulatory compliance while maintaining user trust and system integrity.