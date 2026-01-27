# Phase 0: Pre-Implementation Setup - Design Document

## Architecture Overview

Phase 0 establishes the foundational specifications and development environment required for successful implementation of the faith-based motivator chatbot. This includes frontend architecture, environment management, and local development setup.

## 1. Frontend Architecture Design

### Technology Stack
```typescript
// Core Technologies
- Framework: Next.js 14 (App Router)
- Language: TypeScript
- Styling: Tailwind CSS + Headless UI
- State Management: Zustand
- Authentication: AWS Cognito + NextAuth.js
- API Client: TanStack Query (React Query)
- Testing: Jest + React Testing Library + Playwright
- Build Tool: Turbopack (Next.js built-in)
```

### Component Architecture
```
src/
├── app/                          # Next.js App Router
│   ├── (auth)/                   # Auth route group
│   │   ├── login/
│   │   └── callback/
│   ├── (dashboard)/              # Protected route group
│   │   ├── chat/
│   │   ├── history/
│   │   └── settings/
│   ├── layout.tsx                # Root layout
│   ├── page.tsx                  # Home page
│   └── globals.css               # Global styles
├── components/                   # Reusable components
│   ├── ui/                       # Base UI components
│   │   ├── Button.tsx
│   │   ├── Input.tsx
│   │   ├── Modal.tsx
│   │   └── index.ts
│   ├── chat/                     # Chat-specific components
│   │   ├── ChatInterface.tsx
│   │   ├── MessageBubble.tsx
│   │   ├── TypingIndicator.tsx
│   │   └── PrayerConnectModal.tsx
│   ├── layout/                   # Layout components
│   │   ├── Header.tsx
│   │   ├── Navigation.tsx
│   │   └── Footer.tsx
│   └── forms/                    # Form components
│       ├── ConsentForm.tsx
│       └── ContactForm.tsx
├── lib/                          # Utilities and configurations
│   ├── auth.ts                   # Authentication configuration
│   ├── api.ts                    # API client setup
│   ├── utils.ts                  # Utility functions
│   └── validations.ts            # Form validation schemas
├── hooks/                        # Custom React hooks
│   ├── useAuth.ts
│   ├── useChat.ts
│   └── usePrayerConnect.ts
├── store/                        # State management
│   ├── authStore.ts
│   ├── chatStore.ts
│   └── index.ts
├── types/                        # TypeScript type definitions
│   ├── auth.ts
│   ├── chat.ts
│   └── api.ts
└── styles/                       # Additional styles
    └── components.css
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
```typescript
interface ButtonProps {
  variant: 'primary' | 'secondary' | 'outline' | 'ghost';
  size: 'sm' | 'md' | 'lg';
  disabled?: boolean;
  loading?: boolean;
  icon?: React.ReactNode;
  children: React.ReactNode;
  onClick?: () => void;
}

// Usage Examples:
<Button variant="primary" size="md">Send Message</Button>
<Button variant="outline" size="sm" icon={<PrayIcon />}>
  Connect for Prayer
</Button>
```

##### Chat Interface Component
```typescript
interface ChatInterfaceProps {
  messages: Message[];
  onSendMessage: (message: string) => void;
  isTyping?: boolean;
  disabled?: boolean;
}

interface Message {
  id: string;
  content: string;
  role: 'user' | 'assistant';
  timestamp: Date;
  metadata?: {
    emotion?: EmotionClassification;
    bibleVerse?: BiblicalContent;
    prayerConnectOffered?: boolean;
  };
}
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