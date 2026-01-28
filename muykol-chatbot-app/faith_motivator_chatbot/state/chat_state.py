"""Chat functionality state management."""

import reflex as rx
from typing import List, Dict, Any, Optional
import httpx
from datetime import datetime
from faith_motivator_chatbot.state.auth_state import AuthState


class Message(rx.Base):
    """Message model for chat interface."""
    id: str
    content: str
    role: str  # "user" or "assistant"
    timestamp: datetime
    emotion_classification: Optional[str] = None
    biblical_references: Optional[List[str]] = None


class ChatState(AuthState):
    """Chat functionality state management."""
    
    # Chat messages
    messages: List[Message] = []
    current_message: str = ""
    
    # UI state
    is_typing: bool = False
    is_sending: bool = False
    chat_error: Optional[str] = None
    
    # Session management
    session_id: Optional[str] = None
    
    # Prayer connect state
    show_prayer_connect_modal: bool = False
    prayer_request_text: str = ""
    prayer_connect_consent: bool = False
    
    def set_current_message(self, message: str):
        """Set the current message being typed."""
        self.current_message = message
        self.chat_error = None
    
    def set_prayer_request_text(self, text: str):
        """Set prayer request text."""
        self.prayer_request_text = text
    
    def set_prayer_connect_consent(self, consent: bool):
        """Set prayer connect consent."""
        self.prayer_connect_consent = consent
    
    def show_prayer_connect(self):
        """Show prayer connect modal."""
        self.show_prayer_connect_modal = True
    
    def hide_prayer_connect(self):
        """Hide prayer connect modal."""
        self.show_prayer_connect_modal = False
        self.prayer_request_text = ""
        self.prayer_connect_consent = False
    
    async def send_message(self):
        """Send a message to the chatbot."""
        if not self.current_message.strip():
            return
        
        if not self.is_authenticated:
            self.chat_error = "Please log in to send messages"
            return
        
        self.is_sending = True
        self.chat_error = None
        
        # Create user message
        user_message = Message(
            id=f"msg_{len(self.messages)}_{datetime.now().timestamp()}",
            content=self.current_message.strip(),
            role="user",
            timestamp=datetime.now(),
        )
        
        # Add user message to chat
        self.messages.append(user_message)
        message_to_send = self.current_message
        self.current_message = ""
        
        # Show typing indicator
        self.is_typing = True
        
        try:
            # Get auth headers
            headers = await self.get_auth_headers()
            if not headers:
                self.chat_error = "Authentication required. Please log in again."
                return
            
            # Send message to API
            async with httpx.AsyncClient() as client:
                response = await client.post(
                    f"{rx.config.get_config().api_url}/chat/message",
                    json={
                        "message": message_to_send,
                        "session_id": self.session_id,
                    },
                    headers=headers,
                    timeout=30.0,
                )
                
                if response.status_code == 200:
                    response_data = response.json()
                    
                    # Update session ID if provided
                    if response_data.get("session_id"):
                        self.session_id = response_data["session_id"]
                    
                    # Create assistant message
                    assistant_message = Message(
                        id=f"msg_{len(self.messages)}_{datetime.now().timestamp()}",
                        content=response_data["response"],
                        role="assistant",
                        timestamp=datetime.now(),
                        emotion_classification=response_data.get("emotion_classification"),
                        biblical_references=response_data.get("biblical_references", []),
                    )
                    
                    # Add assistant message to chat
                    self.messages.append(assistant_message)
                    
                else:
                    error_data = response.json()
                    self.chat_error = error_data.get("detail", "Failed to send message")
                    
        except httpx.TimeoutException:
            self.chat_error = "Message request timed out. Please try again."
        except httpx.RequestError:
            self.chat_error = "Unable to connect to chat service."
        except Exception as e:
            self.chat_error = f"An unexpected error occurred: {str(e)}"
        finally:
            self.is_typing = False
            self.is_sending = False
    
    async def submit_prayer_request(self):
        """Submit a prayer request for community prayer."""
        if not self.prayer_request_text.strip():
            return
        
        if not self.prayer_connect_consent:
            self.chat_error = "Please provide consent to share your prayer request"
            return
        
        if not self.is_authenticated:
            self.chat_error = "Please log in to submit prayer requests"
            return
        
        self.is_sending = True
        self.chat_error = None
        
        try:
            # Get auth headers
            headers = await self.get_auth_headers()
            if not headers:
                self.chat_error = "Authentication required. Please log in again."
                return
            
            # Submit prayer request
            async with httpx.AsyncClient() as client:
                response = await client.post(
                    f"{rx.config.get_config().api_url}/prayer/request",
                    json={
                        "prayer_text": self.prayer_request_text.strip(),
                        "consent_given": self.prayer_connect_consent,
                    },
                    headers=headers,
                    timeout=30.0,
                )
                
                if response.status_code == 200:
                    # Success - hide modal and show confirmation
                    self.hide_prayer_connect()
                    
                    # Add confirmation message to chat
                    confirmation_message = Message(
                        id=f"msg_{len(self.messages)}_{datetime.now().timestamp()}",
                        content="Your prayer request has been submitted to the community. "
                                "You'll receive updates via email when others pray for you.",
                        role="assistant",
                        timestamp=datetime.now(),
                    )
                    self.messages.append(confirmation_message)
                    
                else:
                    error_data = response.json()
                    self.chat_error = error_data.get("detail", "Failed to submit prayer request")
                    
        except httpx.TimeoutException:
            self.chat_error = "Prayer request timed out. Please try again."
        except httpx.RequestError:
            self.chat_error = "Unable to connect to prayer service."
        except Exception as e:
            self.chat_error = f"An unexpected error occurred: {str(e)}"
        finally:
            self.is_sending = False
    
    async def load_chat_history(self):
        """Load chat history for the current user."""
        if not self.is_authenticated:
            return
        
        try:
            # Get auth headers
            headers = await self.get_auth_headers()
            if not headers:
                return
            
            # Load chat history
            async with httpx.AsyncClient() as client:
                response = await client.get(
                    f"{rx.config.get_config().api_url}/chat/history",
                    headers=headers,
                    timeout=30.0,
                )
                
                if response.status_code == 200:
                    history_data = response.json()
                    
                    # Convert to Message objects
                    self.messages = [
                        Message(
                            id=msg["id"],
                            content=msg["content"],
                            role=msg["role"],
                            timestamp=datetime.fromisoformat(msg["timestamp"]),
                            emotion_classification=msg.get("emotion_classification"),
                            biblical_references=msg.get("biblical_references", []),
                        )
                        for msg in history_data.get("messages", [])
                    ]
                    
                    # Set session ID if available
                    if history_data.get("session_id"):
                        self.session_id = history_data["session_id"]
                        
        except Exception:
            # Silently fail - chat history is not critical
            pass
    
    def clear_chat(self):
        """Clear the current chat session."""
        self.messages = []
        self.session_id = None
        self.current_message = ""
        self.chat_error = None