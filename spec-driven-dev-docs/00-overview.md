# Motivator Chatbot MVP Spec Pack

This spec pack is designed for spec-driven development. It defines MVP scope, architecture assumptions, data models, safety/privacy controls, and operational requirements.

## Key MVP behaviors
- Cognito authentication (Hosted UI + Authorization Code + PKCE)
- Chat with 2-step Bedrock pipeline: emotion classification → encouragement response
- Explicit consent before sharing user email to Telegram prayer group
- Prayer Connect ticketing with async delivery via SQS → Lambda worker → Telegram + SES

# **1) The product boundaries (what you will and will not do)**

Core user journey

1. User chats (web or mobile UI).
2. System infers the user’s emotional state from conversation.
3. System responds with:
    - empathy,
    - biblically grounded encouragement,
    - a short actionable next step (e.g., breathing, journaling, prayer prompt),
    - and an offer to connect with a community member for prayer.
4. 
5. If user opts in, the platform sends a “Prayer Connect Request” to a Telegram group including the user’s email (per your requirement). A community member then emails a Google Meet link to the user.

Non-negotiable guardrails

- Do not present as medical, mental health, or pastoral counseling.
- Detect and safely handle self-harm / abuse / crisis signals with a clear escalation path.
- Obtain explicit consent before sharing any personal data (email) to a Telegram group.

Using Amazon Bedrock Guardrails can help enforce safety and sensitive-information controls on both user input and model output.

# **2)  The first MVP scope (keep it small, but end-to-end)**

A good MVP is:

MVP v1

- Chat UI (simple web app) + User accounts
- Bedrock LLM response (encouragement)
- Emotion classification (single-label or top-2 emotions)
- Bible verse + reflection + action step
- “Connect for prayer?” flow
- Telegram group notification + email sent

# **3) The architecture pattern**

**A pragmatic AWS reference architecture**

Frontend

- Web app (React/Next.js) OR a lightweight app UI.

Backend (API)

- ECS fargate + ALB  as the chat orchestration layer.

LLM

- Amazon Bedrock for inference.
- Bedrock Guardrails for content safety + sensitive info filtering.

Scripture/insights retrieval

- Start with a curated “emotion → verses → reflections” dataset in DynamoDB or S3.
- Move to RAG with Amazon Bedrock Knowledge Bases when your corpus grows (devotionals, topical notes, pastoral guidance).

Prayer connect workflow

- Store a “prayer request ticket” in DynamoDB.
- Publish event to SQS/EventBridge.
- A Lambda posts message to Telegram via Bot API.
- A separate Lambda sends email to user (SES) confirming request received.

Observability

- CloudWatch Logs + structured app logs
- Alarms for failures in Telegram/email delivery

# **4) Design the “emotion detection” approach (reliable, testable)**

**Two-step pipeline (recommended for reliability)**

1. Classifier step: Ask the model to output a strict JSON schema:
    - primary_emotion, secondary_emotion, confidence, risk_flags
2. Response step: Provide the emotion result + retrieved scripture content and generate the final reply.

# **5) Build a curated “faith insights” layer (avoid shallow or random verses)**

To avoid “verse roulette,” create a curated mapping:

- emotion → themes → verses → reflection prompts → suggested prayer
Examples:
- Anxiety → peace, trust, God’s presence
- Grief → comfort, lament, hope
- Shame → grace, identity, restoration

When you move to RAG, Bedrock Knowledge Bases supports retrieval-augmented responses with citations.

# **6) Implement safety, privacy, and consent as first-class features**

**Safety guardrails**

- Use Bedrock Guardrails to:
    - filter harmful content,
    - block disallowed topics,
    - redact sensitive info,
    - reduce hallucinations with grounding checks (where applicable).
- 

**Crisis escalation**

Create a separate “high-risk” branch:

- If user indicates self-harm intent or imminent danger:
    - provide crisis resources immediately,
    - encourage contacting local emergency services or trusted person,
    - offer to connect to a live helper (if you have one).

**Consent model (important for Telegram + email)**

Before sending a request:

- Show a short consent message:
    - “We will share your email address with our prayer team on Telegram so a community member can reach out with a Google Meet link. Do you agree?”
- Require explicit Yes action.
- Log consent timestamp + purpose.

Data minimization suggestion (even if you keep your requirement):

- Send email + request ID, but keep conversation content out of Telegram.
- Optionally mask the email in Telegram and let the volunteer fetch it through an authenticated portal (safer), but that is a v2 enhancement.

# **7) Telegram + Email workflow design (operationally clean)**

**Telegram message format (actionable for volunteers)**

Include:

- Request ID
- First name or alias (optional)
- Email (required by your flow)
- Suggested prompt: “Reply to this email with a Meet link template”
- Guidelines: privacy + response time expectations

Telegram Bot API is HTTP-based and commonly used for bot messaging.

