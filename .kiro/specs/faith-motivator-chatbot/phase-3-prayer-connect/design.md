# Phase 3: Prayer Connect System - Design Document

## Architecture Overview

Phase 3 implements the prayer connect system that enables users to request prayer support from community members. The system uses asynchronous processing to handle prayer requests without blocking the chat interface, integrates with Telegram for community notifications, and uses Amazon SES for email communications.

### System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Frontend (React/Next.js)                     │
│  ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐   │
│  │ Prayer Connect  │ │ Consent Modal   │ │ Request Status  │   │
│  │    Button       │ │                 │ │    Tracking     │   │
│  └─────────────────┘ └─────────────────┘ └─────────────────┘   │
└─────────────────────────┬───────────────────────────────────────┘
                          │ HTTPS/REST API
┌─────────────────────────▼───────────────────────────────────────┐
│                 FastAPI Backend (ECS Fargate)                   │
│  ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐   │
│  │ Prayer Router   │ │ Consent Service │ │ Request Service │   │
│  │ /prayer/*       │ │                 │ │                 │   │
│  └─────────────────┘ └─────────────────┘ └─────────────────┘   │
│                          │                        │             │
│                          ▼                        ▼             │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │              Prayer Request Processing                      │ │
│  │  1. Validate → 2. Store → 3. Queue → 4. Confirm           │ │
│  └─────────────────────────────────────────────────────────────┘ │
└─────────────────────────┬───────────────────────────────────────┘
                          │ SQS Message
┌─────────────────────────▼───────────────────────────────────────┐
│                    SQS Prayer Queue                             │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │ Message: {request_id, user_email, timestamp, consent}      │ │
│  └─────────────────────────────────────────────────────────────┘ │
└─────────────────────────┬───────────────────────────────────────┘
                          │ Lambda Trigger
┌─────────────────────────▼───────────────────────────────────────┐
│              Lambda Prayer Request Processor                    │
│  ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐   │
│  │ Message Parser  │ │ Telegram Client │ │ SES Email       │   │
│  │                 │ │                 │ │ Service         │   │
│  └─────────────────┘ └─────────────────┘ └─────────────────┘   │
│                          │                        │             │
│                          ▼                        ▼             │
│  ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐   │
│  │ Format Message  │ │ Send to Group   │ │ Send Confirmation│   │
│  │ for Community   │ │                 │ │ to User         │   │
│  └─────────────────┘ └─────────────────┘ └─────────────────┘   │
└─────────────────────────┬───────────────────┬───────────────────┘
                          │                   │
┌─────────────────────────▼───────────────────▼───────────────────┐
│  ┌─────────────────┐                   ┌─────────────────┐       │
│  │ Telegram Prayer │                   │ Amazon SES      │       │
│  │ Group           │                   │ (Email Service) │       │
│  │                 │                   │                 │       │
│  │ Community       │                   │ User Email      │       │
│  │ Members         │                   │ Confirmations   │       │
│  └─────────────────┘                   └─────────────────┘       │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                      DynamoDB Tables                            │
│  ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐   │
│  │ PrayerRequests  │ │ ConsentLogs     │ │ CommunityMembers│   │
│  │                 │ │                 │ │ (Future)        │   │
│  └─────────────────┘ └─────────────────┘ └─────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

## Component Design

### 1. Prayer Request API Implementation

#### Prayer Router
```python
# app/routers/prayer.py
from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks
from app.models.prayer import PrayerRequest, PrayerRequestCreate, ConsentData
from app.services.prayer_service import PrayerService
from app.services.consent_service import ConsentService
from app.dependencies import get_current_user, get_prayer_service

router = APIRouter(prefix="/prayer", tags=["prayer"])

@router.post("/request", response_model=PrayerRequest)
async def create_prayer_request(
    request_data: PrayerRequestCreate,
    background_tasks: BackgroundTasks,
    current_user: User = Depends(get_current_user),
    prayer_service: PrayerService = Depends(get_prayer_service)
):
    """Create a new prayer request with explicit consent"""
    
    # Validate consent
    if not request_data.consent_confirmed:
        raise HTTPException(
            status_code=400,
            detail="Explicit consent required for prayer requests"
        )
    
    # Check rate limiting (3 requests per day)
    await prayer_service.check_daily_limit(current_user.user_id)
    
    # Create prayer request
    prayer_request = await prayer_service.create_request(
        user_id=current_user.user_id,
        user_email=current_user.email,
        consent_data=request_data.consent,
        message=request_data.message
    )
    
    # Process asynchronously
    background_tasks.add_task(
        prayer_service.queue_for_processing,
        prayer_request.request_id
    )
    
    return prayer_request

@router.get("/status/{request_id}", response_model=PrayerRequest)
async def get_prayer_request_status(
    request_id: str,
    current_user: User = Depends(get_current_user),
    prayer_service: PrayerService = Depends(get_prayer_service)
):
    """Get status of a specific prayer request"""
    
    request = await prayer_service.get_request(request_id)
    
    # Verify ownership
    if request.user_id != current_user.user_id:
        raise HTTPException(status_code=403, detail="Access denied")
    
    return request

@router.get("/history", response_model=List[PrayerRequest])
async def get_prayer_request_history(
    limit: int = 20,
    offset: int = 0,
    current_user: User = Depends(get_current_user),
    prayer_service: PrayerService = Depends(get_prayer_service)
):
    """Get user's prayer request history"""
    
    return await prayer_service.get_user_requests(
        user_id=current_user.user_id,
        limit=limit,
        offset=offset
    )

@router.post("/consent", response_model=dict)
async def log_consent(
    consent_data: ConsentData,
    current_user: User = Depends(get_current_user),
    consent_service: ConsentService = Depends(get_consent_service)
):
    """Log user consent for prayer connect"""
    
    consent_log = await consent_service.log_consent(
        user_id=current_user.user_id,
        action="prayer_connect_consent",
        granted=consent_data.granted,
        purpose=consent_data.purpose,
        details=consent_data.details
    )
    
    return {"consent_logged": True, "log_id": consent_log.log_id}
```

#### Data Models
```python
# app/models/prayer.py
from typing import Optional, List, Dict, Any
from pydantic import BaseModel, Field, EmailStr
from datetime import datetime
from enum import Enum

class PrayerRequestStatus(str, Enum):
    PENDING = "pending"
    QUEUED = "queued"
    SENT = "sent"
    RESPONDED = "responded"
    CLOSED = "closed"
    FAILED = "failed"

class ConsentData(BaseModel):
    granted: bool
    purpose: str
    details: Dict[str, Any]
    ip_address: Optional[str] = None
    user_agent: Optional[str] = None

class PrayerRequestCreate(BaseModel):
    message: Optional[str] = Field(None, max_length=500)
    consent_confirmed: bool
    consent: ConsentData

class PrayerRequest(BaseModel):
    request_id: str
    user_id: str
    user_email: EmailStr
    status: PrayerRequestStatus
    message: Optional[str] = None
    created_at: datetime
    updated_at: datetime
    sent_at: Optional[datetime] = None
    responded_at: Optional[datetime] = None
    telegram_message_id: Optional[str] = None
    community_member_id: Optional[str] = None
    response_notes: Optional[str] = None

class PrayerRequestHistory(BaseModel):
    requests: List[PrayerRequest]
    total_count: int
    has_more: bool
```

### 2. Prayer Service Implementation

```python
# app/services/prayer_service.py
import uuid
import boto3
from datetime import datetime, timedelta
from typing import Optional, List
from app.models.prayer import PrayerRequest, PrayerRequestStatus, ConsentData
from app.services.db_service import DatabaseService
from app.services.consent_service import ConsentService
from app.utils.rate_limiter import DailyRateLimiter

class PrayerService:
    def __init__(
        self,
        db_service: DatabaseService,
        consent_service: ConsentService,
        sqs_client: boto3.client
    ):
        self.db_service = db_service
        self.consent_service = consent_service
        self.sqs_client = sqs_client
        self.queue_url = settings.sqs_prayer_queue_url
        self.rate_limiter = DailyRateLimiter(max_requests=3)
    
    async def create_request(
        self,
        user_id: str,
        user_email: str,
        consent_data: ConsentData,
        message: Optional[str] = None
    ) -> PrayerRequest:
        """Create a new prayer request"""
        
        request_id = f"pr_{uuid.uuid4().hex[:8]}"
        now = datetime.utcnow()
        
        # Log consent
        await self.consent_service.log_consent(
            user_id=user_id,
            action="prayer_connect_consent",
            granted=consent_data.granted,
            purpose=consent_data.purpose,
            details=consent_data.details
        )
        
        # Create prayer request record
        prayer_request = PrayerRequest(
            request_id=request_id,
            user_id=user_id,
            user_email=user_email,
            status=PrayerRequestStatus.PENDING,
            message=message,
            created_at=now,
            updated_at=now
        )
        
        # Store in database
        await self.db_service.create_prayer_request(prayer_request)
        
        return prayer_request
    
    async def queue_for_processing(self, request_id: str):
        """Queue prayer request for asynchronous processing"""
        
        request = await self.db_service.get_prayer_request(request_id)
        
        # Update status to queued
        await self.update_request_status(request_id, PrayerRequestStatus.QUEUED)
        
        # Send to SQS queue
        message_body = {
            "request_id": request.request_id,
            "user_id": request.user_id,
            "user_email": request.user_email,
            "user_name": await self._get_user_display_name(request.user_id),
            "message": request.message,
            "timestamp": request.created_at.isoformat(),
            "consent_confirmed": True
        }
        
        try:
            response = self.sqs_client.send_message(
                QueueUrl=self.queue_url,
                MessageBody=json.dumps(message_body),
                MessageAttributes={
                    'RequestId': {
                        'StringValue': request.request_id,
                        'DataType': 'String'
                    },
                    'Priority': {
                        'StringValue': 'normal',
                        'DataType': 'String'
                    }
                }
            )
            
            logger.info(
                "Prayer request queued successfully",
                request_id=request.request_id,
                message_id=response['MessageId']
            )
            
        except Exception as e:
            logger.error(
                "Failed to queue prayer request",
                request_id=request.request_id,
                error=str(e)
            )
            await self.update_request_status(request_id, PrayerRequestStatus.FAILED)
            raise
    
    async def get_request(self, request_id: str) -> PrayerRequest:
        """Get prayer request by ID"""
        return await self.db_service.get_prayer_request(request_id)
    
    async def get_user_requests(
        self,
        user_id: str,
        limit: int = 20,
        offset: int = 0
    ) -> List[PrayerRequest]:
        """Get prayer requests for a user"""
        return await self.db_service.get_user_prayer_requests(
            user_id, limit, offset
        )
    
    async def update_request_status(
        self,
        request_id: str,
        status: PrayerRequestStatus,
        **kwargs
    ):
        """Update prayer request status"""
        
        update_data = {
            "status": status,
            "updated_at": datetime.utcnow()
        }
        
        if status == PrayerRequestStatus.SENT:
            update_data["sent_at"] = datetime.utcnow()
        elif status == PrayerRequestStatus.RESPONDED:
            update_data["responded_at"] = datetime.utcnow()
        
        # Add any additional fields
        update_data.update(kwargs)
        
        await self.db_service.update_prayer_request(request_id, update_data)
    
    async def check_daily_limit(self, user_id: str):
        """Check if user has exceeded daily prayer request limit"""
        if not await self.rate_limiter.is_allowed(user_id):
            raise HTTPException(
                status_code=429,
                detail="Daily prayer request limit exceeded. Please try again tomorrow."
            )
    
    async def _get_user_display_name(self, user_id: str) -> str:
        """Get user's display name for community notifications"""
        user_profile = await self.db_service.get_user_profile(user_id)
        
        if user_profile and user_profile.first_name:
            return user_profile.first_name
        
        return "Anonymous"
```

### 3. Lambda Prayer Request Processor

```python
# lambda/prayer_processor/handler.py
import json
import boto3
import requests
from datetime import datetime
from typing import Dict, Any
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
dynamodb = boto3.resource('dynamodb')
ses_client = boto3.client('ses')
secrets_client = boto3.client('secretsmanager')

# Get configuration
PRAYER_REQUESTS_TABLE = os.environ['PRAYER_REQUESTS_TABLE']
TELEGRAM_BOT_TOKEN_SECRET = os.environ['TELEGRAM_BOT_TOKEN_SECRET']
TELEGRAM_CHAT_ID = os.environ['TELEGRAM_CHAT_ID']
FROM_EMAIL = os.environ['FROM_EMAIL']

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """Process prayer requests from SQS queue"""
    
    processed_count = 0
    failed_count = 0
    
    for record in event['Records']:
        try:
            # Parse SQS message
            message_body = json.loads(record['body'])
            request_id = message_body['request_id']
            
            logger.info(f"Processing prayer request: {request_id}")
            
            # Process the prayer request
            await process_prayer_request(message_body)
            
            processed_count += 1
            
        except Exception as e:
            logger.error(f"Failed to process prayer request: {e}")
            failed_count += 1
            # Let SQS handle retry logic
            raise
    
    return {
        'statusCode': 200,
        'body': json.dumps({
            'processed': processed_count,
            'failed': failed_count
        })
    }

async def process_prayer_request(request_data: Dict[str, Any]):
    """Process individual prayer request"""
    
    request_id = request_data['request_id']
    
    try:
        # 1. Send Telegram notification
        telegram_message_id = await send_telegram_notification(request_data)
        
        # 2. Send email confirmation to user
        await send_user_confirmation_email(request_data)
        
        # 3. Update request status
        await update_request_status(
            request_id,
            'sent',
            telegram_message_id=telegram_message_id,
            sent_at=datetime.utcnow().isoformat()
        )
        
        logger.info(f"Successfully processed prayer request: {request_id}")
        
    except Exception as e:
        logger.error(f"Failed to process prayer request {request_id}: {e}")
        
        # Update status to failed
        await update_request_status(request_id, 'failed')
        raise

async def send_telegram_notification(request_data: Dict[str, Any]) -> str:
    """Send prayer request notification to Telegram group"""
    
    # Get Telegram bot token from Secrets Manager
    bot_token = await get_secret(TELEGRAM_BOT_TOKEN_SECRET)
    
    # Format message for community
    message = format_telegram_message(request_data)
    
    # Send to Telegram
    telegram_url = f"https://api.telegram.org/bot{bot_token}/sendMessage"
    
    payload = {
        'chat_id': TELEGRAM_CHAT_ID,
        'text': message,
        'parse_mode': 'Markdown',
        'disable_web_page_preview': True
    }
    
    response = requests.post(telegram_url, json=payload)
    response.raise_for_status()
    
    result = response.json()
    return str(result['result']['message_id'])

def format_telegram_message(request_data: Dict[str, Any]) -> str:
    """Format prayer request message for Telegram group"""
    
    message = "🙏 *Prayer Connect Request*\n\n"
    message += f"*Request ID:* {request_data['request_id']}\n"
    message += f"*Name:* {request_data['user_name']}\n"
    message += f"*Email:* {request_data['user_email']}\n"
    message += f"*Timestamp:* {request_data['timestamp']}\n\n"
    
    if request_data.get('message'):
        message += f"*Context:* {request_data['message'][:200]}...\n\n"
    
    message += "*Guidelines:*\n"
    message += "• Respond within 24-48 hours when possible\n"
    message += "• Send Google Meet link to the email above\n"
    message += "• Keep all conversations confidential\n"
    message += "• Refer complex situations to pastoral team\n"
    message += "• Reply to this message when you've reached out\n\n"
    
    message += "*Template Email:*\n"
    message += "_Hi [Name], I received your prayer request through our faith community. "
    message += "I'd love to pray with you. Here's a Google Meet link for us to connect: [LINK]. "
    message += "Looking forward to our time together. Blessings, [Your Name]_"
    
    return message

async def send_user_confirmation_email(request_data: Dict[str, Any]):
    """Send confirmation email to user"""
    
    subject = "Prayer Request Received - Faith Motivator"
    
    body_text = f"""
Dear {request_data['user_name']},

We've received your prayer request and have notified our prayer team. 
A community member will reach out to you via email within 24-48 hours 
with a Google Meet link for your prayer session.

Request ID: {request_data['request_id']}
Submitted: {request_data['timestamp']}

Thank you for trusting us with your prayer request. We're honored to 
pray with you during this time.

Blessings,
The Faith Motivator Team

---
This is an automated message. Please do not reply to this email.
If you need immediate assistance, please contact emergency services 
or call the National Suicide Prevention Lifeline at 988.
"""
    
    body_html = f"""
<html>
<body>
    <h2>Prayer Request Received</h2>
    
    <p>Dear {request_data['user_name']},</p>
    
    <p>We've received your prayer request and have notified our prayer team. 
    A community member will reach out to you via email within 24-48 hours 
    with a Google Meet link for your prayer session.</p>
    
    <p><strong>Request ID:</strong> {request_data['request_id']}<br>
    <strong>Submitted:</strong> {request_data['timestamp']}</p>
    
    <p>Thank you for trusting us with your prayer request. We're honored to 
    pray with you during this time.</p>
    
    <p>Blessings,<br>
    The Faith Motivator Team</p>
    
    <hr>
    <p><small>This is an automated message. Please do not reply to this email.
    If you need immediate assistance, please contact emergency services 
    or call the National Suicide Prevention Lifeline at 988.</small></p>
</body>
</html>
"""
    
    try:
        response = ses_client.send_email(
            Source=FROM_EMAIL,
            Destination={
                'ToAddresses': [request_data['user_email']]
            },
            Message={
                'Subject': {'Data': subject},
                'Body': {
                    'Text': {'Data': body_text},
                    'Html': {'Data': body_html}
                }
            }
        )
        
        logger.info(f"Confirmation email sent: {response['MessageId']}")
        
    except Exception as e:
        logger.error(f"Failed to send confirmation email: {e}")
        raise

async def update_request_status(request_id: str, status: str, **kwargs):
    """Update prayer request status in DynamoDB"""
    
    table = dynamodb.Table(PRAYER_REQUESTS_TABLE)
    
    update_expression = "SET #status = :status, updated_at = :updated_at"
    expression_values = {
        ':status': status,
        ':updated_at': datetime.utcnow().isoformat()
    }
    expression_names = {'#status': 'status'}
    
    # Add additional fields
    for key, value in kwargs.items():
        update_expression += f", {key} = :{key}"
        expression_values[f":{key}"] = value
    
    table.update_item(
        Key={'request_id': request_id},
        UpdateExpression=update_expression,
        ExpressionAttributeValues=expression_values,
        ExpressionAttributeNames=expression_names
    )

async def get_secret(secret_name: str) -> str:
    """Get secret from AWS Secrets Manager"""
    
    try:
        response = secrets_client.get_secret_value(SecretId=secret_name)
        return response['SecretString']
    except Exception as e:
        logger.error(f"Failed to get secret {secret_name}: {e}")
        raise
```

### 4. Frontend Prayer Connect Components

#### Prayer Connect Modal
```typescript
// src/components/prayer/PrayerConnectModal.tsx
import React, { useState } from 'react';
import { Modal } from '../common/Modal';
import { ConsentForm } from './ConsentForm';
import { ChatResponse } from '../../types/chat';

interface PrayerConnectModalProps {
  isOpen: boolean;
  onClose: () => void;
  onResponse: (accepted: boolean, consentData?: any) => void;
  response: ChatResponse;
}

export const PrayerConnectModal: React.FC<PrayerConnectModalProps> = ({
  isOpen,
  onClose,
  onResponse,
  response
}) => {
  const [step, setStep] = useState<'offer' | 'consent' | 'confirmation'>('offer');
  const [consentData, setConsentData] = useState(null);
  
  const handleAccept = () => {
    setStep('consent');
  };
  
  const handleDecline = () => {
    onResponse(false);
    onClose();
  };
  
  const handleConsentSubmit = (consent: any) => {
    setConsentData(consent);
    setStep('confirmation');
  };
  
  const handleFinalConfirm = () => {
    onResponse(true, consentData);
    onClose();
  };
  
  return (
    <Modal isOpen={isOpen} onClose={onClose} title="Prayer Connect">
      {step === 'offer' && (
        <div className="space-y-4">
          <div className="text-center">
            <div className="text-4xl mb-4">🙏</div>
            <h3 className="text-lg font-semibold text-gray-900 mb-2">
              Would you like prayer support?
            </h3>
            <p className="text-gray-600 mb-4">
              Our prayer team can connect with you for personal prayer and encouragement.
            </p>
          </div>
          
          <div className="bg-blue-50 rounded-lg p-4">
            <h4 className="font-medium text-blue-900 mb-2">What happens next:</h4>
            <ul className="text-sm text-blue-800 space-y-1">
              <li>• We'll share your email with our prayer team</li>
              <li>• A community member will email you within 24-48 hours</li>
              <li>• They'll include a Google Meet link for your prayer session</li>
              <li>• Your conversation content stays private</li>
            </ul>
          </div>
          
          <div className="flex space-x-3">
            <button
              onClick={handleAccept}
              className="flex-1 bg-blue-600 text-white py-2 px-4 rounded-lg hover:bg-blue-700 transition-colors"
            >
              Yes, I'd like prayer support
            </button>
            <button
              onClick={handleDecline}
              className="flex-1 bg-gray-200 text-gray-800 py-2 px-4 rounded-lg hover:bg-gray-300 transition-colors"
            >
              No, thank you
            </button>
          </div>
        </div>
      )}
      
      {step === 'consent' && (
        <ConsentForm
          onSubmit={handleConsentSubmit}
          onCancel={() => setStep('offer')}
        />
      )}
      
      {step === 'confirmation' && (
        <div className="space-y-4 text-center">
          <div className="text-4xl mb-4">✅</div>
          <h3 className="text-lg font-semibold text-gray-900 mb-2">
            Prayer Request Submitted
          </h3>
          <p className="text-gray-600 mb-4">
            Thank you for your trust. A community member will reach out to you 
            via email within 24-48 hours with a Google Meet link.
          </p>
          <button
            onClick={handleFinalConfirm}
            className="w-full bg-blue-600 text-white py-2 px-4 rounded-lg hover:bg-blue-700 transition-colors"
          >
            Continue Chatting
          </button>
        </div>
      )}
    </Modal>
  );
};
```

#### Consent Form Component
```typescript
// src/components/prayer/ConsentForm.tsx
import React, { useState } from 'react';

interface ConsentFormProps {
  onSubmit: (consentData: any) => void;
  onCancel: () => void;
}

export const ConsentForm: React.FC<ConsentFormProps> = ({ onSubmit, onCancel }) => {
  const [consents, setConsents] = useState({
    shareEmail: false,
    understandProcess: false,
    confirmAge: false
  });
  
  const [additionalMessage, setAdditionalMessage] = useState('');
  
  const allConsentsGiven = Object.values(consents).every(Boolean);
  
  const handleConsentChange = (key: string, value: boolean) => {
    setConsents(prev => ({ ...prev, [key]: value }));
  };
  
  const handleSubmit = () => {
    if (!allConsentsGiven) return;
    
    const consentData = {
      granted: true,
      purpose: "Share email address with prayer team for Google Meet invitation",
      details: {
        shareEmail: consents.shareEmail,
        understandProcess: consents.understandProcess,
        confirmAge: consents.confirmAge,
        additionalMessage: additionalMessage.trim() || null,
        timestamp: new Date().toISOString(),
        ip_address: null, // Will be set by backend
        user_agent: navigator.userAgent
      }
    };
    
    onSubmit(consentData);
  };
  
  return (
    <div className="space-y-4">
      <div>
        <h3 className="text-lg font-semibold text-gray-900 mb-2">
          Consent for Prayer Connect
        </h3>
        <p className="text-sm text-gray-600 mb-4">
          Please review and confirm your understanding:
        </p>
      </div>
      
      <div className="space-y-3">
        <label className="flex items-start space-x-3">
          <input
            type="checkbox"
            checked={consents.shareEmail}
            onChange={(e) => handleConsentChange('shareEmail', e.target.checked)}
            className="mt-1 h-4 w-4 text-blue-600 border-gray-300 rounded focus:ring-blue-500"
          />
          <span className="text-sm text-gray-700">
            I consent to sharing my email address with the prayer team so a 
            community member can send me a Google Meet link for prayer support.
          </span>
        </label>
        
        <label className="flex items-start space-x-3">
          <input
            type="checkbox"
            checked={consents.understandProcess}
            onChange={(e) => handleConsentChange('understandProcess', e.target.checked)}
            className="mt-1 h-4 w-4 text-blue-600 border-gray-300 rounded focus:ring-blue-500"
          />
          <span className="text-sm text-gray-700">
            I understand that my conversation content will NOT be shared, 
            only my email address and that I requested prayer support.
          </span>
        </label>
        
        <label className="flex items-start space-x-3">
          <input
            type="checkbox"
            checked={consents.confirmAge}
            onChange={(e) => handleConsentChange('confirmAge', e.target.checked)}
            className="mt-1 h-4 w-4 text-blue-600 border-gray-300 rounded focus:ring-blue-500"
          />
          <span className="text-sm text-gray-700">
            I confirm that I am 18 years or older, or have parental consent 
            to participate in prayer support.
          </span>
        </label>
      </div>
      
      <div>
        <label className="block text-sm font-medium text-gray-700 mb-2">
          Additional context for prayer team (optional):
        </label>
        <textarea
          value={additionalMessage}
          onChange={(e) => setAdditionalMessage(e.target.value)}
          placeholder="Any specific prayer requests or context you'd like to share..."
          className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-blue-500 focus:border-blue-500"
          rows={3}
          maxLength={500}
        />
        <p className="text-xs text-gray-500 mt-1">
          {additionalMessage.length}/500 characters
        </p>
      </div>
      
      <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-3">
        <p className="text-xs text-yellow-800">
          <strong>Privacy Notice:</strong> Your email will only be used for this 
          prayer request. Community members are bound by confidentiality agreements. 
          You can revoke this consent at any time by contacting us.
        </p>
      </div>
      
      <div className="flex space-x-3">
        <button
          onClick={handleSubmit}
          disabled={!allConsentsGiven}
          className={`flex-1 py-2 px-4 rounded-lg transition-colors ${
            allConsentsGiven
              ? 'bg-blue-600 text-white hover:bg-blue-700'
              : 'bg-gray-300 text-gray-500 cursor-not-allowed'
          }`}
        >
          Submit Prayer Request
        </button>
        <button
          onClick={onCancel}
          className="flex-1 bg-gray-200 text-gray-800 py-2 px-4 rounded-lg hover:bg-gray-300 transition-colors"
        >
          Cancel
        </button>
      </div>
    </div>
  );
};
```

## Security Design

### Data Protection
- Prayer request data encrypted at rest in DynamoDB
- SQS messages encrypted with KMS keys
- Telegram bot token stored in AWS Secrets Manager
- Email content filtered for sensitive information

### Access Controls
- Prayer requests accessible only by request owner
- Lambda functions use least privilege IAM roles
- Telegram bot restricted to designated group only
- SES sending limited to verified domains

### Privacy Compliance
- Explicit consent required for all data sharing
- Conversation content never shared with community
- Audit trail for all consent and sharing actions
- User rights to access and delete their data

## Performance & Scalability

### Asynchronous Processing
- SQS queue decouples request creation from processing
- Lambda functions auto-scale based on queue depth
- Background processing doesn't block chat interface
- Dead letter queue handles persistent failures

### Rate Limiting
- 3 prayer requests per day per user
- Telegram API rate limiting compliance
- SES sending rate management
- Queue processing throttling

## Monitoring & Observability

### Metrics
- Prayer request success/failure rates
- Community response times and rates
- Email delivery success rates
- Telegram message delivery rates

### Alerting
- Failed prayer request processing
- High queue depth or processing delays
- Email delivery failures
- Telegram API errors

This design provides a comprehensive prayer connect system that maintains user privacy while enabling meaningful community support through secure, asynchronous processing.