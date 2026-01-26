# Phase 5: Testing & Quality Assurance - Design Document

## Testing Architecture Overview

Phase 5 implements a comprehensive testing strategy that ensures the faith-based motivator chatbot meets the highest standards of reliability, security, performance, and user experience. The testing architecture includes multiple layers of validation from unit tests to end-to-end user journey testing.

### Testing Pyramid Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    End-to-End Tests                             │
│  ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐   │
│  │ User Journey    │ │ Security        │ │ Accessibility   │   │
│  │ Testing         │ │ Testing         │ │ Testing         │   │
│  └─────────────────┘ └─────────────────┘ └─────────────────┘   │
└─────────────────────────┬───────────────────────────────────────┘
                          │
┌─────────────────────────▼───────────────────────────────────────┐
│                 Integration Tests                               │
│  ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐   │
│  │ API Integration │ │ Database        │ │ External        │   │
│  │ Testing         │ │ Integration     │ │ Service Testing │   │
│  └─────────────────┘ └─────────────────┘ └─────────────────┘   │
└─────────────────────────┬───────────────────────────────────────┘
                          │
┌─────────────────────────▼───────────────────────────────────────┐
│                Property-Based Tests                             │
│  ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐   │
│  │ Correctness     │ │ Invariant       │ │ Edge Case       │   │
│  │ Properties      │ │ Validation      │ │ Discovery       │   │
│  └─────────────────┘ └─────────────────┘ └─────────────────┘   │
└─────────────────────────┬───────────────────────────────────────┘
                          │
┌─────────────────────────▼───────────────────────────────────────┐
│                    Unit Tests                                   │
│  ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐   │
│  │ Component       │ │ Service         │ │ Utility         │   │
│  │ Testing         │ │ Testing         │ │ Testing         │   │
│  └─────────────────┘ └─────────────────┘ └─────────────────┘   │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                 Cross-Cutting Test Concerns                     │
│  ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐   │
│  │ Performance     │ │ Security        │ │ Compliance      │   │
│  │ Testing         │ │ Testing         │ │ Testing         │   │
│  └─────────────────┘ └─────────────────┘ └─────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

## Testing Framework Design

### 1. Unit Testing Framework

