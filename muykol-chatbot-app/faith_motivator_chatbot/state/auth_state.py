"""Authentication state management using Reflex State."""

import reflex as rx
from typing import Optional, Dict, Any
import httpx
from datetime import datetime, timedelta


class AuthState(rx.State):
    """Authentication state management."""
    
    # User authentication status
    is_authenticated: bool = False
    user_id: Optional[str] = None
    email: Optional[str] = None
    first_name: Optional[str] = None
    
    # Authentication tokens
    access_token: Optional[str] = None
    refresh_token: Optional[str] = None
    token_expires_at: Optional[datetime] = None
    
    # UI state
    is_loading: bool = False
    auth_error: Optional[str] = None
    
    # Login form state
    login_email: str = ""
    login_password: str = ""
    
    def set_login_email(self, email: str):
        """Set login email."""
        self.login_email = email
        self.auth_error = None
    
    def set_login_password(self, password: str):
        """Set login password."""
        self.login_password = password
        self.auth_error = None
    
    async def login(self):
        """Authenticate user with email and password."""
        if not self.login_email or not self.login_password:
            self.auth_error = "Please enter both email and password"
            return
        
        self.is_loading = True
        self.auth_error = None
        
        try:
            # Call authentication API
            async with httpx.AsyncClient() as client:
                response = await client.post(
                    f"{rx.config.get_config().api_url}/auth/login",
                    json={
                        "email": self.login_email,
                        "password": self.login_password,
                    },
                    timeout=30.0,
                )
                
                if response.status_code == 200:
                    auth_data = response.json()
                    await self._set_auth_data(auth_data)
                    
                    # Clear login form
                    self.login_email = ""
                    self.login_password = ""
                else:
                    error_data = response.json()
                    self.auth_error = error_data.get("detail", "Login failed")
                    
        except httpx.TimeoutException:
            self.auth_error = "Login request timed out. Please try again."
        except httpx.RequestError:
            self.auth_error = "Unable to connect to authentication service."
        except Exception as e:
            self.auth_error = f"An unexpected error occurred: {str(e)}"
        finally:
            self.is_loading = False
    
    async def logout(self):
        """Log out the current user."""
        self.is_loading = True
        
        try:
            # Call logout API if we have a token
            if self.access_token:
                async with httpx.AsyncClient() as client:
                    await client.post(
                        f"{rx.config.get_config().api_url}/auth/logout",
                        headers={"Authorization": f"Bearer {self.access_token}"},
                        timeout=10.0,
                    )
        except Exception:
            # Ignore logout API errors - clear local state anyway
            pass
        finally:
            await self._clear_auth_data()
            self.is_loading = False
    
    async def refresh_access_token(self) -> bool:
        """Refresh the access token using the refresh token."""
        if not self.refresh_token:
            return False
        
        try:
            async with httpx.AsyncClient() as client:
                response = await client.post(
                    f"{rx.config.get_config().api_url}/auth/refresh",
                    json={"refresh_token": self.refresh_token},
                    timeout=30.0,
                )
                
                if response.status_code == 200:
                    auth_data = response.json()
                    await self._set_auth_data(auth_data)
                    return True
                else:
                    # Refresh failed, clear auth data
                    await self._clear_auth_data()
                    return False
                    
        except Exception:
            await self._clear_auth_data()
            return False
    
    def is_token_expired(self) -> bool:
        """Check if the current access token is expired."""
        if not self.token_expires_at:
            return True
        return datetime.now() >= self.token_expires_at
    
    async def get_auth_headers(self) -> Dict[str, str]:
        """Get authentication headers for API requests."""
        if not self.access_token:
            return {}
        
        # Check if token is expired and try to refresh
        if self.is_token_expired():
            if not await self.refresh_access_token():
                return {}
        
        return {"Authorization": f"Bearer {self.access_token}"}
    
    async def _set_auth_data(self, auth_data: Dict[str, Any]):
        """Set authentication data from API response."""
        self.is_authenticated = True
        self.user_id = auth_data.get("user_id")
        self.email = auth_data.get("email")
        self.first_name = auth_data.get("first_name")
        self.access_token = auth_data.get("access_token")
        self.refresh_token = auth_data.get("refresh_token")
        
        # Calculate token expiration
        expires_in = auth_data.get("expires_in", 3600)  # Default 1 hour
        self.token_expires_at = datetime.now() + timedelta(seconds=expires_in)
    
    async def _clear_auth_data(self):
        """Clear all authentication data."""
        self.is_authenticated = False
        self.user_id = None
        self.email = None
        self.first_name = None
        self.access_token = None
        self.refresh_token = None
        self.token_expires_at = None
        self.auth_error = None