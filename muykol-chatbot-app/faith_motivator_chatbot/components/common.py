"""Common UI components with accessibility and consistent styling."""

import reflex as rx
from typing import Optional, Literal, Any, Dict


def button(
    text: str,
    variant: Literal["primary", "secondary", "outline", "ghost"] = "primary",
    size: Literal["sm", "md", "lg"] = "md",
    disabled: bool = False,
    loading: bool = False,
    icon: Optional[str] = None,
    on_click: Optional[rx.EventHandler] = None,
    **props
) -> rx.Component:
    """Accessible button component with consistent styling."""
    
    base_styles = {
        "border_radius": "0.5rem",
        "font_weight": "500",
        "transition": "all 0.2s",
        "cursor": "pointer" if not disabled else "not-allowed",
        "opacity": "0.6" if disabled else "1.0",
        "display": "inline-flex",
        "align_items": "center",
        "justify_content": "center",
        "border": "none",
    }
    
    variant_styles = {
        "primary": {
            "bg": "primary.500",
            "color": "white",
            "_hover": {"bg": "primary.600"} if not disabled else {},
            "_focus": {"box_shadow": "0 0 0 3px rgba(59, 130, 246, 0.3)"},
        },
        "secondary": {
            "bg": "gray.200",
            "color": "gray.800",
            "_hover": {"bg": "gray.300"} if not disabled else {},
            "_focus": {"box_shadow": "0 0 0 3px rgba(156, 163, 175, 0.3)"},
        },
        "outline": {
            "bg": "transparent",
            "border": "1px solid",
            "border_color": "primary.500",
            "color": "primary.500",
            "_hover": {"bg": "primary.50"} if not disabled else {},
            "_focus": {"box_shadow": "0 0 0 3px rgba(59, 130, 246, 0.3)"},
        },
        "ghost": {
            "bg": "transparent",
            "color": "gray.600",
            "_hover": {"bg": "gray.100"} if not disabled else {},
            "_focus": {"box_shadow": "0 0 0 3px rgba(156, 163, 175, 0.3)"},
        },
    }
    
    size_styles = {
        "sm": {"padding": "0.5rem 1rem", "font_size": "0.875rem", "min_height": "2rem"},
        "md": {"padding": "0.75rem 1.5rem", "font_size": "1rem", "min_height": "2.5rem"},
        "lg": {"padding": "1rem 2rem", "font_size": "1.125rem", "min_height": "3rem"},
    }
    
    return rx.button(
        rx.cond(
            loading,
            rx.spinner(size="sm", margin_right="0.5rem"),
        ),
        rx.cond(
            icon and not loading,
            rx.icon(icon, margin_right="0.5rem"),
        ),
        text,
        on_click=on_click if not disabled else None,
        disabled=disabled or loading,
        aria_disabled=disabled or loading,
        **{**base_styles, **variant_styles[variant], **size_styles[size], **props}
    )


def input_field(
    placeholder: str = "",
    value: str = "",
    on_change: Optional[rx.EventHandler] = None,
    type_: Literal["text", "email", "password", "tel"] = "text",
    required: bool = False,
    disabled: bool = False,
    error: Optional[str] = None,
    label: Optional[str] = None,
    **props
) -> rx.Component:
    """Accessible input field with validation styling."""
    
    input_id = f"input-{rx.utils.format.to_snake_case(label or placeholder)}"
    
    base_styles = {
        "width": "100%",
        "padding": "0.75rem",
        "border": "1px solid",
        "border_color": "red.300" if error else "gray.300",
        "border_radius": "0.5rem",
        "font_size": "1rem",
        "transition": "all 0.2s",
        "_focus": {
            "outline": "none",
            "border_color": "red.500" if error else "primary.500",
            "box_shadow": f"0 0 0 3px {'rgba(239, 68, 68, 0.3)' if error else 'rgba(59, 130, 246, 0.3)'}",
        },
        "_disabled": {
            "bg": "gray.100",
            "cursor": "not-allowed",
        },
    }
    
    return rx.vstack(
        rx.cond(
            label,
            rx.text(
                label,
                as_="label",
                html_for=input_id,
                font_weight="500",
                color="gray.700",
                margin_bottom="0.25rem",
            ),
        ),
        rx.input(
            placeholder=placeholder,
            value=value,
            on_change=on_change,
            type_=type_,
            required=required,
            disabled=disabled,
            id=input_id,
            aria_invalid=bool(error),
            aria_describedby=f"{input_id}-error" if error else None,
            **{**base_styles, **props}
        ),
        rx.cond(
            error,
            rx.text(
                error,
                id=f"{input_id}-error",
                color="red.500",
                font_size="0.875rem",
                margin_top="0.25rem",
            ),
        ),
        spacing="0",
        align="stretch",
        width="100%",
    )


