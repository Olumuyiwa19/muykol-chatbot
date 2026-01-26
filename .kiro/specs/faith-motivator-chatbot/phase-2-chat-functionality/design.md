# Phase 2: Core Chat Functionality - Design Document

## Architecture Overview

Phase 2 builds the core chat functionality on the foundation established in Phase 1. This includes the chat API endpoints, message processing pipeline, crisis detection system, and the responsive React frontend that provides the user interface.

### System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Frontend (React/Next.js)                     │
│  ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐   │
│  │  Chat Interface │ │ Auth Components │ │ Prayer Connect  │   │
│  │                 │ │                 │ │     Modal       │   │
│  └─────────────────┘ └─────────────────┘ └─────────────────┘   │
└─────────────────────────┬───────────────────────────────────────┘
                          │ HTTPS/REST API
┌─────────────────────────▼───────────────────────────────────────┐
│                 FastAPI Backend (ECS Fargate)                   │
│  ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐   │
│  │  Chat Router    │ │ Message         │ │ Crisis Detection│   │
│  │  /chat/*        │ │ Processing      │ │ & Response      │   │
│  └─────────────────┘ └─────────────────┘ └─────────────────┘   │
│                          │                        │             │
│  ┌─────────────────┐     │     ┌─────────────────┐│             │
│  │ Auth Middleware │     │     │ Content         ││             │
│  │ (JWT Validation)│     │     │ Filtering       ││             │
│  └─────────────────┘     │     └─────────────────┘│             │
└───────────────────────────┼──────────────────────┼─────────────┘
                            │                      │
┌───────────────────────────▼──────────────────────▼─────────────┐
│                    Message Processing Pipeline                  │
│                                                                 │
│ 1. Input Validation → 2. Context Retrieval → 3. Emotion       │
│                                                Classification   │
│ 4. Crisis Detection → 5. Content Retrieval → 6. Response      │
│                                                Generation       │
│ 7. Prayer Connect → 8. Storage → 9. Return Response           │
│     Evaluation                                                  │
└─────────────────────────┬───────────────────────────────────────┘
                          │
┌─────────────────────────▼───────────────────────────────────────┐
│                    External Services                            │
│  ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐   │
│  │   Amazon        │ │   DynamoDB      │ │      SQS        │   │
│  │   Bedrock       │ │  (Conversations │ │ (Prayer Requests│   │
│  │ (Emotion + AI)  │ │   & Users)      │ │   - Future)     │   │
│  └─────────────────┘ └─────────────────┘ └─────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

## Component Design

### 1. Chat API Implementation

#### Chat Router Structure
```python
# app/routers/chat.py
from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks
from app.models.chat import ChatMessage, ChatResponse, ConversationHistory
from app.services.chat_service import ChatService
from app.dependencies import get_current_user, get_chat_service

router = APIRouter(prefix="/chat", tags=["chat"])

@router.post("/message", response_model=ChatResponse)
async def send_message(
    message: ChatMessage,
    background_tasks: BackgroundTasks,
    current_user: User = Depends(get_current_user),
    chat_service: ChatService = Depends(get_chat_service)
):
    """Process user message and return AI response"""
    
    # Rate limiting check
    await chat_service.check_rate_limit(current_user.user_id)
    
    # Process message through pipeline
    response = await chat_service.process_message(
        user_id=current_user.user_id,
        message=message.content,
        session_id=message.session_id
    )
    
    # Handle prayer connect request asynchronously if needed
    if response.prayer_connect_offered and message.request_prayer_connect:
        background_tasks.add_task(
            chat_service.initiate_prayer_request,
            current_user.user_id,
            response.session_id
        )
    
    return response

@router.get("/history", response_model=ConversationHistory)
async def get_conversation_history(
    session_id: Optional[str] = None,
    limit: int = 50,
    offset: int = 0,
    current_user: User = Depends(get_current_user),
    chat_service: ChatService = Depends(get_chat_service)
):
    """Retrieve user's conversation history"""
    
    return await chat_service.get_conversation_history(
        user_id=current_user.user_id,
        session_id=session_id,
        limit=limit,
        offset=offset
    )

@router.get("/session/{session_id}", response_model=ConversationSession)
async def get_conversation_session(
    session_id: str,
    current_user: User = Depends(get_current_user),
    chat_service: ChatService = Depends(get_chat_service)
):
    """Get specific conversation session"""
    
    session = await chat_service.get_conversation_session(session_id)
    
    # Verify user owns this session
    if session.user_id != current_user.user_id:
        raise HTTPException(status_code=403, detail="Access denied")
    
    return session
```

#### Data Models
```python
# app/models/chat.py
from typing import List, Optional, Dict, Any
from pydantic import BaseModel, Field
from datetime import datetime
from app.models.emotion import EmotionClassification

class ChatMessage(BaseModel):
    content: str = Field(..., min_length=1, max_length=2000)
    session_id: Optional[str] = None
    request_prayer_connect: bool = False

class BiblicalResponse(BaseModel):
    verse: Dict[str, str]  # reference, text, theme
    reflection: str
    action_step: str
    prayer_suggestion: Optional[str] = None

class ChatResponse(BaseModel):
    message_id: str
    session_id: str
    content: str
    biblical_response: BiblicalResponse
    emotion_classification: EmotionClassification
    prayer_connect_offered: bool = False
    crisis_response: bool = False
    timestamp: datetime

class ConversationMessage(BaseModel):
    id: str
    role: str  # "user" or "assistant"
    content: str
    timestamp: datetime
    emotion_classification: Optional[EmotionClassification] = None
    biblical_response: Optional[BiblicalResponse] = None

class ConversationHistory(BaseModel):
    sessions: List[Dict[str, Any]]
    total_count: int
    has_more: bool
```

### 2. Message Processing Pipeline

#### Chat Service Implementation
```python
# app/services/chat_service.py
import uuid
from datetime import datetime, timedelta
from typing import Optional, Dict, Any
from app.services.emotion_service import EmotionService
from app.services.biblical_content_service import BiblicalContentService
from app.services.crisis_service import CrisisService
from app.services.db_service import DatabaseService
from app.models.chat import ChatResponse, BiblicalResponse
from app.utils.rate_limiter import RateLimiter

class ChatService:
    def __init__(
        self,
        emotion_service: EmotionService,
        biblical_service: BiblicalContentService,
        crisis_service: CrisisService,
        db_service: DatabaseService
    ):
        self.emotion_service = emotion_service
        self.biblical_service = biblical_service
        self.crisis_service = crisis_service
        self.db_service = db_service
        self.rate_limiter = RateLimiter(max_requests=10, window_minutes=1)
    
    async def process_message(
        self, 
        user_id: str, 
        message: str, 
        session_id: Optional[str] = None
    ) -> ChatResponse:
        """Main message processing pipeline"""
        
        # 1. Input Validation
        validated_message = await self._validate_message(message)
        
        # 2. Session Management
        if not session_id:
            session_id = await self._create_new_session(user_id)
        
        # 3. Context Retrieval
        context = await self._get_conversation_context(session_id)
        
        # 4. Emotion Classification
        emotion_result = await self.emotion_service.classify_emotion(
            message=validated_message,
            context=context
        )
        
        # 5. Crisis Detection
        is_crisis = await self.crisis_service.detect_crisis(emotion_result)
        
        if is_crisis:
            return await self._handle_crisis_response(
                user_id, session_id, validated_message, emotion_result
            )
        
        # 6. Biblical Content Retrieval
        biblical_content = await self.biblical_service.get_content_for_emotion(
            emotion_result.primary_emotion,
            secondary_emotion=emotion_result.secondary_emotion
        )
        
        # 7. Response Generation
        response_content = await self._generate_response(
            emotion_result, biblical_content, context
        )
        
        # 8. Prayer Connect Evaluation
        offer_prayer_connect = await self._should_offer_prayer_connect(
            emotion_result, context
        )
        
        # 9. Storage
        message_id = str(uuid.uuid4())
        await self._store_conversation_turn(
            session_id, user_id, validated_message, response_content,
            emotion_result, biblical_content, message_id
        )
        
        # 10. Return Response
        return ChatResponse(
            message_id=message_id,
            session_id=session_id,
            content=response_content,
            biblical_response=BiblicalResponse(
                verse=biblical_content.verses[0].__dict__,
                reflection=biblical_content.reflections[0],
                action_step=biblical_content.action_steps[0],
                prayer_suggestion=biblical_content.prayers[0] if biblical_content.prayers else None
            ),
            emotion_classification=emotion_result,
            prayer_connect_offered=offer_prayer_connect,
            timestamp=datetime.utcnow()
        )
    
    async def _validate_message(self, message: str) -> str:
        """Validate and sanitize user message"""
        # Remove excessive whitespace
        cleaned = " ".join(message.split())
        
        # Basic length validation
        if len(cleaned) > 2000:
            raise ValueError("Message too long")
        
        if len(cleaned.strip()) == 0:
            raise ValueError("Message cannot be empty")
        
        return cleaned
    
    async def _get_conversation_context(self, session_id: str) -> str:
        """Retrieve recent conversation context"""
        session = await self.db_service.get_conversation_session(session_id)
        
        if not session or not session.messages:
            return ""
        
        # Get last 5 messages for context
        recent_messages = session.messages[-5:]
        context_parts = []
        
        for msg in recent_messages:
            role = "User" if msg.role == "user" else "Assistant"
            context_parts.append(f"{role}: {msg.content}")
        
        return "\n".join(context_parts)
    
    async def _generate_response(
        self, 
        emotion_result: EmotionClassification,
        biblical_content: BiblicalContent,
        context: str
    ) -> str:
        """Generate empathetic response with biblical encouragement"""
        
        # Build response using template
        empathy_statement = await self._generate_empathy_statement(emotion_result)
        
        verse = biblical_content.verses[0]
        reflection = biblical_content.reflections[0]
        action_step = biblical_content.action_steps[0]
        
        response = f"{empathy_statement}\n\n"
        response += f"I'm reminded of {verse.reference}: \"{verse.text}\"\n\n"
        response += f"{reflection}\n\n"
        response += f"Here's something you might try: {action_step}"
        
        return response
    
    async def _generate_empathy_statement(self, emotion_result: EmotionClassification) -> str:
        """Generate contextual empathy statement"""
        
        empathy_templates = {
            "anxiety": [
                "I can sense you're feeling anxious, and that's completely understandable.",
                "It sounds like you're carrying some worry right now.",
                "I hear the anxiety in your words, and I want you to know that's okay."
            ],
            "sadness": [
                "I can feel the sadness in what you're sharing.",
                "It sounds like you're going through a difficult time.",
                "I sense the heaviness you're carrying right now."
            ],
            "anger": [
                "I can hear the frustration and anger in your words.",
                "It sounds like something has really upset you.",
                "I understand you're feeling angry about this situation."
            ]
            # Add more emotions...
        }
        
        templates = empathy_templates.get(emotion_result.primary_emotion.value, [
            "I hear what you're going through.",
            "Thank you for sharing this with me.",
            "I can sense this is important to you."
        ])
        
        # Simple selection - could be enhanced with more sophisticated logic
        return templates[0]
    
    async def _should_offer_prayer_connect(
        self, 
        emotion_result: EmotionClassification, 
        context: str
    ) -> bool:
        """Determine if prayer connect should be offered"""
        
        # Offer prayer connect for moderate to severe distress
        high_distress_flags = [
            RiskFlag.MODERATE_DISTRESS,
            RiskFlag.SEVERE_DISTRESS
        ]
        
        if any(flag in emotion_result.risk_flags for flag in high_distress_flags):
            return True
        
        # Offer for certain emotions regardless of distress level
        prayer_connect_emotions = [
            PrimaryEmotion.GRIEF,
            PrimaryEmotion.LONELINESS,
            PrimaryEmotion.FEAR
        ]
        
        if emotion_result.primary_emotion in prayer_connect_emotions:
            return True
        
        return False
    
    async def check_rate_limit(self, user_id: str):
        """Check if user has exceeded rate limit"""
        if not await self.rate_limiter.is_allowed(user_id):
            raise HTTPException(
                status_code=429,
                detail="Too many messages. Please wait before sending another message."
            )
```

### 3. Crisis Detection and Response System

#### Crisis Service Implementation
```python
# app/services/crisis_service.py
from typing import List, Dict, Any
from app.models.emotion import EmotionClassification, RiskFlag
from app.models.chat import ChatResponse, BiblicalResponse

class CrisisService:
    def __init__(self):
        self.crisis_keywords = [
            "kill myself", "end it all", "don't want to live",
            "suicide", "hurt myself", "end my life",
            "not worth living", "better off dead"
        ]
        
        self.crisis_resources = {
            "suicide_prevention": {
                "name": "National Suicide Prevention Lifeline",
                "number": "988",
                "description": "24/7 crisis support"
            },
            "crisis_text": {
                "name": "Crisis Text Line",
                "number": "Text HOME to 741741",
                "description": "24/7 text-based crisis support"
            },
            "emergency": {
                "name": "Emergency Services",
                "number": "911",
                "description": "For immediate danger"
            }
        }
    
    async def detect_crisis(self, emotion_result: EmotionClassification) -> bool:
        """Detect if this is a crisis situation"""
        
        # Check for crisis risk flags
        if RiskFlag.CRISIS_INDICATORS in emotion_result.risk_flags:
            return True
        
        # Check for specific crisis indicators
        crisis_indicators = [
            "self_harm_intent",
            "suicide_ideation",
            "immediate_danger"
        ]
        
        if any(indicator in emotion_result.crisis_indicators for indicator in crisis_indicators):
            return True
        
        return False
    
    async def generate_crisis_response(
        self, 
        emotion_result: EmotionClassification
    ) -> ChatResponse:
        """Generate specialized crisis response"""
        
        crisis_content = self._build_crisis_content(emotion_result)
        
        return ChatResponse(
            message_id=str(uuid.uuid4()),
            session_id="crisis_session",  # Special handling
            content=crisis_content,
            biblical_response=self._get_crisis_biblical_response(),
            emotion_classification=emotion_result,
            prayer_connect_offered=True,
            crisis_response=True,
            timestamp=datetime.utcnow()
        )
    
    def _build_crisis_content(self, emotion_result: EmotionClassification) -> str:
        """Build crisis-specific response content"""
        
        content = "I'm deeply concerned about what you're sharing with me. "
        content += "Your life has immense value and meaning to God, and there are people who want to help you right now.\n\n"
        
        content += "**Immediate Resources:**\n"
        for resource in self.crisis_resources.values():
            content += f"• {resource['name']}: {resource['number']} - {resource['description']}\n"
        
        content += "\n**Please consider:**\n"
        content += "• Reaching out to a trusted friend, family member, or counselor\n"
        content += "• Going to your nearest emergency room if you're in immediate danger\n"
        content += "• Calling one of the numbers above - they have trained counselors ready to help\n\n"
        
        content += "Remember: This difficult moment is not your final story. "
        content += "God has plans for your life, and there are people who care about you deeply."
        
        return content
    
    def _get_crisis_biblical_response(self) -> BiblicalResponse:
        """Get biblical response appropriate for crisis situations"""
        
        return BiblicalResponse(
            verse={
                "reference": "Jeremiah 29:11",
                "text": "For I know the plans I have for you, declares the Lord, plans to prosper you and not to harm you, to give you hope and a future.",
                "theme": "hope_and_future"
            },
            reflection="Even in the darkest moments, God sees you and has not forgotten you. Your life has purpose and meaning that may not be clear right now, but God's love for you is constant and unchanging.",
            action_step="Please reach out to one of the crisis resources above or contact someone you trust. You don't have to face this alone.",
            prayer_suggestion="Lord, I'm struggling and need Your help. Please send people to support me and help me see hope again."
        )
```

### 4. Frontend React Application

#### Project Structure
```
frontend/
├── src/
│   ├── components/
│   │   ├── auth/
│   │   │   ├── LoginButton.tsx
│   │   │   ├── LogoutButton.tsx
│   │   │   └── ProtectedRoute.tsx
│   │   ├── chat/
│   │   │   ├── ChatInterface.tsx
│   │   │   ├── MessageBubble.tsx
│   │   │   ├── MessageInput.tsx
│   │   │   ├── ConversationHistory.tsx
│   │   │   └── LoadingIndicator.tsx
│   │   ├── prayer/
│   │   │   ├── PrayerConnectModal.tsx
│   │   │   ├── ConsentForm.tsx
│   │   │   └── PrayerRequestStatus.tsx
│   │   └── common/
│   │       ├── ErrorBoundary.tsx
│   │       ├── Layout.tsx
│   │       └── Header.tsx
│   ├── hooks/
│   │   ├── useAuth.ts
│   │   ├── useChat.ts
│   │   └── usePrayerConnect.ts
│   ├── services/
│   │   ├── api.ts
│   │   ├── auth.ts
│   │   └── chat.ts
│   ├── types/
│   │   ├── auth.ts
│   │   ├── chat.ts
│   │   └── prayer.ts
│   ├── utils/
│   │   ├── constants.ts
│   │   └── helpers.ts
│   └── pages/
│       ├── index.tsx
│       ├── chat.tsx
│       └── auth/
│           ├── login.tsx
│           └── callback.tsx
├── public/
├── styles/
└── next.config.js
```

#### Main Chat Interface Component
```typescript
// src/components/chat/ChatInterface.tsx
import React, { useState, useEffect, useRef } from 'react';
import { MessageBubble } from './MessageBubble';
import { MessageInput } from './MessageInput';
import { LoadingIndicator } from './LoadingIndicator';
import { PrayerConnectModal } from '../prayer/PrayerConnectModal';
import { useChat } from '../../hooks/useChat';
import { useAuth } from '../../hooks/useAuth';
import { ChatMessage, ChatResponse } from '../../types/chat';

export const ChatInterface: React.FC = () => {
  const { user } = useAuth();
  const {
    messages,
    isLoading,
    error,
    sendMessage,
    loadConversationHistory
  } = useChat();
  
  const [showPrayerModal, setShowPrayerModal] = useState(false);
  const [currentResponse, setCurrentResponse] = useState<ChatResponse | null>(null);
  const messagesEndRef = useRef<HTMLDivElement>(null);
  
  useEffect(() => {
    if (user) {
      loadConversationHistory();
    }
  }, [user, loadConversationHistory]);
  
  useEffect(() => {
    scrollToBottom();
  }, [messages]);
  
  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  };
  
  const handleSendMessage = async (content: string) => {
    try {
      const response = await sendMessage(content);
      
      if (response.prayer_connect_offered) {
        setCurrentResponse(response);
        setShowPrayerModal(true);
      }
    } catch (error) {
      console.error('Failed to send message:', error);
    }
  };
  
  const handlePrayerConnectResponse = (accepted: boolean) => {
    setShowPrayerModal(false);
    
    if (accepted && currentResponse) {
      // Handle prayer connect acceptance
      // This will be implemented in Phase 3
    }
    
    setCurrentResponse(null);
  };
  
  return (
    <div className="flex flex-col h-full max-w-4xl mx-auto bg-white rounded-lg shadow-lg">
      {/* Header */}
      <div className="bg-blue-600 text-white p-4 rounded-t-lg">
        <h1 className="text-xl font-semibold">Faith Motivator Chat</h1>
        <p className="text-blue-100 text-sm">
          Share what's on your heart, and receive biblical encouragement
        </p>
      </div>
      
      {/* Messages Container */}
      <div className="flex-1 overflow-y-auto p-4 space-y-4 min-h-0">
        {messages.length === 0 && !isLoading && (
          <div className="text-center text-gray-500 mt-8">
            <p className="text-lg mb-2">Welcome! How are you feeling today?</p>
            <p className="text-sm">
              Share what's on your mind, and I'll provide biblical encouragement and support.
            </p>
          </div>
        )}
        
        {messages.map((message) => (
          <MessageBubble
            key={message.id}
            message={message}
            isUser={message.role === 'user'}
          />
        ))}
        
        {isLoading && <LoadingIndicator />}
        
        {error && (
          <div className="bg-red-50 border border-red-200 rounded-lg p-4">
            <p className="text-red-800">
              I'm having trouble responding right now. Please try again in a moment.
            </p>
          </div>
        )}
        
        <div ref={messagesEndRef} />
      </div>
      
      {/* Message Input */}
      <div className="border-t bg-gray-50 p-4 rounded-b-lg">
        <MessageInput
          onSendMessage={handleSendMessage}
          disabled={isLoading}
          placeholder="Share what's on your heart..."
        />
      </div>
      
      {/* Prayer Connect Modal */}
      {showPrayerModal && currentResponse && (
        <PrayerConnectModal
          isOpen={showPrayerModal}
          onClose={() => setShowPrayerModal(false)}
          onResponse={handlePrayerConnectResponse}
          response={currentResponse}
        />
      )}
    </div>
  );
};
```

#### Message Bubble Component
```typescript
// src/components/chat/MessageBubble.tsx
import React from 'react';
import { format } from 'date-fns';
import { ConversationMessage } from '../../types/chat';