#### Backend Unit Testing (Python/pytest)
```python
# tests/conftest.py - Test configuration and fixtures
import pytest
import asyncio
from unittest.mock import AsyncMock, MagicMock
from app.services.emotion_service import EmotionService
from app.services.biblical_content_service import BiblicalContentService
from app.services.prayer_service import PrayerService

@pytest.fixture
def mock_bedrock_client():
    """Mock Bedrock client for testing"""
    client = AsyncMock()
    client.invoke_model.return_value = {
        'body': MagicMock(read=MagicMock(return_value=json.dumps({
            'content': [{'text': '{"primary_emotion": "anxiety", "confidence": 0.85}'}]
        })))
    }
    return client

@pytest.fixture
def emotion_service(mock_bedrock_client):
    """Emotion service with mocked dependencies"""
    return EmotionService(bedrock_client=mock_bedrock_client)

@pytest.fixture
def sample_user_data():
    """Sample user data for testing"""
    return {
        'user_id': 'test_user_123',
        'email': 'test@example.com',
        'first_name': 'Test User'
    }

@pytest.fixture
def sample_conversation_data():
    """Sample conversation data for testing"""
    return {
        'session_id': 'session_123',
        'messages': [
            {
                'role': 'user',
                'content': 'I am feeling anxious about work',
                'timestamp': '2024-01-26T10:00:00Z'
            }
        ]
    }

# Test class structure
class TestEmotionClassification:
    """Test emotion classification functionality"""
    
    @pytest.mark.asyncio
    async def test_classify_anxiety_emotion(self, emotion_service):
        """Test anxiety emotion classification accuracy"""
        message = "I'm really worried about my job interview tomorrow"
        
        result = await emotion_service.classify_emotion(message)
        
        assert result.primary_emotion == PrimaryEmotion.ANXIETY
        assert result.confidence > 0.7
        assert RiskFlag.MILD_DISTRESS in result.risk_flags
    
    @pytest.mark.asyncio
    async def test_crisis_detection_accuracy(self, emotion_service):
        """Test crisis detection with known crisis indicators"""
        crisis_message = "I don't want to be here anymore, life isn't worth living"
        
        result = await emotion_service.classify_emotion(crisis_message)
        
        assert RiskFlag.CRISIS_INDICATORS in result.risk_flags
        assert len(result.crisis_indicators) > 0
        assert 'suicide_ideation' in result.crisis_indicators
    
    @pytest.mark.asyncio
    async def test_emotion_classification_with_context(self, emotion_service):
        """Test emotion classification with conversation context"""
        message = "I'm still feeling the same way"
        context = "User: I'm anxious about work\nAssistant: I understand your anxiety..."
        
        result = await emotion_service.classify_emotion(message, context)
        
        assert result.primary_emotion == PrimaryEmotion.ANXIETY
        assert result.confidence > 0.6
    
    @pytest.mark.asyncio
    async def test_bedrock_service_failure_handling(self, emotion_service):
        """Test graceful handling of Bedrock service failures"""
        # Mock Bedrock failure
        emotion_service.bedrock_client.invoke_model.side_effect = Exception("Service unavailable")
        
        result = await emotion_service.classify_emotion("Test message")
        
        # Should return fallback classification
        assert result.primary_emotion == PrimaryEmotion.CONFUSION
        assert result.confidence == 0.0
        assert RiskFlag.MILD_DISTRESS in result.risk_flags

class TestBiblicalContentService:
    """Test biblical content retrieval and validation"""
    
    def test_get_content_for_anxiety(self, biblical_content_service):
        """Test biblical content retrieval for anxiety"""
        content = biblical_content_service.get_content_for_emotion(PrimaryEmotion.ANXIETY)
        
        assert content is not None
        assert len(content.verses) > 0
        assert len(content.reflections) > 0
        assert len(content.action_steps) > 0
        assert 'anxiety' in content.themes or 'peace' in content.themes
    
    def test_content_theological_accuracy(self, biblical_content_service):
        """Test theological accuracy of biblical content"""
        content = biblical_content_service.get_content_for_emotion(PrimaryEmotion.SHAME)
        
        # Ensure content promotes grace and forgiveness, not condemnation
        for reflection in content.reflections:
            assert 'grace' in reflection.lower() or 'forgiveness' in reflection.lower()
            assert 'condemned' not in reflection.lower()
            assert 'worthless' not in reflection.lower()
    
    def test_content_variety_and_randomization(self, biblical_content_service):
        """Test that content selection provides variety"""
        contents = []
        for _ in range(10):
            content = biblical_content_service.get_content_for_emotion(PrimaryEmotion.SADNESS)
            contents.append(content.verses[0].reference)
        
        # Should have some variety in verse selection
        unique_verses = set(contents)
        assert len(unique_verses) > 1

class TestPrayerService:
    """Test prayer request functionality"""
    
    @pytest.mark.asyncio
    async def test_create_prayer_request_with_consent(self, prayer_service, sample_user_data):
        """Test prayer request creation with proper consent"""
        consent_data = ConsentData(
            granted=True,
            purpose="Share email with prayer team",
            details={'consent_type': 'prayer_connect'}
        )
        
        request = await prayer_service.create_request(
            user_id=sample_user_data['user_id'],
            user_email=sample_user_data['email'],
            consent_data=consent_data,
            message="Please pray for my anxiety"
        )
        
        assert request.request_id.startswith('pr_')
        assert request.user_id == sample_user_data['user_id']
        assert request.status == PrayerRequestStatus.PENDING
        assert request.message == "Please pray for my anxiety"
    
    @pytest.mark.asyncio
    async def test_prayer_request_rate_limiting(self, prayer_service, sample_user_data):
        """Test daily rate limiting for prayer requests"""
        # Create 3 requests (daily limit)
        for i in range(3):
            await prayer_service.create_request(
                user_id=sample_user_data['user_id'],
                user_email=sample_user_data['email'],
                consent_data=ConsentData(granted=True, purpose="test"),
                message=f"Prayer request {i+1}"
            )
        
        # 4th request should be rate limited
        with pytest.raises(HTTPException) as exc_info:
            await prayer_service.create_request(
                user_id=sample_user_data['user_id'],
                user_email=sample_user_data['email'],
                consent_data=ConsentData(granted=True, purpose="test"),
                message="Rate limited request"
            )
        
        assert exc_info.value.status_code == 429
```

