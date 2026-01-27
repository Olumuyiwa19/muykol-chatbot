# Phase 0: Pre-Implementation Setup - Design Document

## Architecture Overview

Phase 0 establishes the foundational specifications and development environment required for successful implementation of the faith-based motivator chatbot. This includes frontend architecture, environment management, and local development setup.

## 1. Frontend Architecture Design

### Technology Stack
```python
# Core Technologies
- Framework: Reflex (Python-based React framework)
- Language: Python 3.9+
- Styling: Reflex built-in styling system + Custom CSS
- State Management: Reflex State classes
- Authentication: AWS Cognito integration
- API Client: httpx for async HTTP requests
- Testing: pytest + pytest-asyncio
- Build Tool: Reflex CLI
```

### Component Architecture
```
muykol-chatbot-app/
├── frontend/                     # Reflex application
│   ├── chatbot_app.py           # Main app entry point
│   ├── components/              # Reusable components
│   │   ├── __init__.py
│   │   ├── auth_components.py   # Authentication UI
│   │   ├── chat_components.py   # Chat interface
│   │   ├── common.py           # Shared components
│   │   ├── export_components.py # Data export UI
│   │   ├── history_components.py # Chat history
│   │   └── navigation.py       # Navigation components
│   ├── state/                   # Application state management
│   │   ├── __init__.py
│   │   ├── auth_state.py       # Authentication state
│   │   ├── chat_state.py       # Chat functionality state
│   │   ├── export_state.py     # Data export state
│   │   └── rate_limit_state.py # Rate limiting state
│   ├── services/               # API integration
│   │   ├── __init__.py
│   │   ├── api_service.py      # Backend API client
│   │   └── auth_service.py     # Authentication service
│   ├── config.py               # Configuration management
│   ├── requirements.txt        # Python dependencies
│   └── rxconfig.py            # Reflex configuration
```

### Design System Specification

#### Color Palette
```css
/* Primary Colors - Faith-inspired palette */
:root {
  /* Primary - Deep Blue (Trust, Peace) */
  --color-primary-50: #eff6ff;
  --color-primary-100: #dbeafe;
  --color-primary-500: #3b82f6;
  --color-primary-600: #2563eb;
  --color-primary-700: #1d4ed8;
  
  /* Secondary - Warm Gold (Hope, Light) */
  --color-secondary-50: #fffbeb;
  --color-secondary-100: #fef3c7;
  --color-secondary-500: #f59e0b;
  --color-secondary-600: #d97706;
  
  /* Accent - Soft Purple (Spirituality) */
  --color-accent-50: #faf5ff;
  --color-accent-100: #f3e8ff;
  --color-accent-500: #8b5cf6;
  --color-accent-600: #7c3aed;
  
  /* Neutrals */
  --color-gray-50: #f9fafb;
  --color-gray-100: #f3f4f6;
  --color-gray-500: #6b7280;
  --color-gray-700: #374151;
  --color-gray-900: #111827;
  
  /* Semantic Colors */
  --color-success: #10b981;
  --color-warning: #f59e0b;
  --color-error: #ef4444;
  --color-info: #3b82f6;
}
```

#### Typography Scale
```css
/* Font Families */
--font-primary: 'Inter', system-ui, sans-serif;
--font-heading: 'Playfair Display', serif;

/* Font Sizes */
--text-xs: 0.75rem;    /* 12px */
--text-sm: 0.875rem;   /* 14px */
--text-base: 1rem;     /* 16px */
--text-lg: 1.125rem;   /* 18px */
--text-xl: 1.25rem;    /* 20px */
--text-2xl: 1.5rem;    /* 24px */
--text-3xl: 1.875rem;  /* 30px */
--text-4xl: 2.25rem;   /* 36px */
```

#### Component Specifications