**Email templates**

- To user: “We received your request. A community member will email a Meet link soon.”
- To volunteer (optional): include the request details if you manage volunteers outside Telegram.

# **8) Decide whether you need Bedrock “Agents”**

You can build this as a standard orchestrated app (Lambda calls Bedrock) without Agents.

Use Bedrock Agents if you want:

- structured tool-calling,
- multi-step reasoning with managed orchestration,
- built-in integration patterns (e.g., invoke Lambda tools, call knowledge bases).

For MVP: direct orchestration is usually simpler.

# **9) Evaluation and iteration plan (so quality improves over time)**

Create a small internal dataset of anonymized prompts (or synthetic prompts):

- Each includes: conversation snippet → expected emotion → acceptable response traits
Measure:
- Emotion classification accuracy (human-labeled)
- User satisfaction (thumbs up/down)
- Safety compliance (no prohibited outputs)
- Scripture relevance (human rating)

Also add “red team” tests:

- manipulative prompts
- theology traps (e.g., “God hates me, confirm it”)
- crisis content

**implementation sequence (so you do not get stuck)**

1. S3 + CloudFront hosting for Reflex static “Hello world”
2. ECS Fargate service behind ALB with /healthz
3. Cognito Hosted UI integrated end-to-end (login, callback, cookie session)
4. Chat endpoint calls Bedrock (simple echo → then emotion pipeline)
5. DynamoDB persistence (sessions + consent)
6. SQS + worker for Telegram + SES


**Phase 1: Foundations**

- Define your emotion taxonomy (8–12 emotions)
- Draft response rubric (tone, scripture usage, length limits)
- Create curated verse/insight dataset (minimum 5–10 entries per emotion)
- Implement Bedrock calls + Guardrails configuration

**Phase 2: End-to-end MVP**

- Web chat UI → API Gateway → Lambda
- Two-step LLM pipeline: classify → respond
- Store sessions (DynamoDB)
- Implement consent + prayer request ticket
- Telegram bot posting + SES email confirmation

**Phase 3: Hardening**

- Add RAG via Bedrock Knowledge Bases when your content grows
- Add rate limiting, abuse prevention
- Add monitoring/alerts and a volunteer SLA process
- Add user accounts (Cognito) if needed


**Target Architecture (Topology 1 + ECS Fargate)**

**Components**

Frontend

- Reflex static export hosted on S3 + CloudFront
- Custom domain (e.g., app.yourdomain.com) via ACM + Route 53

Backend

- ECS Fargate service running your API (FastAPI / Reflex backend)
- Application Load Balancer (ALB) for HTTPS termination and routing
- Backend domain (e.g., api.yourdomain.com) or path-based routing under one domain

Auth

- Cognito User Pool + Hosted UI (Authorization Code + PKCE)
- Backend validates JWTs via Cognito JWKS

Data + async

- DynamoDB for user profile metadata, consent logs, prayer request tickets, conversation metadata (or S3 for transcripts if needed)
- EventBridge or SQS for decoupling prayer connect notifications
- Lambda (optional) for Telegram posting and/or email sending, or do both from the backend service

Messaging

- Telegram Bot API for group messages
- SES for user notification emails

```
                   ┌───────────────────────────────────────────────┐
                   │                   Route 53                     │
                   │            app.yourdomain.com (A/AAAA)         │
                   └───────────────────────────┬───────────────────┘
                                               │
                                 ┌─────────────▼─────────────┐
                                 │        CloudFront CDN      │
                                 │  TLS (ACM cert) + (WAF)     │
                                 │  Path routing: /api/* → ALB │
                                 └─────────────┬─────────────┘
                       Default (*)             │                 /api/*
                 ┌─────────────────────────────┘──────────────────────┐
                 │                                                    │
 ┌───────────────▼────────────────┐                   ┌───────────────▼────────────────┐
 │          S3 Bucket (Static)     │                   │    Application Load Balancer     │
 │  Reflex static export (HTML/JS) │                   │   Public Subnets (2+ AZ)         │
 │  - Block public access: ON      │                   │   - HTTPS only (ACM)             │
 │  - Bucket policy: only CloudFront│                  │   - SG: allow 443 from CloudFront│
 │  - OAC/OAI enforced             │                   │   - Access logs → S3             │
 └───────────────┬────────────────┘                   └───────────────┬────────────────┘
                 │                                                    │ target group
                 │                                                    │
     ┌───────────▼───────────┐                           ┌────────────▼─────────────┐
     │  CloudFront Logs (opt) │                           │        ECS Service        │
     │  WAF logs → CloudWatch │                           │   Fargate Tasks (2+ AZ)   │
     └────────────────────────┘                           │   Private Subnets          │
                                                          │   - SG: allow 443 from ALB │
                                                          │   - No public IPs          │
                                                          │   - Task Role IAM (least)  │
                                                          │   - Exec disabled (or tightly scoped)│
                                                          │   - App logs → CloudWatch Logs│
                                                          └────────────┬─────────────┘
                                                                       │
                                                                       │ (no NAT / no Internet egress)
                                                                       │

```