#### Frontend Unit Testing (React/Jest)
```typescript
// src/components/chat/__tests__/ChatInterface.test.tsx
import React from 'react';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { ChatInterface } from '../ChatInterface';
import { useAuth } from '../../../hooks/useAuth';
import { useChat } from '../../../hooks/useChat';

// Mock hooks
jest.mock('../../../hooks/useAuth');
jest.mock('../../../hooks/useChat');

const mockUseAuth = useAuth as jest.MockedFunction<typeof useAuth>;
const mockUseChat = useChat as jest.MockedFunction<typeof useChat>;

describe('ChatInterface', () => {
  beforeEach(() => {
    mockUseAuth.mockReturnValue({
      user: { user_id: 'test_user', email: 'test@example.com' },
      isAuthenticated: true,
      login: jest.fn(),
      logout: jest.fn()
    });
    
    mockUseChat.mockReturnValue({
      messages: [],
      isLoading: false,
      error: null,
      sendMessage: jest.fn(),
      loadConversationHistory: jest.fn()
    });
  });
  
  test('renders chat interface with welcome message', () => {
    render(<ChatInterface />);
    
    expect(screen.getByText('Welcome! How are you feeling today?')).toBeInTheDocument();
    expect(screen.getByPlaceholderText('Share what\'s on your heart...')).toBeInTheDocument();
  });
  
  test('sends message when user submits input', async () => {
    const mockSendMessage = jest.fn().mockResolvedValue({
      message_id: 'msg_123',
      content: 'Thank you for sharing...',
      prayer_connect_offered: false
    });
    
    mockUseChat.mockReturnValue({
      ...mockUseChat(),
      sendMessage: mockSendMessage
    });
    
    render(<ChatInterface />);
    
    const input = screen.getByPlaceholderText('Share what\'s on your heart...');
    const sendButton = screen.getByRole('button', { name: /send/i });
    
    fireEvent.change(input, { target: { value: 'I am feeling anxious' } });
    fireEvent.click(sendButton);
    
    await waitFor(() => {
      expect(mockSendMessage).toHaveBeenCalledWith('I am feeling anxious');
    });
  });
  
  test('displays prayer connect modal when offered', async () => {
    const mockSendMessage = jest.fn().mockResolvedValue({
      message_id: 'msg_123',
      content: 'I understand your anxiety...',
      prayer_connect_offered: true
    });
    
    mockUseChat.mockReturnValue({
      ...mockUseChat(),
      sendMessage: mockSendMessage
    });
    
    render(<ChatInterface />);
    
    const input = screen.getByPlaceholderText('Share what\'s on your heart...');
    fireEvent.change(input, { target: { value: 'I need prayer support' } });
    fireEvent.click(screen.getByRole('button', { name: /send/i }));
    
    await waitFor(() => {
      expect(screen.getByText('Would you like prayer support?')).toBeInTheDocument();
    });
  });
  
  test('handles error states gracefully', () => {
    mockUseChat.mockReturnValue({
      ...mockUseChat(),
      error: 'Failed to send message'
    });
    
    render(<ChatInterface />);
    
    expect(screen.getByText(/having trouble responding/i)).toBeInTheDocument();
  });
});

// src/components/prayer/__tests__/PrayerConnectModal.test.tsx
describe('PrayerConnectModal', () => {
  test('displays consent form when user accepts prayer connect', () => {
    render(
      <PrayerConnectModal
        isOpen={true}
        onClose={jest.fn()}
        onResponse={jest.fn()}
        response={mockChatResponse}
      />
    );
    
    fireEvent.click(screen.getByText('Yes, I\'d like prayer support'));
    
    expect(screen.getByText('Consent for Prayer Connect')).toBeInTheDocument();
    expect(screen.getByText(/share my email address/i)).toBeInTheDocument();
  });
  
  test('validates all consent checkboxes before allowing submission', () => {
    render(
      <PrayerConnectModal
        isOpen={true}
        onClose={jest.fn()}
        onResponse={jest.fn()}
        response={mockChatResponse}
      />
    );
    
    // Navigate to consent form
    fireEvent.click(screen.getByText('Yes, I\'d like prayer support'));
    
    // Submit button should be disabled initially
    const submitButton = screen.getByText('Submit Prayer Request');
    expect(submitButton).toBeDisabled();
    
    // Check all consent boxes
    const checkboxes = screen.getAllByRole('checkbox');
    checkboxes.forEach(checkbox => {
      fireEvent.click(checkbox);
    });
    
    // Submit button should now be enabled
    expect(submitButton).not.toBeDisabled();
  });
});
```

### 2. Property-Based Testing Framework

