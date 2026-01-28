"""Navigation components for the Faith Motivator Chatbot."""

import reflex as rx
from faith_motivator_chatbot.state.auth_state import AuthState
from faith_motivator_chatbot.state.ui_state import UIState
from faith_motivator_chatbot.components.common import button


def navbar() -> rx.Component:
    """Main navigation bar component."""
    return rx.box(
        rx.container(
            rx.hstack(
                # Logo and brand
                rx.hstack(
                    rx.icon(
                        "heart",
                        size="2rem",
                        color="primary.500",
                    ),
                    rx.heading(
                        "Faith Motivator",
                        size="lg",
                        color="primary.700",
                        font_family="heading",
                    ),
                    spacing="0.5rem",
                    align="center",
                ),
                
                # Desktop navigation
                rx.hstack(
                    rx.cond(
                        AuthState.is_authenticated,
                        rx.hstack(
                            rx.text(
                                f"Welcome, {AuthState.first_name or AuthState.email}",
                                color="gray.600",
                                font_weight="500",
                            ),
                            button(
                                "Settings",
                                variant="ghost",
                                size="sm",
                                icon="settings",
                                on_click=UIState.show_settings,
                            ),
                            button(
                                "Export Data",
                                variant="ghost",
                                size="sm",
                                icon="download",
                                on_click=UIState.show_export,
                            ),
                            button(
                                "Logout",
                                variant="outline",
                                size="sm",
                                icon="log-out",
                                on_click=AuthState.logout,
                                loading=AuthState.is_loading,
                            ),
                            spacing="1rem",
                            align="center",
                        ),
                        rx.hstack(
                            button(
                                "Login",
                                variant="primary",
                                size="sm",
                                on_click=UIState.show_login,
                            ),
                            spacing="1rem",
                            align="center",
                        ),
                    ),
                    display=["none", "none", "flex"],  # Hidden on mobile
                    spacing="1rem",
                    align="center",
                ),
                
                # Mobile menu button
                rx.button(
                    rx.icon("menu"),
                    variant="ghost",
                    size="sm",
                    on_click=UIState.toggle_mobile_menu,
                    display=["flex", "flex", "none"],  # Visible on mobile only
                    aria_label="Toggle menu",
                ),
                
                justify="space-between",
                align="center",
                width="100%",
            ),
            max_width="1200px",
            padding="0 1rem",
        ),
        
        # Mobile menu overlay
        rx.cond(
            UIState.is_mobile_menu_open,
            mobile_menu(),
        ),
        
        bg="white",
        border_bottom="1px solid",
        border_color="gray.200",
        position="sticky",
        top="0",
        z_index="100",
        box_shadow="0 1px 3px 0 rgba(0, 0, 0, 0.1)",
    )


def mobile_menu() -> rx.Component:
    """Mobile navigation menu."""
    return rx.box(
        # Backdrop
        rx.box(
            position="fixed",
            top="0",
            left="0",
            width="100vw",
            height="100vh",
            bg="rgba(0, 0, 0, 0.5)",
            z_index="200",
            on_click=UIState.close_mobile_menu,
        ),
        
        # Menu content
        rx.box(
            rx.vstack(
                # Header
                rx.hstack(
                    rx.heading(
                        "Menu",
                        size="md",
                        color="gray.800",
                    ),
                    rx.button(
                        rx.icon("x"),
                        variant="ghost",
                        size="sm",
                        on_click=UIState.close_mobile_menu,
                        aria_label="Close menu",
                    ),
                    justify="space-between",
                    align="center",
                    width="100%",
                    padding_bottom="1rem",
                    border_bottom="1px solid",
                    border_color="gray.200",
                ),
                
                # Menu items
                rx.cond(
                    AuthState.is_authenticated,
                    rx.vstack(
                        rx.text(
                            f"Welcome, {AuthState.first_name or AuthState.email}",
                            color="gray.600",
                            font_weight="500",
                            text_align="center",
                        ),
                        button(
                            "Settings",
                            variant="ghost",
                            size="md",
                            icon="settings",
                            on_click=lambda: [UIState.show_settings(), UIState.close_mobile_menu()],
                            width="100%",
                        ),
                        button(
                            "Export Data",
                            variant="ghost",
                            size="md",
                            icon="download",
                            on_click=lambda: [UIState.show_export(), UIState.close_mobile_menu()],
                            width="100%",
                        ),
                        button(
                            "Logout",
                            variant="outline",
                            size="md",
                            icon="log-out",
                            on_click=lambda: [AuthState.logout(), UIState.close_mobile_menu()],
                            loading=AuthState.is_loading,
                            width="100%",
                        ),
                        spacing="1rem",
                        align="stretch",
                        width="100%",
                    ),
                    rx.vstack(
                        button(
                            "Login",
                            variant="primary",
                            size="md",
                            on_click=lambda: [UIState.show_login(), UIState.close_mobile_menu()],
                            width="100%",
                        ),
                        spacing="1rem",
                        align="stretch",
                        width="100%",
                    ),
                ),
                
                spacing="1rem",
                align="stretch",
                width="100%",
            ),
            position="fixed",
            top="0",
            right="0",
            height="100vh",
            width="300px",
            bg="white",
            padding="1.5rem",
            z_index="201",
            box_shadow="-4px 0 6px -1px rgba(0, 0, 0, 0.1)",
        ),
    )


def protected_route(component: rx.Component) -> rx.Component:
    """Wrapper for protected routes that require authentication."""
    return rx.cond(
        AuthState.is_authenticated,
        component,
        rx.container(
            rx.vstack(
                rx.heading(
                    "Authentication Required",
                    size="xl",
                    color="gray.700",
                    text_align="center",
                ),
                rx.text(
                    "Please log in to access this page.",
                    color="gray.600",
                    text_align="center",
                    margin_bottom="2rem",
                ),
                button(
                    "Login",
                    variant="primary",
                    size="lg",
                    on_click=UIState.show_login,
                ),
                spacing="2rem",
                align="center",
                padding="4rem 2rem",
            ),
            max_width="600px",
            margin="0 auto",
        ),
    )