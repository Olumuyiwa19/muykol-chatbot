"""Chat interface components."""

import reflex as rx
from faith_motivator_chatbot.state.chat_state import ChatState, Message
from faith_motivator_chatbot.components.common import button, textarea_field, modal


def chat_interface() -> rx.Component:
    """Main chat interface component."""
    return rx.vstack(
        # Chat messages area
        rx.box(
            rx.cond(
                ChatState.messages,
                rx.vstack(
                    rx.foreach(
                        ChatState.messages,
                        message_bubble,
                    ),
                    rx.cond(
                        ChatState.is_typing,
                        typing_indicator(),
                    ),
                    spacing="1rem",
                    align="stretch",
                    width="100%",
                ),
                # Empty state
                rx.vstack(
                    rx.icon(
                        "message-circle",
                        size="3rem",
                        color="gray.400",
                    ),
                    rx.heading(
                        "Start a Conversation",
                        size="lg",
                        color="gray.600",
                        text_align="center",
                    ),
                    rx.text(
                        "Share what's on your heart. I'm here to listen and provide "
                        "biblical encouragement and support.",
                        color="gray.500",
                        text_align="center",
                        max_width="400px",
                    ),
                    spacing="1rem",
                    align="center",
                    justify="center",
                    height="300px",
                ),
            ),
            height="400px",
            overflow_y="auto",
            padding="1rem",
            border="1px solid",
            border_color="gray.200",
            border_radius="0.5rem",
            bg="gray.50",
            margin_bottom="1rem",
        ),
        
        # Error message
        rx.cond(
            ChatState.chat_error,
            rx.box(
                rx.text(
                    ChatState.chat_error,
                    color="red.500",
                    font_size="0.875rem",
                ),
                bg="red.50",
                border="1px solid",
                border_color="red.200",
                border_radius="0.5rem",
                padding="0.75rem",
                margin_bottom="1rem",
                width="100%",
            ),
        ),
        
        # Message input area
        rx.vstack(
            textarea_field(
                placeholder="Type your message here... Share what's on your heart.",
                value=ChatState.current_message,
                on_change=ChatState.set_current_message,
                rows=3,
                disabled=ChatState.is_sending or ChatState.is_typing,
            ),
            
            rx.hstack(
                button(
                    "Prayer Connect",
                    variant="outline",
                    size="md",
                    icon="heart",
                    on_click=ChatState.show_prayer_connect,
                    disabled=ChatState.is_sending or ChatState.is_typing,
                ),
                rx.spacer(),
                button(
                    "Send Message",
                    variant="primary",
                    size="md",
                    icon="send",
                    on_click=ChatState.send_message,
                    loading=ChatState.is_sending,
                    disabled=ChatState.is_sending or ChatState.is_typing or (ChatState.current_message.strip() == ""),
                ),
                justify="space-between",
                align="center",
                width="100%",
            ),
            
            spacing="1rem",
            align="stretch",
            width="100%",
        ),
        
        # Prayer connect modal
        prayer_connect_modal(),
        
        spacing="0",
        align="stretch",
        width="100%",
        max_width="800px",
        margin="0 auto",
    )


def message_bubble(message: Message) -> rx.Component:
    """Individual message bubble component."""
    is_user = message.role == "user"
    
    return rx.box(
        rx.vstack(
            # Message content
            rx.text(
                message.content,
                color="white" if is_user else "gray.800",
                font_size="1rem",
                line_height="1.5",
                white_space="pre-wrap",
            ),
            
            # Biblical references (for assistant messages)
            rx.cond(
                message.biblical_references and not is_user,
                rx.vstack(
                    rx.text(
                        "Biblical References:",
                        font_weight="600",
                        color="gray.700",
                        font_size="0.875rem",
                        margin_top="0.5rem",
                    ),
                    rx.foreach(
                        message.biblical_references,
                        lambda ref: rx.text(
                            f"• {ref}",
                            color="gray.600",
                            font_size="0.875rem",
                            font_style="italic",
                        ),
                    ),
                    spacing="0.25rem",
                    align="start",
                    width="100%",
                ),
            ),
            
            # Timestamp
            rx.text(
                message.timestamp.strftime("%I:%M %p"),
                color="gray.300" if is_user else "gray.500",
                font_size="0.75rem",
                margin_top="0.5rem",
            ),
            
            spacing="0",
            align="start" if not is_user else "end",
            width="100%",
        ),
        bg="primary.500" if is_user else "white",
        border="1px solid" if not is_user else "none",
        border_color="gray.200" if not is_user else "transparent",
        padding="1rem",
        border_radius="1rem",
        margin_left="auto" if is_user else "0",
        margin_right="0" if is_user else "auto",
        max_width="75%",
        box_shadow="0 1px 3px 0 rgba(0, 0, 0, 0.1)" if not is_user else "none",
    )