#### Hypothesis-Based Property Testing
```python
# tests/property_tests/test_emotion_classification_properties.py
from hypothesis import given, strategies as st, assume, settings
from hypothesis.stateful import RuleBasedStateMachine, rule, invariant
from app.models.emotion import PrimaryEmotion, RiskFlag
from app.services.emotion_service import EmotionService

# Custom strategies for domain-specific data
@st.composite
def user_messages(draw):
    """Generate realistic user messages for testing"""
    message_types = [
        st.text(min_size=10, max_size=500),  # General text
        st.sampled_from([  # Common emotional expressions
            "I'm feeling anxious about work",
            "I'm so happy today",
            "I feel sad and lonely",
            "I'm angry about this situation",
            "I'm scared about the future"
        ]),
        st.sampled_from([  # Crisis-related messages (for testing)
            "I don't want to live anymore",
            "Life isn't worth living",
            "I want to hurt myself"
        ])
    ]
    return draw(st.one_of(message_types))

@st.composite
def conversation_contexts(draw):
    """Generate conversation contexts for testing"""
    num_messages = draw(st.integers(min_value=0, max_value=10))
    messages = []
    
    for _ in range(num_messages):
        role = draw(st.sampled_from(['user', 'assistant']))
        content = draw(st.text(min_size=5, max_size=200))
        messages.append(f"{role.title()}: {content}")
    
    return "\n".join(messages)

@st.composite
def emotion_classifications(draw):
    """Generate emotion classification results for testing"""
    return EmotionClassification(
        primary_emotion=draw(st.sampled_from(list(PrimaryEmotion))),
        secondary_emotion=draw(st.one_of(st.none(), st.sampled_from(list(PrimaryEmotion)))),
        confidence=draw(st.floats(min_value=0.0, max_value=1.0)),
        risk_flags=draw(st.lists(st.sampled_from(list(RiskFlag)), max_size=3)),
        crisis_indicators=draw(st.lists(st.text(min_size=1, max_size=50), max_size=3))
    )

class TestEmotionClassificationProperties:
    """Property-based tests for emotion classification"""
    
    @given(message=user_messages(), context=conversation_contexts())
    @settings(max_examples=100, deadline=5000)
    def test_emotion_classification_never_crashes(self, message, context):
        """Property: Emotion classification should never crash regardless of input"""
        emotion_service = EmotionService()
        
        try:
            result = asyncio.run(emotion_service.classify_emotion(message, context))
            
            # Basic invariants that should always hold
            assert isinstance(result, EmotionClassification)
            assert result.primary_emotion in PrimaryEmotion
            assert 0.0 <= result.confidence <= 1.0
            assert all(flag in RiskFlag for flag in result.risk_flags)
            
        except Exception as e:
            # Should only fail for expected reasons (service unavailable, etc.)
            assert "Service unavailable" in str(e) or "Rate limited" in str(e)
    
    @given(emotion_data=emotion_classifications())
    def test_response_generation_format_consistency(self, emotion_data):
        """Property: All responses should follow consistent format"""
        biblical_service = BiblicalContentService()
        
        content = biblical_service.get_content_for_emotion(emotion_data.primary_emotion)
        response = generate_response(emotion_data, content)
        
        # Response format invariants
        assert isinstance(response, str)
        assert len(response) > 0
        assert len(response) < 2000  # Reasonable length limit
        
        # Should contain empathy, biblical content, and action step
        response_lower = response.lower()
        empathy_indicators = ['understand', 'feel', 'sense', 'hear']
        assert any(indicator in response_lower for indicator in empathy_indicators)
        
        # Should contain biblical reference
        assert any(book in response for book in ['Matthew', 'John', 'Psalm', 'Philippians'])
    
    @given(user_data=st.fixed_dictionaries({
        'user_id': st.text(min_size=5, max_size=50),
        'email': st.emails(),
        'consent_granted': st.booleans()
    }))
    def test_privacy_controls_always_protect_data(self, user_data):
        """Property: Privacy controls should always protect user data"""
        privacy_service = PrivacyService()
        
        # If consent not granted, no data should be shared
        if not user_data['consent_granted']:
            sharing_allowed = privacy_service.can_share_data(
                user_data['user_id'], 
                'prayer_connect'
            )
            assert not sharing_allowed
        
        # Data export should always include all user data
        if user_data['consent_granted']:
            export_data = asyncio.run(privacy_service.export_user_data(user_data['user_id']))
            
            assert 'user_profile' in export_data.data
            assert 'conversations' in export_data.data
            assert 'consent_logs' in export_data.data
    
    @given(prayer_request_data=st.fixed_dictionaries({
        'user_id': st.text(min_size=5, max_size=50),
        'user_email': st.emails(),
        'message': st.one_of(st.none(), st.text(max_size=500))
    }))
    def test_prayer_request_processing_reliability(self, prayer_request_data):
        """Property: Prayer request processing should be reliable"""
        prayer_service = PrayerService()
        
        consent_data = ConsentData(granted=True, purpose="test")
        
        request = asyncio.run(prayer_service.create_request(
            user_id=prayer_request_data['user_id'],
            user_email=prayer_request_data['user_email'],
            consent_data=consent_data,
            message=prayer_request_data['message']
        ))
        
        # Request invariants
        assert request.request_id.startswith('pr_')
        assert request.user_id == prayer_request_data['user_id']
        assert request.user_email == prayer_request_data['user_email']
        assert request.status in [PrayerRequestStatus.PENDING, PrayerRequestStatus.QUEUED]
        assert request.created_at is not None

# Stateful testing for complex workflows
class ChatWorkflowStateMachine(RuleBasedStateMachine):
    """Stateful testing for chat workflow"""
    
    def __init__(self):
        super().__init__()
        self.chat_service = ChatService()
        self.user_id = "test_user_123"
        self.session_id = None
        self.message_count = 0
    
    @rule(message=st.text(min_size=1, max_size=500))
    def send_message(self, message):
        """Send a message and verify response"""
        response = asyncio.run(self.chat_service.process_message(
            user_id=self.user_id,
            message=message,
            session_id=self.session_id
        ))
        
        if self.session_id is None:
            self.session_id = response.session_id
        
        self.message_count += 1
        
        # Response invariants
        assert response.session_id == self.session_id
        assert response.content is not None
        assert len(response.content) > 0
    
    @invariant()
    def session_consistency(self):
        """Session should remain consistent throughout conversation"""
        if self.session_id is not None:
            session = asyncio.run(self.chat_service.get_conversation_session(self.session_id))
            assert session.user_id == self.user_id
            assert len(session.messages) >= self.message_count

TestChatWorkflow = ChatWorkflowStateMachine.TestCase
```

