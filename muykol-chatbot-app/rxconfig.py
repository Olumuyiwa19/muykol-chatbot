"""Reflex configuration file for the Faith Motivator Chatbot."""

import reflex as rx

config = rx.Config(
    app_name="faith_motivator_chatbot",
    frontend_port=3000,
    backend_port=8000,
    
    # Environment configuration
    env=rx.Env.DEV,
    
    # Disable sitemap plugin to avoid warnings
    disable_plugins=["reflex.plugins.sitemap.SitemapPlugin"],
    
    # Styling configuration
    tailwind={
        "theme": {
            "extend": {
                "colors": {
                    "primary": {
                        "50": "#eff6ff",
                        "100": "#dbeafe", 
                        "500": "#3b82f6",
                        "600": "#2563eb",
                        "700": "#1d4ed8",
                    },
                    "secondary": {
                        "50": "#fffbeb",
                        "100": "#fef3c7",
                        "500": "#f59e0b", 
                        "600": "#d97706",
                    },
                    "accent": {
                        "50": "#faf5ff",
                        "100": "#f3e8ff",
                        "500": "#8b5cf6",
                        "600": "#7c3aed",
                    }
                },
                "fontFamily": {
                    "primary": ["Inter", "system-ui", "sans-serif"],
                    "heading": ["Playfair Display", "serif"],
                }
            }
        }
    },
    
    # API configuration
    api_url="http://localhost:8000",
    
    # Build configuration
    compile=False,
    
    # Database URL for development
    db_url="sqlite:///reflex.db",
)