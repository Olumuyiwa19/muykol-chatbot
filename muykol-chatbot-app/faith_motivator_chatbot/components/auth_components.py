"""Authentication UI components."""

import reflex as rx
from faith_motivator_chatbot.state.auth_state import AuthState
from faith_motivator_chatbot.state.ui_state import UIState
from faith_motivator_chatbot.components.common import button, input_field, modal


def login_modal() -> rx.Component:
    """Login modal component."""
    return modal(
        is_open=UIState.show_login_modal,
        on_close=UIState.hide_login,
        title="Sign In to Faith Motivator",
        children=rx.vstack(
            # Login form
            rx.form(
                rx.vstack(
                    input_field(
                        label="Email Address",
                        placeholder="Enter your email",
                        type_="email",
                        value=AuthState.login_email,
                        on_change=AuthState.set_login_email,
                        required=True,
                        error=AuthState.auth_error if "@" in (AuthState.auth_error or "") else None,
                    ),
                    input_field(
                        label="Password",
                        placeholder="Enter your password",
                        type_="password",
                        value=AuthState.login_password,
                        on_change=AuthState.set_login_password,
                        required=True,
                        error=AuthState.auth_error if "password" in (AuthState.auth_error or "").lower() else None,
                    ),
                    
                    # Error message
                    rx.cond(
                        AuthState.auth_error,
                        rx.box(
                            rx.text(
                                AuthState.auth_error,
                                color="red.500",
                                font_size="0.875rem",
                                text_align="center",
                            ),
                            bg="red.50",
                            border="1px solid",
                            border_color="red.200",
                            border_radius="0.5rem",
                            padding="0.75rem",
                            width="100%",
                        ),
                    ),
                    
                    # Login button
                    button(
                        "Sign In",
                        type_="submit",
                        variant="primary",
                        size="lg",
                        loading=AuthState.is_loading,
                        disabled=AuthState.is_loading,
                        width="100%",
                    ),
                    
                    spacing="1.5rem",
                    align="stretch",
                    width="100%",
                ),
                on_submit=AuthState.login,
                width="100%",
            ),
            
            # Divider
            rx.box(
                rx.text(
                    "or",
                    color="gray.500",
                    font_size="0.875rem",
                    text_align="center",
                    bg="white",
                    padding="0 1rem",
                ),
                position="relative",
                text_align="center",
                margin="1.5rem 0",
                _before={
                    "content": "''",
                    "position": "absolute",
                    "top": "50%",
                    "left": "0",
                    "right": "0",
                    "height": "1px",
                    "bg": "gray.200",
                    "z_index": "-1",
                },
            ),
            
            # Social login options (placeholder for future implementation)
            rx.vstack(
                button(
                    "Continue with Google",
                    variant="outline",
                    size="lg",
                    icon="chrome",  # Using chrome as Google icon placeholder
                    width="100%",
                    disabled=True,  # Disabled for now
                ),
                rx.text(
                    "Social login coming soon",
                    color="gray.500",
                    font_size="0.75rem",
                    text_align="center",
                ),
                spacing="0.5rem",
                align="stretch",
                width="100%",
            ),
            
            # Sign up link
            rx.box(
                rx.text(
                    "Don't have an account? ",
                    color="gray.600",
                    font_size="0.875rem",
                    display="inline",
                ),
                rx.text(
                    "Contact us to get started",
                    color="primary.500",
                    font_size="0.875rem",
                    font_weight="500",
                    display="inline",
                    cursor="pointer",
                    _hover={"text_decoration": "underline"},
                ),
                text_align="center",
                margin_top="1rem",
            ),
            
            spacing="0",
            align="stretch",
            width="100%",
        ),
        size="md",
    )


def user_profile_section() -> rx.Component:
    """User profile section for authenticated users."""
    return rx.cond(
        AuthState.is_authenticated,
        rx.box(
            rx.vstack(
                rx.hstack(
                    rx.box(
                        rx.text(
                            (AuthState.first_name or AuthState.email or "U")[0].upper(),
                            color="white",
                            font_weight="bold",
                            font_size="1.25rem",
                        ),
                        bg="primary.500",
                        border_radius="50%",
                        width="3rem",
                        height="3rem",
                        display="flex",
                        align_items="center",
                        justify_content="center",
                    ),
                    rx.vstack(
                        rx.text(
                            AuthState.first_name or "User",
                            font_weight="600",
                            color="gray.800",
                        ),
                        rx.text(
                            AuthState.email,
                            font_size="0.875rem",
                            color="gray.600",
                        ),
                        spacing="0.25rem",
                        align="start",
                    ),
                    spacing="1rem",
                    align="center",
                ),
                
                rx.hstack(
                    button(
                        "Settings",
                        variant="outline",
                        size="sm",
                        icon="settings",
                        on_click=UIState.show_settings,
                    ),
                    button(
                        "Export Data",
                        variant="outline",
                        size="sm",
                        icon="download",
                        on_click=UIState.show_export,
                    ),
                    button(
                        "Logout",
                        variant="ghost",
                        size="sm",
                        icon="log-out",
                        on_click=AuthState.logout,
                        loading=AuthState.is_loading,
                    ),
                    spacing="0.5rem",
                    justify="center",
                    width="100%",
                ),
                
                spacing="1.5rem",
                align="center",
                width="100%",
            ),
            bg="white",
            border="1px solid",
            border_color="gray.200",
            border_radius="0.5rem",
            padding="1.5rem",
            box_shadow="0 1px 3px 0 rgba(0, 0, 0, 0.1)",
        ),
    )