##### Button Component
```python
import reflex as rx
from typing import Optional, Literal

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
    """Reusable button component with consistent styling"""
    
    base_styles = {
        "border_radius": "0.5rem",
        "font_weight": "500",
        "transition": "all 0.2s",
        "cursor": "pointer" if not disabled else "not-allowed",
        "opacity": "0.6" if disabled else "1.0",
    }
    
    variant_styles = {
        "primary": {
            "bg": "blue.500",
            "color": "white",
            "_hover": {"bg": "blue.600"},
        },
        "secondary": {
            "bg": "gray.200",
            "color": "gray.800",
            "_hover": {"bg": "gray.300"},
        },
        "outline": {
            "border": "1px solid",
            "border_color": "blue.500",
            "color": "blue.500",
            "_hover": {"bg": "blue.50"},
        },
        "ghost": {
            "bg": "transparent",
            "color": "gray.600",
            "_hover": {"bg": "gray.100"},
        },
    }
    
    size_styles = {
        "sm": {"padding": "0.5rem 1rem", "font_size": "0.875rem"},
        "md": {"padding": "0.75rem 1.5rem", "font_size": "1rem"},
        "lg": {"padding": "1rem 2rem", "font_size": "1.125rem"},
    }
    
    return rx.button(
        rx.cond(
            loading,
            rx.spinner(size="sm", margin_right="0.5rem"),
        ),
        rx.cond(
            icon,
            rx.icon(icon, margin_right="0.5rem"),
        ),
        text,
        on_click=on_click if not disabled else None,
        **{**base_styles, **variant_styles[variant], **size_styles[size], **props}
    )

# Usage Examples:
# button("Send Message", variant="primary", size="md")
# button("Connect for Prayer", variant="outline", size="sm", icon="heart")
```

##### Chat Interface Component
```python
import reflex as rx
from typing import List, Dict, Any

class ChatState(rx.State):
    messages: List[Dict[str, Any]] = []
    current_message: str = ""
    is_typing: bool = False
    
    async def send_message(self):
        if not self.current_message.strip():
            return
            
        # Add user message
        user_message = {
            "id": f"msg_{len(self.messages)}",
            "content": self.current_message,
            "role": "user",
            "timestamp": rx.moment().format("YYYY-MM-DD HH:mm:ss"),
        }
        self.messages.append(user_message)
        
        # Clear input and show typing
        message_to_send = self.current_message
        self.current_message = ""
        self.is_typing = True
        
        # Call backend API (implementation in services)
        # response = await api_service.send_message(message_to_send)
        
        # Add assistant response (mock for now)
        assistant_message = {
            "id": f"msg_{len(self.messages)}",
            "content": "Thank you for sharing. I'm here to listen and support you.",
            "role": "assistant",
            "timestamp": rx.moment().format("YYYY-MM-DD HH:mm:ss"),
        }
        self.messages.append(assistant_message)
        self.is_typing = False

def chat_interface() -> rx.Component:
    """Main chat interface component"""
    return rx.vstack(
        # Chat messages area
        rx.box(
            rx.foreach(
                ChatState.messages,
                lambda message: message_bubble(message)
            ),
            rx.cond(
                ChatState.is_typing,
                typing_indicator(),
            ),
            height="400px",
            overflow_y="auto",
            padding="1rem",
            border="1px solid",
            border_color="gray.200",
            border_radius="0.5rem",
            margin_bottom="1rem",
        ),
        
        # Message input area
        rx.hstack(
            rx.input(
                placeholder="Type your message here...",
                value=ChatState.current_message,
                on_change=ChatState.set_current_message,
                flex="1",
                padding="0.75rem",
                border_radius="0.5rem",
            ),
            button(
                "Send",
                variant="primary",
                on_click=ChatState.send_message,
                disabled=ChatState.is_typing,
            ),
            width="100%",
        ),
        width="100%",
        max_width="800px",
        margin="0 auto",
    )

def message_bubble(message: Dict[str, Any]) -> rx.Component:
    """Individual message bubble component"""
    is_user = message["role"] == "user"
    
    return rx.box(
        rx.text(
            message["content"],
            color="white" if is_user else "gray.800",
            font_size="1rem",
            line_height="1.5",
        ),
        rx.text(
            message["timestamp"],
            color="gray.300" if is_user else "gray.500",
            font_size="0.75rem",
            margin_top="0.25rem",
        ),
        bg="blue.500" if is_user else "gray.100",
        padding="1rem",
        border_radius="1rem",
        margin_bottom="1rem",
        margin_left="auto" if is_user else "0",
        margin_right="0" if is_user else "auto",
        max_width="70%",
    )

def typing_indicator() -> rx.Component:
    """Typing indicator component"""
    return rx.box(
        rx.hstack(
            rx.text("Assistant is typing"),
            rx.spinner(size="sm"),
            spacing="0.5rem",
        ),
        color="gray.500",
        font_style="italic",
        padding="0.5rem",
    )
```

### Responsive Design Breakpoints
```css
/* Mobile First Approach */
/* xs: 0px - 475px (default) */
/* sm: 476px - 639px */
@media (min-width: 476px) { /* Small phones */ }

/* md: 640px - 767px */
@media (min-width: 640px) { /* Large phones */ }

/* lg: 768px - 1023px */
@media (min-width: 768px) { /* Tablets */ }

/* xl: 1024px - 1279px */
@media (min-width: 1024px) { /* Small desktops */ }

/* 2xl: 1280px+ */
@media (min-width: 1280px) { /* Large desktops */ }
```

