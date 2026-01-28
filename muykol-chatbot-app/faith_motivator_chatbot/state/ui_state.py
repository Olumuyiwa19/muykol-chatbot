"""UI state management for modals, notifications, and global UI state."""

import reflex as rx
from typing import Optional, Literal
from datetime import datetime, timedelta


class ToastNotification(rx.Base):
    """Toast notification model."""
    id: str
    message: str
    type: Literal["success", "error", "warning", "info"]
    timestamp: datetime
    duration: int = 5000  # milliseconds


class UIState(rx.State):
    """Global UI state management."""
    
    # Modal states
    show_login_modal: bool = False
    show_settings_modal: bool = False
    show_export_modal: bool = False
    
    # Toast notifications
    toast_notifications: list[ToastNotification] = []
    
    # Loading states
    is_page_loading: bool = False
    
    # Mobile navigation
    is_mobile_menu_open: bool = False
    
    # Theme preferences
    theme_mode: Literal["light", "dark", "system"] = "system"
    
    def show_login(self):
        """Show login modal."""
        self.show_login_modal = True
    
    def hide_login(self):
        """Hide login modal."""
        self.show_login_modal = False
    
    def show_settings(self):
        """Show settings modal."""
        self.show_settings_modal = True
    
    def hide_settings(self):
        """Hide settings modal."""
        self.show_settings_modal = False
    
    def show_export(self):
        """Show data export modal."""
        self.show_export_modal = True
    
    def hide_export(self):
        """Hide data export modal."""
        self.show_export_modal = False
    
    def toggle_mobile_menu(self):
        """Toggle mobile navigation menu."""
        self.is_mobile_menu_open = not self.is_mobile_menu_open
    
    def close_mobile_menu(self):
        """Close mobile navigation menu."""
        self.is_mobile_menu_open = False
    
    def set_theme_mode(self, mode: Literal["light", "dark", "system"]):
        """Set theme mode preference."""
        self.theme_mode = mode
    
    def add_toast(
        self,
        message: str,
        type_: Literal["success", "error", "warning", "info"] = "info",
        duration: int = 5000,
    ):
        """Add a toast notification."""
        toast = ToastNotification(
            id=f"toast_{datetime.now().timestamp()}",
            message=message,
            type=type_,
            timestamp=datetime.now(),
            duration=duration,
        )
        
        self.toast_notifications.append(toast)
        
        # Auto-remove after duration (this would need to be handled by a timer in real implementation)
        # For now, we'll limit to 5 notifications max
        if len(self.toast_notifications) > 5:
            self.toast_notifications = self.toast_notifications[-5:]
    
    def remove_toast(self, toast_id: str):
        """Remove a specific toast notification."""
        self.toast_notifications = [
            toast for toast in self.toast_notifications 
            if toast.id != toast_id
        ]
    
    def clear_all_toasts(self):
        """Clear all toast notifications."""
        self.toast_notifications = []
    
    def show_success_toast(self, message: str):
        """Show a success toast notification."""
        self.add_toast(message, "success")
    
    def show_error_toast(self, message: str):
        """Show an error toast notification."""
        self.add_toast(message, "error")
    
    def show_warning_toast(self, message: str):
        """Show a warning toast notification."""
        self.add_toast(message, "warning")
    
    def show_info_toast(self, message: str):
        """Show an info toast notification."""
        self.add_toast(message, "info")
    
    def set_page_loading(self, loading: bool):
        """Set page loading state."""
        self.is_page_loading = loading