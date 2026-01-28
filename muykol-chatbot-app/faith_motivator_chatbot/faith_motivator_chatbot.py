"""Main application entry point for the Faith Motivator Chatbot."""

import reflex as rx
from faith_motivator_chatbot.components.navigation import navbar
from faith_motivator_chatbot.components.chat_components import chat_interface
from faith_motivator_chatbot.components.auth_components import login_modal
from faith_motivator_chatbot.state.auth_state import AuthState
from faith_motivator_chatbot.state.ui_state import UIState
from faith_motivator_chatbot.components.common import button


def index() -> rx.Component:
    """Main landing page component."""
    return rx.box(
        navbar(),
        rx.container(
            rx.vstack(
                rx.heading(
                    "Faith Motivator Chatbot",
                    size="2xl",
                    color="primary.700",
                    font_family="heading",
                    text_align="center",
                    margin_bottom="2rem",
                ),
                rx.text(
                    "Welcome to your personal faith companion. Share your thoughts, "
                    "receive biblical encouragement, and connect with a community of prayer.",
                    font_size="lg",
                    color="gray.600",
                    text_align="center",
                    margin_bottom="3rem",
                    max_width="600px",
                ),
                rx.cond(
                    AuthState.is_authenticated,
                    chat_interface(),
                    rx.vstack(
                        button(
                            "Get Started",
                            variant="primary",
                            size="lg",
                            on_click=UIState.show_login,
                        ),
                        rx.text(
                            "Sign in to start your faith journey with personalized biblical guidance.",
                            color="gray.500",
                            text_align="center",
                            font_size="sm",
                        ),
                        spacing="1rem",
                        align="center",
                    ),
                ),
                spacing="2rem",
                align="center",
                width="100%",
            ),
            max_width="1200px",
            padding="2rem",
        ),
        
        # Modals
        login_modal(),
        
        min_height="100vh",
        bg="gray.50",
    )


# Create the app
app = rx.App()
app.add_page(index, route="/")

if __name__ == "__main__":
    # Use the correct method to run the app
    app.run()