### 3. Integration Testing Framework

#### API Integration Tests
```python
# tests/integration/test_chat_api_integration.py
import pytest
import httpx
from fastapi.testclient import TestClient
from app.main import app

@pytest.fixture
def client():
    """Test client for API integration tests"""
    return TestClient(app)

@pytest.fixture
def authenticated_headers(client):
    """Get authenticated headers for API requests"""
    # Mock authentication for testing
    return {"Authorization": "Bearer test_jwt_token"}

class TestChatAPIIntegration:
    """Integration tests for chat API endpoints"""
    
    def test_send_message_end_to_end(self, client, authenticated_headers):
        """Test complete message sending workflow"""
        # Send a message
        response = client.post(
            "/chat/message",
            json={
                "content": "I'm feeling anxious about work",
                "session_id": None,
                "request_prayer_connect": False
            },
            headers=authenticated_headers
        )
        
        assert response.status_code == 200
        data = response.json()
        
        # Verify response structure
        assert "message_id" in data
        assert "session_id" in data
        assert "content" in data
        assert "biblical_response" in data
        assert "emotion_classification" in data
        
        # Verify emotion classification
        emotion = data["emotion_classification"]
        assert emotion["primary_emotion"] in ["anxiety", "fear", "worry"]
        assert 0.0 <= emotion["confidence"] <= 1.0
        
        # Verify biblical response
        biblical = data["biblical_response"]
        assert "verse" in biblical
        assert "reflection" in biblical
        assert "action_step" in biblical
    
    def test_conversation_history_retrieval(self, client, authenticated_headers):
        """Test conversation history retrieval"""
        # First, send a few messages to create history
        session_id = None
        for i in range(3):
            response = client.post(
                "/chat/message",
                json={
                    "content": f"Test message {i+1}",
                    "session_id": session_id
                },
                headers=authenticated_headers
            )
            if session_id is None:
                session_id = response.json()["session_id"]
        
        # Retrieve conversation history
        response = client.get(
            "/chat/history",
            headers=authenticated_headers
        )
        
        assert response.status_code == 200
        data = response.json()
        
        assert "sessions" in data
        assert len(data["sessions"]) > 0
        
        # Find our test session
        test_session = next(
            (s for s in data["sessions"] if s["session_id"] == session_id),
            None
        )
        assert test_session is not None
        assert len(test_session["messages"]) >= 6  # 3 user + 3 assistant messages
    
    def test_prayer_request_workflow(self, client, authenticated_headers):
        """Test complete prayer request workflow"""
        # Create prayer request
        response = client.post(
            "/prayer/request",
            json={
                "message": "Please pray for my anxiety",
                "consent_confirmed": True,
                "consent": {
                    "granted": True,
                    "purpose": "Share email with prayer team",
                    "details": {"consent_type": "prayer_connect"}
                }
            },
            headers=authenticated_headers
        )
        
        assert response.status_code == 200
        data = response.json()
        
        assert "request_id" in data
        assert data["status"] == "pending"
        assert data["message"] == "Please pray for my anxiety"
        
        request_id = data["request_id"]
        
        # Check prayer request status
        response = client.get(
            f"/prayer/status/{request_id}",
            headers=authenticated_headers
        )
        
        assert response.status_code == 200
        status_data = response.json()
        assert status_data["request_id"] == request_id
        assert status_data["status"] in ["pending", "queued", "sent"]

class TestDatabaseIntegration:
    """Integration tests for database operations"""
    
    @pytest.mark.asyncio
    async def test_user_profile_crud_operations(self, db_service):
        """Test user profile CRUD operations"""
        user_data = {
            "user_id": "test_user_integration",
            "email": "integration@test.com",
            "first_name": "Integration Test"
        }
        
        # Create user profile
        await db_service.create_user_profile(user_data)
        
        # Read user profile
        profile = await db_service.get_user_profile(user_data["user_id"])
        assert profile["email"] == user_data["email"]
        assert profile["first_name"] == user_data["first_name"]
        
        # Update user profile
        updated_data = {"first_name": "Updated Name"}
        await db_service.update_user_profile(user_data["user_id"], updated_data)
        
        # Verify update
        updated_profile = await db_service.get_user_profile(user_data["user_id"])
        assert updated_profile["first_name"] == "Updated Name"
        
        # Delete user profile
        await db_service.delete_user_profile(user_data["user_id"])
        
        # Verify deletion
        deleted_profile = await db_service.get_user_profile(user_data["user_id"])
        assert deleted_profile is None
    
    @pytest.mark.asyncio
    async def test_conversation_session_management(self, db_service):
        """Test conversation session management"""
        session_data = {
            "session_id": "test_session_integration",
            "user_id": "test_user_integration",
            "messages": [
                {
                    "id": "msg_1",
                    "role": "user",
                    "content": "Hello",
                    "timestamp": "2024-01-26T10:00:00Z"
                }
            ]
        }
        
        # Create conversation session
        await db_service.create_conversation_session(session_data)
        
        # Retrieve session
        session = await db_service.get_conversation_session(session_data["session_id"])
        assert session["user_id"] == session_data["user_id"]
        assert len(session["messages"]) == 1
        
        # Add message to session
        new_message = {
            "id": "msg_2",
            "role": "assistant",
            "content": "Hello! How can I help you today?",
            "timestamp": "2024-01-26T10:01:00Z"
        }
        
        await db_service.add_message_to_session(session_data["session_id"], new_message)
        
        # Verify message added
        updated_session = await db_service.get_conversation_session(session_data["session_id"])
        assert len(updated_session["messages"]) == 2
```