┌─────────────────────────────────────────────────────────────────────────▼─────────────────────────────────┐
│                                           VPC ENDPOINTS (PRIVATE)                                           │
│  Interface Endpoints (PrivateLink)                                                                            │
│   - Bedrock runtime/API                                                                                       │
│   - Cognito (as needed by backend)                                                                            │
│   - SES (if backend sends email directly; otherwise omit)                                                     │
│   - ECR (api + dkr), CloudWatch Logs, Secrets Manager, SSM, STS, KMS (as needed)                             │
│    Security controls:                                                                                         │
│     - Endpoint SG: allow from ECS task SG only                                                                │
│     - Private DNS: enabled (where applicable)                                                                 │
│     - Endpoint policy: restrict to required actions/resources                                                 │
│  Gateway Endpoints: S3, DynamoDB                                                                              │
│    Security controls:                                                                                         │
│     - Endpoint policy: restrict bucket/table access                                                           │
└─────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
│                                           │
│                                           │
┌─────────────▼─────────────┐                  ┌──────────▼───────────┐
│         DynamoDB           │                  │     SQS / EventBridge │
│ - Users / Profiles         │                  │ PrayerConnectRequested│
│ - Sessions / Consent logs  │                  └──────────┬───────────┘
│ - PrayerRequest tickets    │                             │
└─────────────┬─────────────┘                             │ async
│                                            │
│                                  ┌─────────▼──────────┐
│                                  │ Worker (Lambda)      │
│                                  │ Not in VPC (public)  │
│                                  │ - Posts to Telegram  │
│                                  │ - Sends email via SES│
│                                  └─────────┬──────────┘
│                                            │
│                         ┌──────────────────▼──────────────────┐
│                         │ Telegram Bot API (Public Internet)  │
│                         └─────────────────────────────────────┘
│
│                         ┌──────────────────▼──────────────────┐
│                         │ Amazon SES (Email to user)           │
│                         └─────────────────────────────────────┘

# **Security controls by layer (what to enforce)**

**Edge (CloudFront + optional WAF)**

- AWS WAF: rate limits (per IP), bot control (if needed), basic OWASP rules.
- TLS: ACM cert on CloudFront.
- Origin protection:
    - S3: Block Public Access ON, bucket policy allows only CloudFront (via Origin Access Control).
    - ALB: restrict ingress to CloudFront only (practically: allow from the AWS-managed CloudFront origin-facing IP list via AWS prefix lists / managed approach, or put ALB behind CloudFront with custom headers + WAF; exact method depends on your preference for strictness vs simplicity).
- 

**ALB**

- HTTPS only; redirect 80 → 443 (or do not open 80 at all).
- Security group: inbound 443 only; outbound to ECS service SG.
- Access logs to S3 for auditability.

**ECS Fargate tasks (private subnets, no NAT)**

- No public IPs and no route to IGW/NAT for egress.
- Security group: inbound only from ALB SG; egress only to VPC endpoints (tighten with prefix lists / SG references where possible).
- Secrets: store Telegram bot token (if ever needed by backend), encryption keys, etc. in Secrets Manager; retrieve via task role.
- IAM task role (least privilege):
    - Bedrock invoke permissions for only required models
    - DynamoDB table access scoped to required tables
    - SQS/EventBridge publish only to the specific queue/bus
    - CloudWatch Logs write only to the specific log groups
- 
- KMS: encrypt secrets and (optionally) DynamoDB/S3 objects with CMKs.
- ECS Exec: keep disabled by default; if enabled, restrict to break-glass IAM and audit.

**VPC endpoints (the “no NAT” backbone)**

- Interface endpoint SGs: allow inbound only from ECS task SG.
- Endpoint policies:
    - S3 gateway endpoint policy restricts to the one bucket used for logs/static assets (and any other required buckets).
    - DynamoDB gateway endpoint policy restricts to specific tables.
    - Interface endpoint policies restrict allowed API actions where supported.
- 

**Async prayer connect worker**

- Keep Telegram calls out of the VPC (no NAT required).
- Lambda permissions: restricted to:
    - read prayer ticket from DynamoDB (if required)
    - consume from SQS
    - send via SES
    - no broad permissions
- 

# **Observability and audit (recommended baseline)**

- CloudTrail for account/API auditing.
- CloudWatch Logs for ECS + WAF logs (if enabled) + Lambda logs.
- ALB access logs and optionally CloudFront logs (useful for troubleshooting and incident analysis).
- Alarms:
    - 5xx rate at ALB
    - ECS task restarts / unhealthy targets
    - SQS DLQ > 0
    - SES bounces/complaints (if you automate notifications)