def typing_indicator() -> rx.Component:
    """Typing indicator component."""
    return rx.box(
        rx.hstack(
            rx.box(
                rx.hstack(
                    rx.box(
                        width="0.5rem",
                        height="0.5rem",
                        bg="gray.400",
                        border_radius="50%",
                        animation="pulse 1.4s ease-in-out infinite both",
                    ),
                    rx.box(
                        width="0.5rem",
                        height="0.5rem",
                        bg="gray.400",
                        border_radius="50%",
                        animation="pulse 1.4s ease-in-out 0.2s infinite both",
                    ),
                    rx.box(
                        width="0.5rem",
                        height="0.5rem",
                        bg="gray.400",
                        border_radius="50%",
                        animation="pulse 1.4s ease-in-out 0.4s infinite both",
                    ),
                    spacing="0.25rem",
                    align="center",
                ),
                padding="1rem",
                bg="white",
                border="1px solid",
                border_color="gray.200",
                border_radius="1rem",
                box_shadow="0 1px 3px 0 rgba(0, 0, 0, 0.1)",
            ),
            rx.text(
                "Assistant is typing...",
                color="gray.500",
                font_size="0.875rem",
                font_style="italic",
                margin_left="0.5rem",
            ),
            spacing="0.5rem",
            align="center",
        ),
        max_width="75%",
    )


def prayer_connect_modal() -> rx.Component:
    """Prayer connect modal for submitting prayer requests."""
    return modal(
        is_open=ChatState.show_prayer_connect_modal,
        on_close=ChatState.hide_prayer_connect,
        title="Connect for Prayer",
        children=rx.vstack(
            # Introduction
            rx.text(
                "Share your prayer request with our faith community. Your request will be "
                "sent to volunteer prayer partners who will pray for you and provide support.",
                color="gray.600",
                line_height="1.6",
                margin_bottom="1.5rem",
            ),
            
            # Prayer request form
            rx.form(
                rx.vstack(
                    textarea_field(
                        label="Prayer Request",
                        placeholder="Please share what you'd like prayer for...",
                        value=ChatState.prayer_request_text,
                        on_change=ChatState.set_prayer_request_text,
                        rows=5,
                        required=True,
                    ),
                    
                    # Consent checkbox
                    rx.hstack(
                        rx.checkbox(
                            checked=ChatState.prayer_connect_consent,
                            on_change=ChatState.set_prayer_connect_consent,
                            color_scheme="blue",
                        ),
                        rx.text(
                            "I consent to sharing this prayer request with volunteer prayer "
                            "partners and understand that I may receive follow-up communication.",
                            color="gray.600",
                            font_size="0.875rem",
                            line_height="1.5",
                        ),
                        spacing="0.75rem",
                        align="start",
                        width="100%",
                    ),
                    
                    # Privacy notice
                    rx.box(
                        rx.text(
                            "Privacy Notice: Your prayer request will only be shared with "
                            "verified prayer partners. We never share personal information "
                            "beyond what you choose to include in your request.",
                            color="gray.500",
                            font_size="0.75rem",
                            line_height="1.4",
                        ),
                        bg="gray.50",
                        border="1px solid",
                        border_color="gray.200",
                        border_radius="0.5rem",
                        padding="0.75rem",
                        width="100%",
                    ),
                    
                    # Action buttons
                    rx.hstack(
                        button(
                            "Cancel",
                            variant="outline",
                            size="md",
                            on_click=ChatState.hide_prayer_connect,
                            disabled=ChatState.is_sending,
                        ),
                        button(
                            "Submit Prayer Request",
                            variant="primary",
                            size="md",
                            type_="submit",
                            loading=ChatState.is_sending,
                            disabled=ChatState.is_sending or not ChatState.prayer_connect_consent or not ChatState.prayer_request_text.strip(),
                        ),
                        spacing="1rem",
                        justify="end",
                        width="100%",
                    ),
                    
                    spacing="1.5rem",
                    align="stretch",
                    width="100%",
                ),
                on_submit=ChatState.submit_prayer_request,
                width="100%",
            ),
            
            spacing="0",
            align="stretch",
            width="100%",
        ),
        size="lg",
    )