### Accessibility Implementation

#### WCAG 2.1 AA Compliance Checklist
```typescript
// Accessibility utilities
export const a11yUtils = {
  // Focus management
  trapFocus: (element: HTMLElement) => { /* implementation */ },
  restoreFocus: (element: HTMLElement) => { /* implementation */ },
  
  // ARIA helpers
  generateId: (prefix: string) => `${prefix}-${Math.random().toString(36)}`,
  announceToScreenReader: (message: string) => { /* implementation */ },
  
  // Keyboard navigation
  handleEscapeKey: (callback: () => void) => { /* implementation */ },
  handleEnterSpace: (callback: () => void) => { /* implementation */ },
};

// Example accessible component
const AccessibleButton: React.FC<ButtonProps> = ({
  children,
  disabled,
  loading,
  ...props
}) => (
  <button
    {...props}
    disabled={disabled || loading}
    aria-disabled={disabled || loading}
    aria-describedby={loading ? 'loading-text' : undefined}
  >
    {loading && <span id="loading-text" className="sr-only">Loading</span>}
    {children}
  </button>
);
```

## 2. Environment Management Design

### Configuration Schema
```typescript
// config/schema.ts
import { z } from 'zod';

export const ConfigSchema = z.object({
  // Application
  NODE_ENV: z.enum(['development', 'staging', 'production']),
  PORT: z.coerce.number().default(3000),
  APP_URL: z.string().url(),
  
  // AWS Configuration
  AWS_REGION: z.string().default('us-east-1'),
  AWS_ACCESS_KEY_ID: z.string().optional(),
  AWS_SECRET_ACCESS_KEY: z.string().optional(),
  
  // Cognito
  COGNITO_USER_POOL_ID: z.string(),
  COGNITO_CLIENT_ID: z.string(),
  COGNITO_DOMAIN: z.string(),
  
  // API Configuration
  API_BASE_URL: z.string().url(),
  API_TIMEOUT: z.coerce.number().default(30000),
  
  // Feature Flags
  ENABLE_PRAYER_CONNECT: z.coerce.boolean().default(true),
  ENABLE_ANALYTICS: z.coerce.boolean().default(false),
  
  // Monitoring
  LOG_LEVEL: z.enum(['debug', 'info', 'warn', 'error']).default('info'),
  SENTRY_DSN: z.string().optional(),
});

export type Config = z.infer<typeof ConfigSchema>;
```

### Environment Files Structure
```bash
# .env.local (development)
NODE_ENV=development
APP_URL=http://localhost:3000
API_BASE_URL=http://localhost:8000
COGNITO_USER_POOL_ID=us-east-1_dev123
COGNITO_CLIENT_ID=dev-client-id
COGNITO_DOMAIN=auth-dev.faithchatbot.com
LOG_LEVEL=debug
ENABLE_PRAYER_CONNECT=true

# .env.staging
NODE_ENV=staging
APP_URL=https://staging.faithchatbot.com
API_BASE_URL=https://api-staging.faithchatbot.com
COGNITO_USER_POOL_ID=us-east-1_staging123
COGNITO_CLIENT_ID=staging-client-id
COGNITO_DOMAIN=auth-staging.faithchatbot.com
LOG_LEVEL=info

# .env.production
NODE_ENV=production
APP_URL=https://app.faithchatbot.com
API_BASE_URL=https://api.faithchatbot.com
COGNITO_USER_POOL_ID=us-east-1_prod123
COGNITO_CLIENT_ID=prod-client-id
COGNITO_DOMAIN=auth.faithchatbot.com
LOG_LEVEL=warn
```

### Secrets Management Strategy
```typescript
// lib/secrets.ts
import { SecretsManagerClient, GetSecretValueCommand } from '@aws-sdk/client-secrets-manager';

interface SecretConfig {
  secretId: string;
  region: string;
}

export class SecretsManager {
  private client: SecretsManagerClient;
  private cache: Map<string, any> = new Map();
  
  constructor(region: string = 'us-east-1') {
    this.client = new SecretsManagerClient({ region });
  }
  
  async getSecret<T = any>(secretId: string): Promise<T> {
    if (this.cache.has(secretId)) {
      return this.cache.get(secretId);
    }
    
    const command = new GetSecretValueCommand({ SecretId: secretId });
    const response = await this.client.send(command);
    
    const secret = JSON.parse(response.SecretString || '{}');
    this.cache.set(secretId, secret);
    
    return secret;
  }
}

// Usage in application
const secrets = new SecretsManager();
const dbConfig = await secrets.getSecret('faith-chatbot/database-config');
```