### 4. Performance Testing Framework

#### Load Testing with Locust
```python
# tests/performance/locustfile.py
from locust import HttpUser, task, between
import json
import random

class ChatBotUser(HttpUser):
    """Simulate user behavior for load testing"""
    
    wait_time = between(1, 5)  # Wait 1-5 seconds between requests
    
    def on_start(self):
        """Setup for each user"""
        self.session_id = None
        self.auth_headers = {"Authorization": "Bearer test_jwt_token"}
        self.message_count = 0
    
    @task(10)  # Weight: 10 (most common action)
    def send_chat_message(self):
        """Send a chat message"""
        messages = [
            "I'm feeling anxious about work",
            "I'm happy today",
            "I feel sad and lonely",
            "I'm worried about my family",
            "Thank you for the encouragement",
            "I need some guidance",
            "I'm grateful for this support"
        ]
        
        message = random.choice(messages)
        
        response = self.client.post(
            "/chat/message",
            json={
                "content": message,
                "session_id": self.session_id,
                "request_prayer_connect": False
            },
            headers=self.auth_headers,
            name="Send Chat Message"
        )
        
        if response.status_code == 200:
            data = response.json()
            if self.session_id is None:
                self.session_id = data.get("session_id")
            self.message_count += 1
    
    @task(2)  # Weight: 2 (less common)
    def get_conversation_history(self):
        """Retrieve conversation history"""
        if self.message_count > 0:  # Only if we have messages
            self.client.get(
                "/chat/history",
                headers=self.auth_headers,
                name="Get Conversation History"
            )
    
    @task(1)  # Weight: 1 (rare)
    def create_prayer_request(self):
        """Create a prayer request"""
        if self.message_count > 2:  # Only after some conversation
            self.client.post(
                "/prayer/request",
                json={
                    "message": "Please pray for me",
                    "consent_confirmed": True,
                    "consent": {
                        "granted": True,
                        "purpose": "Share email with prayer team",
                        "details": {"consent_type": "prayer_connect"}
                    }
                },
                headers=self.auth_headers,
                name="Create Prayer Request"
            )

# Performance test configuration
class PerformanceTestConfig:
    """Configuration for performance tests"""
    
    # Load test scenarios
    SCENARIOS = {
        "normal_load": {
            "users": 50,
            "spawn_rate": 5,
            "duration": "10m"
        },
        "peak_load": {
            "users": 100,
            "spawn_rate": 10,
            "duration": "15m"
        },
        "stress_test": {
            "users": 200,
            "spawn_rate": 20,
            "duration": "20m"
        },
        "spike_test": {
            "users": 300,
            "spawn_rate": 50,
            "duration": "5m"
        }
    }
    
    # Performance thresholds
    THRESHOLDS = {
        "response_time_95th": 3000,  # 95th percentile < 3 seconds
        "response_time_avg": 1500,   # Average < 1.5 seconds
        "error_rate": 0.01,          # Error rate < 1%
        "throughput_min": 10         # Minimum 10 requests/second
    }

# Performance monitoring
class PerformanceMonitor:
    """Monitor performance metrics during tests"""
    
    def __init__(self):
        self.metrics = {
            'response_times': [],
            'error_count': 0,
            'total_requests': 0,
            'throughput': 0
        }
    
    def record_response(self, response_time: float, success: bool):
        """Record response metrics"""
        self.metrics['response_times'].append(response_time)
        self.metrics['total_requests'] += 1
        
        if not success:
            self.metrics['error_count'] += 1
    
    def get_performance_report(self) -> dict:
        """Generate performance report"""
        response_times = self.metrics['response_times']
        
        if not response_times:
            return {"error": "No data collected"}
        
        response_times.sort()
        
        return {
            "total_requests": self.metrics['total_requests'],
            "error_count": self.metrics['error_count'],
            "error_rate": self.metrics['error_count'] / self.metrics['total_requests'],
            "response_time_avg": sum(response_times) / len(response_times),
            "response_time_95th": response_times[int(len(response_times) * 0.95)],
            "response_time_max": max(response_times),
            "response_time_min": min(response_times)
        }
```