interface MessageBubbleProps {
  message: ConversationMessage;
  isUser: boolean;
}

export const MessageBubble: React.FC<MessageBubbleProps> = ({ message, isUser }) => {
  return (
    <div className={`flex ${isUser ? 'justify-end' : 'justify-start'}`}>
      <div
        className={`max-w-xs lg:max-w-md px-4 py-2 rounded-lg ${
          isUser
            ? 'bg-blue-600 text-white'
            : 'bg-gray-100 text-gray-800'
        }`}
      >
        <p className="text-sm whitespace-pre-wrap">{message.content}</p>
        
        {/* Biblical Response for Assistant Messages */}
        {!isUser && message.biblical_response && (
          <div className="mt-3 pt-3 border-t border-gray-200">
            <div className="text-xs text-gray-600 mb-2">
              📖 {message.biblical_response.verse.reference}
            </div>
            <p className="text-xs italic text-gray-700 mb-2">
              "{message.biblical_response.verse.text}"
            </p>
            {message.biblical_response.action_step && (
              <div className="bg-blue-50 rounded p-2 mt-2">
                <p className="text-xs text-blue-800">
                  💡 Try this: {message.biblical_response.action_step}
                </p>
              </div>
            )}
          </div>
        )}
        
        <p className={`text-xs mt-2 ${isUser ? 'text-blue-100' : 'text-gray-500'}`}>
          {format(new Date(message.timestamp), 'h:mm a')}
        </p>
      </div>
    </div>
  );
};
```

#### Chat Hook
```typescript
// src/hooks/useChat.ts
import { useState, useCallback } from 'react';
import { chatService } from '../services/chat';
import { ConversationMessage, ChatResponse } from '../types/chat';