### Environment Validation Scripts
```typescript
// scripts/validate-env.ts
import { ConfigSchema } from '../config/schema';

export function validateEnvironment() {
  try {
    const config = ConfigSchema.parse(process.env);
    console.log('✅ Environment validation passed');
    return config;
  } catch (error) {
    console.error('❌ Environment validation failed:');
    if (error instanceof z.ZodError) {
      error.errors.forEach(err => {
        console.error(`  - ${err.path.join('.')}: ${err.message}`);
      });
    }
    process.exit(1);
  }
}

// Run validation
if (require.main === module) {
  validateEnvironment();
}
```

## 3. Local Development Environment Design

### Docker Compose Configuration
```yaml
# docker-compose.yml
version: '3.8'

services:
  # Frontend Development Server
  frontend:
    build:
      context: .
      dockerfile: Dockerfile.dev
    ports:
      - "3000:3000"
    volumes:
      - .:/app
      - /app/node_modules
    environment:
      - NODE_ENV=development
      - CHOKIDAR_USEPOLLING=true
    depends_on:
      - api
      - localstack

  # Backend API Service
  api:
    build:
      context: ./api
      dockerfile: Dockerfile.dev
    ports:
      - "8000:8000"
    volumes:
      - ./api:/app
    environment:
      - ENVIRONMENT=development
      - AWS_ENDPOINT_URL=http://localstack:4566
      - AWS_ACCESS_KEY_ID=test
      - AWS_SECRET_ACCESS_KEY=test
      - AWS_DEFAULT_REGION=us-east-1
    depends_on:
      - localstack
      - redis

  # LocalStack for AWS Services
  localstack:
    image: localstack/localstack:latest
    ports:
      - "4566:4566"
    environment:
      - SERVICES=dynamodb,sqs,ses,secretsmanager,cognito-idp
      - DEBUG=1
      - DATA_DIR=/tmp/localstack/data
      - DOCKER_HOST=unix:///var/run/docker.sock
    volumes:
      - "./localstack:/etc/localstack/init/ready.d"
      - "/var/run/docker.sock:/var/run/docker.sock"
      - "localstack-data:/tmp/localstack"

  # Redis for Caching
  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis-data:/data

  # Database (PostgreSQL for local development)
  postgres:
    image: postgres:15-alpine
    ports:
      - "5432:5432"
    environment:
      - POSTGRES_DB=faithchatbot_dev
      - POSTGRES_USER=dev
      - POSTGRES_PASSWORD=devpass
    volumes:
      - postgres-data:/var/lib/postgresql/data
      - ./database/init:/docker-entrypoint-initdb.d

volumes:
  localstack-data:
  redis-data:
  postgres-data:
```

### LocalStack Initialization Scripts
```bash
#!/bin/bash
# localstack/01-create-dynamodb-tables.sh

echo "Creating DynamoDB tables..."

# User Profiles Table
awslocal dynamodb create-table \
  --table-name FaithChatbot-UserProfiles \
  --attribute-definitions \
    AttributeName=user_id,AttributeType=S \
    AttributeName=email,AttributeType=S \
  --key-schema \
    AttributeName=user_id,KeyType=HASH \
  --global-secondary-indexes \
    IndexName=EmailIndex,KeySchema=[{AttributeName=email,KeyType=HASH}],Projection={ProjectionType=ALL},ProvisionedThroughput={ReadCapacityUnits=5,WriteCapacityUnits=5} \
  --provisioned-throughput \
    ReadCapacityUnits=5,WriteCapacityUnits=5

# Conversation Sessions Table
awslocal dynamodb create-table \
  --table-name FaithChatbot-ConversationSessions \
  --attribute-definitions \
    AttributeName=session_id,AttributeType=S \
    AttributeName=user_id,AttributeType=S \
  --key-schema \
    AttributeName=session_id,KeyType=HASH \
  --global-secondary-indexes \
    IndexName=UserIndex,KeySchema=[{AttributeName=user_id,KeyType=HASH}],Projection={ProjectionType=ALL},ProvisionedThroughput={ReadCapacityUnits=5,WriteCapacityUnits=5} \
  --provisioned-throughput \
    ReadCapacityUnits=5,WriteCapacityUnits=5

# Prayer Requests Table
awslocal dynamodb create-table \
  --table-name FaithChatbot-PrayerRequests \
  --attribute-definitions \
    AttributeName=request_id,AttributeType=S \
    AttributeName=user_id,AttributeType=S \
    AttributeName=status,AttributeType=S \
  --key-schema \
    AttributeName=request_id,KeyType=HASH \
  --global-secondary-indexes \
    IndexName=UserIndex,KeySchema=[{AttributeName=user_id,KeyType=HASH}],Projection={ProjectionType=ALL},ProvisionedThroughput={ReadCapacityUnits=5,WriteCapacityUnits=5} \
    IndexName=StatusIndex,KeySchema=[{AttributeName=status,KeyType=HASH}],Projection={ProjectionType=ALL},ProvisionedThroughput={ReadCapacityUnits=5,WriteCapacityUnits=5} \
  --provisioned-throughput \
    ReadCapacityUnits=5,WriteCapacityUnits=5

echo "DynamoDB tables created successfully!"
```

