# Faith Motivator Chatbot

A Reflex-based faith counseling chatbot application that provides biblical encouragement, emotional support, and prayer community connections.

## 🌟 Features

- **AI-Powered Chat Interface**: Intelligent conversations with biblical guidance
- **Emotion Classification**: Automatic detection of emotional states for personalized responses
- **Prayer Connect**: Community prayer request sharing with consent management
- **Biblical Content Matching**: Contextually relevant scripture and reflections
- **User Authentication**: Secure login with AWS Cognito integration
- **Data Export**: GDPR-compliant user data export functionality
- **Responsive Design**: Mobile-first design with accessibility compliance
- **Real-time Messaging**: Seamless chat experience with typing indicators

## 🏗️ Architecture

### Technology Stack

- **Frontend**: Reflex (Python-based React framework)
- **Backend**: FastAPI with Python 3.9+
- **Database**: DynamoDB for scalable data storage
- **Authentication**: AWS Cognito for secure user management
- **Caching**: Redis for session management and rate limiting
- **Message Queue**: SQS for asynchronous processing
- **Email**: SES for notifications and communications
- **Infrastructure**: Docker Compose for local development

### Project Structure

```
muykol-chatbot-app/
├── faith_motivator_chatbot/          # Main application
│   ├── components/                   # UI components
│   │   ├── auth_components.py       # Authentication UI
│   │   ├── chat_components.py       # Chat interface
│   │   ├── common.py               # Shared components
│   │   └── navigation.py           # Navigation components
│   ├── state/                       # Application state management
│   │   ├── auth_state.py           # Authentication state
│   │   ├── chat_state.py           # Chat functionality state
│   │   └── ui_state.py             # UI state management
│   ├── config/                      # Configuration management
│   │   └── schema.py               # Environment schema
│   └── faith_motivator_chatbot.py  # Main app entry point
├── scripts/                         # Development scripts
│   ├── dev_setup.sh                # Environment setup
│   ├── validate_env.py             # Configuration validation
│   └── seed_database.py            # Database seeding
├── localstack/                      # LocalStack initialization
│   ├── 01-create-dynamodb-tables.sh
│   ├── 02-create-sqs-queues.sh
│   ├── 03-setup-ses.sh
│   └── 04-setup-secrets.sh
├── tests/                           # Test suite
│   ├── test_accessibility.py       # Accessibility tests
│   └── requirements.txt            # Test dependencies
├── design/                          # Design documentation
│   ├── wireframes.md               # UI wireframes
│   └── design-system.md            # Design system specs
├── docker-compose.yml              # Development environment
├── requirements.txt                # Python dependencies
└── rxconfig.py                     # Reflex configuration
```

## 🚀 Quick Start

### Prerequisites

- Python 3.9 or higher
- Docker and Docker Compose
- Node.js 18+ (for Reflex frontend)
- Git

### Development Setup

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd muykol-chatbot-app
   ```

2. **Run the setup script**
   ```bash
   chmod +x scripts/dev_setup.sh
   ./scripts/dev_setup.sh
   ```

   This script will:
   - Check Docker installation
   - Create environment configuration
   - Start all services (LocalStack, Redis, PostgreSQL)
   - Initialize AWS services
   - Seed the database with test data
   - Validate the environment

3. **Access the application**
   - Frontend: http://localhost:3000
   - Backend API: http://localhost:8000
   - LocalStack: http://localhost:4566

### Manual Setup

If you prefer manual setup:

1. **Create environment file**
   ```bash
   cp .env.example .env
   # Edit .env with your configuration
   ```

2. **Start services**
   ```bash
   docker-compose up -d
   ```

3. **Install Python dependencies**
   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   pip install -r requirements.txt
   ```

4. **Seed database**
   ```bash
   python scripts/seed_database.py
   ```

5. **Start the application**
   ```bash
   reflex run
   ```

## 🔧 Development

### Available Scripts

- `./scripts/dev_setup.sh` - Complete environment setup
- `python scripts/validate_env.py` - Validate configuration
- `python scripts/seed_database.py` - Seed database with test data
- `docker-compose logs -f` - View service logs
- `docker-compose down -v` - Stop and clean environment

### Testing

Run the test suite:

```bash
# Install test dependencies
pip install -r tests/requirements.txt

# Run all tests
pytest

# Run accessibility tests
pytest tests/test_accessibility.py -v

# Run with coverage
pytest --cov=faith_motivator_chatbot
```

### Code Quality

The project uses several tools for code quality:

```bash
# Format code
black faith_motivator_chatbot/

# Lint code
flake8 faith_motivator_chatbot/

# Type checking (if using mypy)
mypy faith_motivator_chatbot/
```

## 🌐 Environment Configuration

### Required Environment Variables

```bash
# Application
APP_ENVIRONMENT=development
APP_URL=http://localhost:3000
API_BASE_URL=http://localhost:8000
APP_SECRET_KEY=your-secret-key-32-chars-minimum

# AWS Configuration
AWS_REGION=us-east-1
AWS_COGNITO_USER_POOL_ID=your-user-pool-id
AWS_COGNITO_CLIENT_ID=your-client-id
AWS_COGNITO_DOMAIN=your-cognito-domain

# LocalStack (for development)
AWS_ENDPOINT_URL=http://localhost:4566
AWS_ACCESS_KEY_ID=test
AWS_SECRET_ACCESS_KEY=test

# Redis
REDIS_URL=redis://localhost:6379

# Feature Flags
FEATURE_ENABLE_PRAYER_CONNECT=true
FEATURE_ENABLE_ANALYTICS=false
```

See `.env.example` for a complete list of configuration options.

## 🎨 Design System

The application follows a comprehensive design system with:

- **Accessibility**: WCAG 2.1 AA compliance
- **Responsive Design**: Mobile-first approach
- **Color Palette**: Faith-inspired colors (blue, gold, purple)
- **Typography**: Inter for body text, Playfair Display for headings
- **Components**: Consistent, reusable UI components

See `design/design-system.md` for detailed specifications.

## 🔒 Security & Privacy

- **Authentication**: AWS Cognito with JWT tokens
- **Data Protection**: Encryption at rest and in transit
- **Privacy Compliance**: GDPR-compliant data handling
- **Consent Management**: Explicit consent tracking
- **Rate Limiting**: Redis-based request throttling

## 📱 Accessibility

The application is built with accessibility as a priority:

- **WCAG 2.1 AA Compliance**: All components meet accessibility standards
- **Keyboard Navigation**: Full keyboard accessibility
- **Screen Reader Support**: Proper ARIA labels and semantic HTML
- **Color Contrast**: Minimum 4.5:1 contrast ratio
- **Focus Management**: Logical tab order and focus indicators

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Guidelines

- Follow the existing code style and patterns
- Write tests for new functionality
- Ensure accessibility compliance
- Update documentation as needed
- Test across different devices and browsers

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🙏 Acknowledgments

- Built with [Reflex](https://reflex.dev/) - The web framework for Python
- Inspired by the mission to provide accessible faith-based support
- Thanks to all contributors and the open-source community

## 📞 Support

For support and questions:

- Create an issue in the repository
- Contact the development team
- Check the documentation in the `design/` directory

---

**Faith Motivator Chatbot** - Bringing biblical encouragement and community support through technology. 🙏✨