export const useChat = () => {
  const [messages, setMessages] = useState<ConversationMessage[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [currentSessionId, setCurrentSessionId] = useState<string | null>(null);
  
  const sendMessage = useCallback(async (content: string): Promise<ChatResponse> => {
    setIsLoading(true);
    setError(null);
    
    // Add user message immediately
    const userMessage: ConversationMessage = {
      id: `temp-${Date.now()}`,
      role: 'user',
      content,
      timestamp: new Date().toISOString()
    };
    
    setMessages(prev => [...prev, userMessage]);
    
    try {
      const response = await chatService.sendMessage({
        content,
        session_id: currentSessionId,
        request_prayer_connect: false
      });
      
      // Update session ID if this is a new conversation
      if (!currentSessionId) {
        setCurrentSessionId(response.session_id);
      }
      
      // Add assistant response
      const assistantMessage: ConversationMessage = {
        id: response.message_id,
        role: 'assistant',
        content: response.content,
        timestamp: response.timestamp,
        biblical_response: response.biblical_response,
        emotion_classification: response.emotion_classification
      };
      
      setMessages(prev => [...prev, assistantMessage]);
      
      return response;
    } catch (err) {
      setError('Failed to send message. Please try again.');
      // Remove the temporary user message on error
      setMessages(prev => prev.slice(0, -1));
      throw err;
    } finally {
      setIsLoading(false);
    }
  }, [currentSessionId]);
  
  const loadConversationHistory = useCallback(async () => {
    try {
      const history = await chatService.getConversationHistory();
      // Load most recent session messages
      if (history.sessions.length > 0) {
        const recentSession = history.sessions[0];
        setCurrentSessionId(recentSession.session_id);
        setMessages(recentSession.messages || []);
      }
    } catch (err) {
      console.error('Failed to load conversation history:', err);
    }
  }, []);
  
  return {
    messages,
    isLoading,
    error,
    sendMessage,
    loadConversationHistory
  };
};
```

## Security Design

### API Security
- JWT token validation on all endpoints
- Rate limiting: 10 messages per minute per user
- Input validation and sanitization
- CORS configuration for frontend domain only
- Request/response logging with sensitive data filtering

### Content Security
- All user input processed through Bedrock Guardrails
- Crisis content detection and specialized handling
- Sensitive information filtering (PII, credentials)
- Response content validation before delivery

### Frontend Security
- Secure token storage using httpOnly cookies
- XSS protection through React's built-in escaping
- CSRF protection for state-changing operations
- Secure communication over HTTPS only

## Performance Optimization

### Backend Performance
- Connection pooling for DynamoDB and Bedrock
- Response caching for biblical content
- Asynchronous processing for non-critical operations
- Efficient conversation context retrieval

### Frontend Performance
- Code splitting for reduced initial bundle size
- Lazy loading of non-critical components
- Optimized re-rendering with React.memo
- Progressive loading of conversation history

## Testing Strategy

### Backend Testing
- Unit tests for all service methods
- Integration tests for API endpoints
- Property-based tests for message processing pipeline
- Crisis detection accuracy testing

### Frontend Testing
- Component unit tests with React Testing Library
- Integration tests for user flows
- Accessibility testing with axe-core
- Cross-browser compatibility testing

This design provides a robust, secure, and user-friendly chat interface that delivers biblically-grounded encouragement while maintaining the highest standards of safety and crisis response.