```bash
#!/bin/bash
# localstack/02-create-sqs-queues.sh

echo "Creating SQS queues..."

# Prayer Requests Queue
awslocal sqs create-queue \
  --queue-name FaithChatbot-PrayerRequests \
  --attributes VisibilityTimeoutSeconds=300,MessageRetentionPeriod=1209600

# Dead Letter Queue
awslocal sqs create-queue \
  --queue-name FaithChatbot-PrayerRequests-DLQ \
  --attributes MessageRetentionPeriod=1209600

echo "SQS queues created successfully!"
```

### Database Seeding Scripts
```typescript
// scripts/seed-database.ts
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, PutCommand } from '@aws-sdk/lib-dynamodb';

const client = new DynamoDBClient({
  endpoint: 'http://localhost:4566',
  region: 'us-east-1',
  credentials: {
    accessKeyId: 'test',
    secretAccessKey: 'test',
  },
});

const docClient = DynamoDBDocumentClient.from(client);

async function seedDatabase() {
  console.log('🌱 Seeding database with test data...');
  
  // Seed User Profiles
  const testUsers = [
    {
      user_id: 'user_001',
      email: 'john.doe@example.com',
      first_name: 'John',
      created_at: new Date().toISOString(),
      last_active: new Date().toISOString(),
      preferences: {
        notification_email: true,
        prayer_connect_enabled: true,
      },
      consent_history: [],
    },
    {
      user_id: 'user_002',
      email: 'jane.smith@example.com',
      first_name: 'Jane',
      created_at: new Date().toISOString(),
      last_active: new Date().toISOString(),
      preferences: {
        notification_email: false,
        prayer_connect_enabled: true,
      },
      consent_history: [],
    },
  ];
  
  for (const user of testUsers) {
    await docClient.send(new PutCommand({
      TableName: 'FaithChatbot-UserProfiles',
      Item: user,
    }));
  }
  
  // Seed Biblical Content
  const biblicalContent = [
    {
      emotion: 'anxiety',
      themes: ['peace', 'trust', 'gods_presence'],
      verses: [
        {
          reference: 'Philippians 4:6-7',
          text: 'Do not be anxious about anything, but in every situation, by prayer and petition, with thanksgiving, present your requests to God.',
          theme: 'peace_and_trust',
        },
      ],
      reflections: [
        'God invites us to bring our worries to Him in prayer, knowing that His peace surpasses our understanding.',
      ],
      action_steps: [
        'Take 3 deep breaths and speak this worry aloud to God in prayer',
      ],
    },
  ];
  
  // Store in a separate table or S3 bucket for biblical content
  console.log('✅ Database seeded successfully!');
}

if (require.main === module) {
  seedDatabase().catch(console.error);
}
```

### Development Scripts
```json
{
  "scripts": {
    "dev:setup": "docker-compose up -d && npm run dev:wait && npm run dev:seed",
    "dev:wait": "wait-on http://localhost:4566 && sleep 5",
    "dev:seed": "tsx scripts/seed-database.ts",
    "dev:clean": "docker-compose down -v && docker system prune -f",
    "dev:logs": "docker-compose logs -f",
    "dev:validate": "tsx scripts/validate-env.ts",
    "dev": "next dev",
    "build": "npm run dev:validate && next build",
    "start": "next start",
    "test": "jest",
    "test:watch": "jest --watch",
    "test:e2e": "playwright test",
    "lint": "next lint",
    "type-check": "tsc --noEmit"
  }
}
```

This comprehensive Phase 0 design provides all the foundational specifications needed for successful implementation, including detailed frontend architecture, environment management, and local development setup.