def textarea_field(
    placeholder: str = "",
    value: str = "",
    on_change: Optional[rx.EventHandler] = None,
    rows: int = 4,
    required: bool = False,
    disabled: bool = False,
    error: Optional[str] = None,
    label: Optional[str] = None,
    **props
) -> rx.Component:
    """Accessible textarea field with validation styling."""
    
    textarea_id = f"textarea-{rx.utils.format.to_snake_case(label or placeholder)}"
    
    base_styles = {
        "width": "100%",
        "padding": "0.75rem",
        "border": "1px solid",
        "border_color": "red.300" if error else "gray.300",
        "border_radius": "0.5rem",
        "font_size": "1rem",
        "resize": "vertical",
        "transition": "all 0.2s",
        "_focus": {
            "outline": "none",
            "border_color": "red.500" if error else "primary.500",
            "box_shadow": f"0 0 0 3px {'rgba(239, 68, 68, 0.3)' if error else 'rgba(59, 130, 246, 0.3)'}",
        },
        "_disabled": {
            "bg": "gray.100",
            "cursor": "not-allowed",
        },
    }
    
    return rx.vstack(
        rx.cond(
            label,
            rx.text(
                label,
                as_="label",
                html_for=textarea_id,
                font_weight="500",
                color="gray.700",
                margin_bottom="0.25rem",
            ),
        ),
        rx.text_area(
            placeholder=placeholder,
            value=value,
            on_change=on_change,
            rows=rows,
            required=required,
            disabled=disabled,
            id=textarea_id,
            aria_invalid=bool(error),
            aria_describedby=f"{textarea_id}-error" if error else None,
            **{**base_styles, **props}
        ),
        rx.cond(
            error,
            rx.text(
                error,
                id=f"{textarea_id}-error",
                color="red.500",
                font_size="0.875rem",
                margin_top="0.25rem",
            ),
        ),
        spacing="0",
        align="stretch",
        width="100%",
    )


def modal(
    is_open: bool,
    on_close: rx.EventHandler,
    title: str,
    children: rx.Component,
    size: Literal["sm", "md", "lg", "xl"] = "md",
    **props
) -> rx.Component:
    """Accessible modal component with focus management."""
    
    size_styles = {
        "sm": {"max_width": "400px"},
        "md": {"max_width": "500px"},
        "lg": {"max_width": "700px"},
        "xl": {"max_width": "900px"},
    }
    
    return rx.cond(
        is_open,
        rx.box(
            # Backdrop
            rx.box(
                position="fixed",
                top="0",
                left="0",
                width="100vw",
                height="100vh",
                bg="rgba(0, 0, 0, 0.5)",
                z_index="1000",
                on_click=on_close,
            ),
            # Modal content
            rx.box(
                rx.vstack(
                    # Header
                    rx.hstack(
                        rx.heading(
                            title,
                            size="lg",
                            color="gray.800",
                        ),
                        rx.button(
                            rx.icon("x"),
                            on_click=on_close,
                            variant="ghost",
                            size="sm",
                            aria_label="Close modal",
                        ),
                        justify="space-between",
                        align="center",
                        width="100%",
                        padding_bottom="1rem",
                        border_bottom="1px solid",
                        border_color="gray.200",
                    ),
                    # Body
                    rx.box(
                        children,
                        padding="1rem 0",
                        width="100%",
                    ),
                    spacing="0",
                    width="100%",
                ),
                position="fixed",
                top="50%",
                left="50%",
                transform="translate(-50%, -50%)",
                bg="white",
                border_radius="0.5rem",
                box_shadow="0 25px 50px -12px rgba(0, 0, 0, 0.25)",
                padding="1.5rem",
                z_index="1001",
                role="dialog",
                aria_modal="true",
                **{**size_styles[size], **props}
            ),
        ),
    )


def loading_spinner(
    size: Literal["sm", "md", "lg"] = "md",
    color: str = "primary.500",
    **props
) -> rx.Component:
    """Loading spinner component."""
    
    size_styles = {
        "sm": {"width": "1rem", "height": "1rem"},
        "md": {"width": "1.5rem", "height": "1.5rem"},
        "lg": {"width": "2rem", "height": "2rem"},
    }
    
    return rx.spinner(
        color=color,
        **{**size_styles[size], **props}
    )


def toast_notification(
    message: str,
    type_: Literal["success", "error", "warning", "info"] = "info",
    is_visible: bool = True,
    on_close: Optional[rx.EventHandler] = None,
    **props
) -> rx.Component:
    """Toast notification component."""
    
    type_styles = {
        "success": {
            "bg": "green.50",
            "border_color": "green.200",
            "color": "green.800",
            "icon": "check-circle",
        },
        "error": {
            "bg": "red.50",
            "border_color": "red.200",
            "color": "red.800",
            "icon": "x-circle",
        },
        "warning": {
            "bg": "yellow.50",
            "border_color": "yellow.200",
            "color": "yellow.800",
            "icon": "alert-triangle",
        },
        "info": {
            "bg": "blue.50",
            "border_color": "blue.200",
            "color": "blue.800",
            "icon": "info",
        },
    }
    
    styles = type_styles[type_]
    
    return rx.cond(
        is_visible,
        rx.box(
            rx.hstack(
                rx.icon(
                    styles["icon"],
                    color=styles["color"],
                    size="1.25rem",
                ),
                rx.text(
                    message,
                    color=styles["color"],
                    font_weight="500",
                    flex="1",
                ),
                rx.cond(
                    on_close,
                    rx.button(
                        rx.icon("x", size="1rem"),
                        on_click=on_close,
                        variant="ghost",
                        size="sm",
                        color=styles["color"],
                        aria_label="Close notification",
                    ),
                ),
                spacing="0.75rem",
                align="center",
                width="100%",
            ),
            bg=styles["bg"],
            border="1px solid",
            border_color=styles["border_color"],
            border_radius="0.5rem",
            padding="1rem",
            position="fixed",
            top="1rem",
            right="1rem",
            max_width="400px",
            z_index="1000",
            box_shadow="0 10px 15px -3px rgba(0, 0, 0, 0.1)",
            **props
        ),
    )