### 5. Security Testing Framework

#### Security Test Suite
```python
# tests/security/test_security_vulnerabilities.py
import pytest
import requests
from sqlalchemy import text

class TestSecurityVulnerabilities:
    """Test for common security vulnerabilities"""
    
    def test_sql_injection_prevention(self, client):
        """Test SQL injection prevention"""
        # Attempt SQL injection in various parameters
        injection_payloads = [
            "'; DROP TABLE users; --",
            "' OR '1'='1",
            "' UNION SELECT * FROM users --",
            "'; INSERT INTO users VALUES ('hacker', 'password'); --"
        ]
        
        for payload in injection_payloads:
            # Test in chat message
            response = client.post(
                "/chat/message",
                json={"content": payload},
                headers={"Authorization": "Bearer test_token"}
            )
            
            # Should not cause server error or expose data
            assert response.status_code in [200, 400, 422]  # Valid responses
            
            if response.status_code == 200:
                data = response.json()
                # Response should not contain SQL error messages
                assert "SQL" not in str(data).upper()
                assert "ERROR" not in str(data).upper()
    
    def test_xss_prevention(self, client):
        """Test XSS prevention"""
        xss_payloads = [
            "<script>alert('XSS')</script>",
            "javascript:alert('XSS')",
            "<img src=x onerror=alert('XSS')>",
            "';alert('XSS');//"
        ]
        
        for payload in xss_payloads:
            response = client.post(
                "/chat/message",
                json={"content": payload},
                headers={"Authorization": "Bearer test_token"}
            )
            
            if response.status_code == 200:
                data = response.json()
                response_content = data.get("content", "")
                
                # XSS payload should be sanitized or escaped
                assert "<script>" not in response_content
                assert "javascript:" not in response_content
                assert "onerror=" not in response_content
    
    def test_authentication_bypass_attempts(self, client):
        """Test authentication bypass prevention"""
        protected_endpoints = [
            "/chat/message",
            "/chat/history",
            "/prayer/request",
            "/privacy/data"
        ]
        
        bypass_attempts = [
            {},  # No auth header
            {"Authorization": ""},  # Empty auth
            {"Authorization": "Bearer invalid_token"},  # Invalid token
            {"Authorization": "Basic admin:admin"},  # Wrong auth type
            {"X-User-ID": "admin"},  # Header injection attempt
        ]
        
        for endpoint in protected_endpoints:
            for headers in bypass_attempts:
                response = client.get(endpoint, headers=headers)
                
                # Should return 401 Unauthorized or 403 Forbidden
                assert response.status_code in [401, 403]
    
    def test_rate_limiting_enforcement(self, client):
        """Test rate limiting enforcement"""
        # Attempt to exceed rate limits
        auth_headers = {"Authorization": "Bearer test_token"}
        
        # Test chat message rate limiting (10 per minute)
        responses = []
        for i in range(15):  # Exceed limit
            response = client.post(
                "/chat/message",
                json={"content": f"Test message {i}"},
                headers=auth_headers
            )
            responses.append(response.status_code)
        
        # Should have some 429 (Too Many Requests) responses
        assert 429 in responses
        
        # Count successful vs rate limited
        success_count = responses.count(200)
        rate_limited_count = responses.count(429)
        
        assert success_count <= 10  # Should not exceed rate limit
        assert rate_limited_count > 0  # Should have rate limited some requests
    
    def test_content_filtering_bypass_attempts(self, client):
        """Test content filtering bypass attempts"""
        bypass_attempts = [
            # Encoding attempts
            "%3Cscript%3Ealert('XSS')%3C/script%3E",
            "&#60;script&#62;alert('XSS')&#60;/script&#62;",
            
            # Obfuscation attempts
            "I want to k1ll myself",  # Leetspeak
            "I want to end my l1fe",
            
            # Case variation
            "KILL MYSELF",
            "KiLl MySeLf",
            
            # Spacing/punctuation
            "k i l l   m y s e l f",
            "kill.my.self",
            
            # Harmful content
            "You should hurt yourself",
            "God hates you and you deserve hell"
        ]
        
        auth_headers = {"Authorization": "Bearer test_token"}
        
        for payload in bypass_attempts:
            response = client.post(
                "/chat/message",
                json={"content": payload},
                headers=auth_headers
            )
            
            if response.status_code == 200:
                data = response.json()
                
                # Should trigger crisis response or content filtering
                if "crisis_response" in data:
                    assert data["crisis_response"] is True
                
                # Response should not echo harmful content
                response_content = data.get("content", "").lower()
                assert "kill" not in response_content
                assert "hurt yourself" not in response_content
                assert "god hates" not in response_content

class TestDataPrivacyCompliance:
    """Test data privacy and compliance"""
    
    def test_gdpr_data_export(self, client):
        """Test GDPR data export functionality"""
        auth_headers = {"Authorization": "Bearer test_token"}
        
        response = client.get("/privacy/data", headers=auth_headers)
        
        assert response.status_code == 200
        data = response.json()
        
        # Should include all required data categories
        required_categories = [
            'user_profile',
            'conversations', 
            'prayer_requests',
            'consent_logs'
        ]
        
        for category in required_categories:
            assert category in data
    
    def test_gdpr_data_deletion(self, client):
        """Test GDPR data deletion (right to be forgotten)"""
        auth_headers = {"Authorization": "Bearer test_token"}
        
        # Request data deletion
        response = client.delete(
            "/privacy/data",
            json={"confirmation_token": "test_confirmation"},
            headers=auth_headers
        )
        
        assert response.status_code == 200
        data = response.json()
        
        assert "deletion_id" in data
        assert data["status"] in ["in_progress", "completed"]
    
    def test_consent_management(self, client):
        """Test consent management functionality"""
        auth_headers = {"Authorization": "Bearer test_token"}
        
        # Log consent
        response = client.post(
            "/privacy/consent",
            json={
                "granted": True,
                "purpose": "prayer_connect",
                "details": {"consent_type": "email_sharing"}
            },
            headers=auth_headers
        )
        
        assert response.status_code == 200
        data = response.json()
        
        assert data["consent_logged"] is True
        assert "log_id" in data
        
        # Revoke consent
        response = client.post(
            "/privacy/consent/revoke",
            json={"consent_type": "prayer_connect"},
            headers=auth_headers
        )
        
        assert response.status_code == 200
```

This comprehensive testing framework ensures the faith-based motivator chatbot meets the highest standards of reliability, security, performance, and user experience through systematic validation at every level of the system.