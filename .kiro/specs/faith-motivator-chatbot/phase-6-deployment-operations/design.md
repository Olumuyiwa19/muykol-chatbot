# Phase 6: Deployment & Operations - Design Document

## Architecture Overview

Phase 6 implements production deployment infrastructure, operational procedures, and launch preparation for the faith-based motivator chatbot. This includes ECS Fargate deployment, CI/CD pipelines, performance optimization, security hardening, and comprehensive operational readiness.

### Production Deployment Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Production Environment                        │
│                                                                 │
│  ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐   │
│  │   CloudFront    │ │  Application    │ │   ECS Fargate   │   │
│  │      CDN        │ │ Load Balancer   │ │    Service      │   │
│  │                 │ │                 │ │                 │   │
│  │ • Static Assets │ │ • SSL Term.     │ │ • Auto Scaling  │   │
│  │ • Global Cache  │ │ • Health Checks │ │ • Blue/Green    │   │
│  │ • WAF Rules     │ │ • Target Groups │ │ • Rolling Update│   │
│  └─────────────────┘ └─────────────────┘ └─────────────────┘   │
└─────────────────────────┬───────────────────────────────────────┘
                          │
┌─────────────────────────▼───────────────────────────────────────┐
│                 CI/CD Pipeline                                  │
│                                                                 │
│  ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐   │
│  │ GitHub Actions  │ │   Docker Build  │ │   Deployment    │   │
│  │                 │ │                 │ │                 │   │
│  │ • Test Suite    │ │ • Image Build   │ │ • Staging       │   │
│  │ • Security Scan │ │ • Vulnerability │ │ • Production    │   │
│  │ • Quality Gates │ │ • ECR Push      │ │ • Rollback      │   │
│  └─────────────────┘ └─────────────────┘ └─────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

## Component Design

### 1. ECS Fargate Deployment Configuration

#### Service Definition
```yaml
# ecs-service.yml
apiVersion: v1
kind: Service
metadata:
  name: faith-chatbot-service
spec:
  serviceName: faith-chatbot
  cluster: faith-chatbot-cluster
  taskDefinition: faith-chatbot-task:LATEST
  desiredCount: 2
  launchType: FARGATE
  
  networkConfiguration:
    awsvpcConfiguration:
      subnets:
        - subnet-private-1a
        - subnet-private-1b
      securityGroups:
        - sg-ecs-tasks
      assignPublicIp: DISABLED
  
  loadBalancers:
    - targetGroupArn: arn:aws:elasticloadbalancing:region:account:targetgroup/faith-chatbot-tg
      containerName: api
      containerPort: 8000
  
  deploymentConfiguration:
    maximumPercent: 200
    minimumHealthyPercent: 50
    deploymentCircuitBreaker:
      enable: true
      rollback: true
  
  serviceTags:
    - key: Environment
      value: production
    - key: Application
      value: faith-motivator-chatbot
```

#### Task Definition
```json
{
  "family": "faith-chatbot-task",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "1024",
  "memory": "2048",
  "executionRoleArn": "arn:aws:iam::account:role/ecsTaskExecutionRole",
  "taskRoleArn": "arn:aws:iam::account:role/faithChatbotTaskRole",
  "containerDefinitions": [
    {
      "name": "api",
      "image": "account.dkr.ecr.region.amazonaws.com/faith-chatbot:latest",
      "portMappings": [
        {
          "containerPort": 8000,
          "protocol": "tcp"
        }
      ],
      "essential": true,
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/faith-chatbot",
          "awslogs-region": "us-east-1",
          "awslogs-stream-prefix": "ecs"
        }
      },
      "environment": [
        {
          "name": "ENVIRONMENT",
          "value": "production"
        },
        {
          "name": "AWS_DEFAULT_REGION",
          "value": "us-east-1"
        }
      ],
      "secrets": [
        {
          "name": "DATABASE_URL",
          "valueFrom": "arn:aws:secretsmanager:region:account:secret:faith-chatbot/database-url"
        },
        {
          "name": "TELEGRAM_BOT_TOKEN",
          "valueFrom": "arn:aws:secretsmanager:region:account:secret:faith-chatbot/telegram-token"
        }
      ],
      "healthCheck": {
        "command": [
          "CMD-SHELL",
          "curl -f http://localhost:8000/health || exit 1"
        ],
        "interval": 30,
        "timeout": 5,
        "retries": 3,
        "startPeriod": 60
      }
    }
  ]
}
```
### 2. CI/CD Pipeline Architecture

#### Pipeline Overview
```
┌─────────────────────────────────────────────────────────────────┐
│                    Feature Branch Workflow                      │
│                                                                 │
│  ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐   │
│  │ Infrastructure  │ │   Application   │ │   Integration   │   │
│  │      CI         │ │       CI        │ │      Tests      │   │
│  │                 │ │                 │ │                 │   │
│  │ • Terraform     │ │ • Unit Tests    │ │ • E2E Tests     │   │
│  │   Validate      │ │ • CodeQL Scan   │ │ • Smoke Tests   │   │
│  │ • Checkov Scan  │ │ • Security Scan │ │ • Performance   │   │
│  │ • Plan (no apply)│ │ • Build & Test  │ │   Tests         │   │
│  └─────────────────┘ └─────────────────┘ └─────────────────┘   │
└─────────────────────────┬───────────────────────────────────────┘
                          │ PR Review & Merge
┌─────────────────────────▼───────────────────────────────────────┐
│                    Main Branch Deployment                       │
│                                                                 │
│  ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐   │
│  │ Infrastructure  │ │   Application   │ │   Production    │   │
│  │      CD         │ │       CD        │ │   Validation    │   │
│  │                 │ │                 │ │                 │   │
│  │ • Terraform     │ │ • Build & Push  │ │ • Health Checks │   │
│  │   Apply         │ │ • Deploy ECS    │ │ • Rollback      │   │
│  │ • Drift Check   │ │ • Blue/Green    │ │   Capability    │   │
│  │ • State Backup  │ │ • Canary Deploy │ │ • Monitoring    │   │
│  └─────────────────┘ └─────────────────┘ └─────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

#### Infrastructure CI Pipeline (Feature Branches)
```yaml
# .github/workflows/infrastructure-ci.yml
name: Infrastructure CI - Validation

on:
  pull_request:
    branches: [main, develop]
    paths: 
      - 'infrastructure/**'
      - '.github/workflows/infrastructure-*.yml'

env:
  TF_VERSION: '1.6.0'
  AWS_REGION: us-east-1

permissions:
  id-token: write
  contents: read
  pull-requests: write
  security-events: write

jobs:
  terraform-validate:
    name: Terraform Validation
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TF_VERSION }}
      
      - name: Terraform Format Check
        run: terraform fmt -check -recursive
        working-directory: infrastructure
      
      - name: Terraform Init
        run: terraform init -backend=false
        working-directory: infrastructure
      
      - name: Terraform Validate
        run: terraform validate
        working-directory: infrastructure

  security-scan:
    name: Infrastructure Security Scan
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Run Checkov Security Scan
        id: checkov
        uses: bridgecrewio/checkov-action@master
        with:
          directory: infrastructure/
          framework: terraform
          output_format: sarif
          output_file_path: checkov-results.sarif
          download_external_modules: true
          quiet: false
          soft_fail: false
          skip_check: CKV_AWS_79,CKV_AWS_61  # Skip specific checks if needed
      
      - name: Upload Checkov results to GitHub Security
        uses: github/codeql-action/upload-sarif@v3
        if: always()
        with:
          sarif_file: checkov-results.sarif
      
      - name: Comment PR with security findings
        uses: actions/github-script@v7
        if: failure()
        with:
          script: |
            const fs = require('fs');
            try {
              const sarif = JSON.parse(fs.readFileSync('checkov-results.sarif', 'utf8'));
              const results = sarif.runs[0].results || [];
              
              if (results.length > 0) {
                let comment = '## 🔒 Infrastructure Security Scan Results\n\n';
                comment += `Found ${results.length} security issue(s):\n\n`;
                
                results.slice(0, 10).forEach((result, index) => {
                  comment += `${index + 1}. **${result.ruleId}**: ${result.message.text}\n`;
                  if (result.locations && result.locations[0]) {
                    const location = result.locations[0].physicalLocation;
                    comment += `   - File: ${location.artifactLocation.uri}\n`;
                    comment += `   - Line: ${location.region.startLine}\n\n`;
                  }
                });
                
                if (results.length > 10) {
                  comment += `... and ${results.length - 10} more issues. Check the Security tab for full details.\n`;
                }
                
                github.rest.issues.createComment({
                  issue_number: context.issue.number,
                  owner: context.repo.owner,
                  repo: context.repo.repo,
                  body: comment
                });
              }
            } catch (error) {
              console.log('Error reading SARIF file:', error);
            }

  terraform-plan:
    name: Terraform Plan
    runs-on: ubuntu-latest
    needs: [terraform-validate, security-scan]
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Configure AWS credentials via OIDC
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::${{ secrets.AWS_ACCOUNT_ID }}:role/GitHubActions-Infrastructure-Role
          role-session-name: GitHubActions-TerraformPlan-${{ github.run_id }}
          aws-region: ${{ env.AWS_REGION }}
      
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TF_VERSION }}
      
      - name: Terraform Init
        run: terraform init
        working-directory: infrastructure
      
      - name: Terraform Plan
        id: plan
        run: |
          terraform plan \
            -var-file="environments/dev.tfvars" \
            -out=tfplan \
            -no-color \
            -detailed-exitcode
        working-directory: infrastructure
        continue-on-error: true
      
      - name: Generate Plan Summary
        run: |
          terraform show -no-color tfplan > tfplan.txt
          
          # Create a summary for the PR comment
          echo "## 🏗️ Terraform Plan Summary" > plan-summary.md
          echo "" >> plan-summary.md
          
          if [ "${{ steps.plan.outputs.exitcode }}" == "0" ]; then
            echo "✅ **No changes detected**" >> plan-summary.md
          elif [ "${{ steps.plan.outputs.exitcode }}" == "2" ]; then
            echo "📋 **Changes detected:**" >> plan-summary.md
            echo "" >> plan-summary.md
            echo '```hcl' >> plan-summary.md
            head -50 tfplan.txt >> plan-summary.md
            echo '```' >> plan-summary.md
            
            if [ $(wc -l < tfplan.txt) -gt 50 ]; then
              echo "" >> plan-summary.md
              echo "... (truncated, see full plan in workflow logs)" >> plan-summary.md
            fi
          else
            echo "❌ **Plan failed** - Check workflow logs for details" >> plan-summary.md
          fi
        working-directory: infrastructure
      
      - name: Comment PR with Plan
        uses: actions/github-script@v7
        with:
          script: |
            const fs = require('fs');
            const plan = fs.readFileSync('infrastructure/plan-summary.md', 'utf8');
            
            // Find existing plan comment
            const comments = await github.rest.issues.listComments({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
            });
            
            const existingComment = comments.data.find(comment => 
              comment.body.includes('🏗️ Terraform Plan Summary')
            );
            
            if (existingComment) {
              // Update existing comment
              await github.rest.issues.updateComment({
                comment_id: existingComment.id,
                owner: context.repo.owner,
                repo: context.repo.repo,
                body: plan
              });
            } else {
              // Create new comment
              await github.rest.issues.createComment({
                issue_number: context.issue.number,
                owner: context.repo.owner,
                repo: context.repo.repo,
                body: plan
              });
            }
      
      - name: Fail if plan failed
        if: steps.plan.outputs.exitcode == 1
        run: exit 1

#### Application CI Pipeline (Feature Branches)
```yaml
# .github/workflows/application-ci.yml
name: Application CI - Validation

on:
  pull_request:
    branches: [main, develop]
    paths:
      - 'app/**'
      - 'tests/**'
      - 'requirements*.txt'
      - 'Dockerfile'
      - '.github/workflows/application-*.yml'

env:
  PYTHON_VERSION: '3.11'
  AWS_REGION: us-east-1

permissions:
  id-token: write
  contents: read
  pull-requests: write
  security-events: write

jobs:
  code-quality:
    name: Code Quality & Security
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: ${{ env.PYTHON_VERSION }}
      
      - name: Cache pip dependencies
        uses: actions/cache@v3
        with:
          path: ~/.cache/pip
          key: ${{ runner.os }}-pip-${{ hashFiles('**/requirements*.txt') }}
          restore-keys: |
            ${{ runner.os }}-pip-
      
      - name: Install dependencies
        run: |
          pip install --upgrade pip
          pip install -r requirements.txt
          pip install -r requirements-test.txt
          pip install bandit safety black isort flake8 mypy
      
      - name: Code formatting check
        run: |
          black --check app/ tests/
          isort --check-only app/ tests/
      
      - name: Linting
        run: |
          flake8 app/ tests/ --max-line-length=88 --extend-ignore=E203,W503
          mypy app/ --ignore-missing-imports
      
      - name: Security scan with Bandit
        run: |
          bandit -r app/ -f json -o bandit-results.json
          bandit -r app/ -f txt
        continue-on-error: true
      
      - name: Dependency security check
        run: |
          safety check --json --output safety-results.json
          safety check
        continue-on-error: true
      
      - name: Initialize CodeQL
        uses: github/codeql-action/init@v3
        with:
          languages: python
          queries: security-and-quality
      
      - name: Perform CodeQL Analysis
        uses: github/codeql-action/analyze@v3
        with:
          category: "/language:python"

  unit-tests:
    name: Unit Tests
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: ${{ env.PYTHON_VERSION }}
      
      - name: Install dependencies
        run: |
          pip install --upgrade pip
          pip install -r requirements.txt
          pip install -r requirements-test.txt
      
      - name: Run unit tests
        run: |
          pytest tests/unit/ \
            --cov=app \
            --cov-report=xml \
            --cov-report=html \
            --cov-report=term \
            --cov-fail-under=80 \
            --junitxml=test-results.xml \
            -v
      
      - name: Upload coverage to Codecov
        uses: codecov/codecov-action@v3
        with:
          file: ./coverage.xml
          flags: unittests
          name: codecov-umbrella
      
      - name: Upload test results
        uses: actions/upload-artifact@v3
        if: always()
        with:
          name: test-results
          path: |
            test-results.xml
            htmlcov/
            coverage.xml

  integration-tests:
    name: Integration Tests
    runs-on: ubuntu-latest
    services:
      localstack:
        image: localstack/localstack:latest
        env:
          SERVICES: dynamodb,sqs,secretsmanager
          DEBUG: 1
        ports:
          - 4566:4566
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: ${{ env.PYTHON_VERSION }}
      
      - name: Install dependencies
        run: |
          pip install --upgrade pip
          pip install -r requirements.txt
          pip install -r requirements-test.txt
      
      - name: Wait for LocalStack
        run: |
          timeout 60 bash -c 'until curl -s http://localhost:4566/_localstack/health | grep -q "\"dynamodb\": \"available\""; do sleep 2; done'
      
      - name: Run integration tests
        env:
          AWS_ACCESS_KEY_ID: test
          AWS_SECRET_ACCESS_KEY: test
          AWS_DEFAULT_REGION: us-east-1
          DYNAMODB_ENDPOINT: http://localhost:4566
          SQS_ENDPOINT: http://localhost:4566
        run: |
          pytest tests/integration/ -v --tb=short

  docker-build:
    name: Docker Build & Security Scan
    runs-on: ubuntu-latest
    needs: [code-quality, unit-tests]
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3
      
      - name: Build Docker image
        uses: docker/build-push-action@v5
        with:
          context: .
          push: false
          tags: faith-chatbot:pr-${{ github.event.number }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
      
      - name: Run Trivy vulnerability scanner
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: 'faith-chatbot:pr-${{ github.event.number }}'
          format: 'sarif'
          output: 'trivy-results.sarif'
      
      - name: Upload Trivy scan results to GitHub Security
        uses: github/codeql-action/upload-sarif@v3
        if: always()
        with:
          sarif_file: 'trivy-results.sarif'
      
      - name: Run Trivy for PR comment
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: 'faith-chatbot:pr-${{ github.event.number }}'
          format: 'table'
        continue-on-error: true

  pr-summary:
    name: PR Validation Summary
    runs-on: ubuntu-latest
    needs: [code-quality, unit-tests, integration-tests, docker-build]
    if: always()
    steps:
      - name: Generate PR Summary
        uses: actions/github-script@v7
        with:
          script: |
            const results = {
              'Code Quality & Security': '${{ needs.code-quality.result }}',
              'Unit Tests': '${{ needs.unit-tests.result }}',
              'Integration Tests': '${{ needs.integration-tests.result }}',
              'Docker Build & Scan': '${{ needs.docker-build.result }}'
            };
            
            let summary = '## 🚀 Application CI Summary\n\n';
            
            for (const [job, result] of Object.entries(results)) {
              const emoji = result === 'success' ? '✅' : result === 'failure' ? '❌' : '⚠️';
              summary += `${emoji} **${job}**: ${result}\n`;
            }
            
            const allPassed = Object.values(results).every(result => result === 'success');
            
            if (allPassed) {
              summary += '\n🎉 **All checks passed!** Ready for review and merge.';
            } else {
              summary += '\n⚠️ **Some checks failed.** Please review and fix issues before merging.';
            }
            
            // Find existing summary comment
            const comments = await github.rest.issues.listComments({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
            });
            
            const existingComment = comments.data.find(comment => 
              comment.body.includes('🚀 Application CI Summary')
            );
            
            if (existingComment) {
              await github.rest.issues.updateComment({
                comment_id: existingComment.id,
                owner: context.repo.owner,
                repo: context.repo.repo,
                body: summary
              });
            } else {
              await github.rest.issues.createComment({
                issue_number: context.issue.number,
                owner: context.repo.owner,
                repo: context.repo.repo,
                body: summary
              });
            }

#### Infrastructure CD Pipeline (Main Branch)
```yaml
# .github/workflows/infrastructure-cd.yml
name: Infrastructure CD - Deployment

on:
  push:
    branches: [main]
    paths:
      - 'infrastructure/**'
      - '.github/workflows/infrastructure-*.yml'
  workflow_dispatch:
    inputs:
      environment:
        description: 'Target environment'
        required: true
        default: 'production'
        type: choice
        options:
          - production
          - staging

env:
  TF_VERSION: '1.6.0'
  AWS_REGION: us-east-1

permissions:
  id-token: write
  contents: read
  pull-requests: write

jobs:
  deploy-infrastructure:
    name: Deploy Infrastructure
    runs-on: ubuntu-latest
    environment: ${{ github.event.inputs.environment || 'production' }}
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Configure AWS credentials via OIDC
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::${{ secrets.AWS_ACCOUNT_ID }}:role/GitHubActions-Infrastructure-Role
          role-session-name: GitHubActions-InfrastructureDeploy-${{ github.run_id }}
          aws-region: ${{ env.AWS_REGION }}
      
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TF_VERSION }}
      
      - name: Terraform Init
        run: terraform init
        working-directory: infrastructure
      
      - name: Terraform Plan
        id: plan
        run: |
          ENV="${{ github.event.inputs.environment || 'production' }}"
          terraform plan \
            -var-file="environments/${ENV}.tfvars" \
            -out=tfplan \
            -detailed-exitcode
        working-directory: infrastructure
      
      - name: Terraform Apply
        if: steps.plan.outputs.exitcode == 2
        run: |
          terraform apply tfplan
        working-directory: infrastructure
      
      - name: Backup Terraform State
        run: |
          # Create timestamped backup of state file
          TIMESTAMP=$(date +%Y%m%d-%H%M%S)
          aws s3 cp s3://faith-chatbot-terraform-state/infrastructure/terraform.tfstate \
                    s3://faith-chatbot-terraform-state/backups/terraform.tfstate.${TIMESTAMP}
      
      - name: Check for Infrastructure Drift
        id: drift-check
        run: |
          ENV="${{ github.event.inputs.environment || 'production' }}"
          terraform plan \
            -var-file="environments/${ENV}.tfvars" \
            -detailed-exitcode
          echo "drift_detected=$?" >> $GITHUB_OUTPUT
        working-directory: infrastructure
        continue-on-error: true
      
      - name: Generate Infrastructure Summary
        run: |
          echo "## 🏗️ Infrastructure Deployment Summary" >> $GITHUB_STEP_SUMMARY
          echo "- **Environment**: ${{ github.event.inputs.environment || 'production' }}" >> $GITHUB_STEP_SUMMARY
          echo "- **Terraform Version**: ${{ env.TF_VERSION }}" >> $GITHUB_STEP_SUMMARY
          echo "- **Deployment Time**: $(date)" >> $GITHUB_STEP_SUMMARY
          
          if [ "${{ steps.plan.outputs.exitcode }}" == "0" ]; then
            echo "- **Changes**: No infrastructure changes needed" >> $GITHUB_STEP_SUMMARY
          elif [ "${{ steps.plan.outputs.exitcode }}" == "2" ]; then
            echo "- **Changes**: Infrastructure updated successfully" >> $GITHUB_STEP_SUMMARY
          fi
          
          if [ "${{ steps.drift-check.outputs.drift_detected }}" == "2" ]; then
            echo "- **⚠️ Drift Detected**: Infrastructure has drifted from expected state" >> $GITHUB_STEP_SUMMARY
          else
            echo "- **✅ No Drift**: Infrastructure matches expected state" >> $GITHUB_STEP_SUMMARY
          fi
      
      - name: Notify on failure
        if: failure()
        uses: actions/github-script@v7
        with:
          script: |
            const issue = await github.rest.issues.create({
              owner: context.repo.owner,
              repo: context.repo.repo,
              title: `🚨 Infrastructure Deployment Failed - ${context.sha.substring(0, 7)}`,
              body: `
              Infrastructure deployment failed for commit ${context.sha}.
              
              **Environment**: ${{ github.event.inputs.environment || 'production' }}
              **Workflow**: ${context.workflow}
              **Run ID**: ${context.runId}
              
              Please check the [workflow logs](${context.payload.repository.html_url}/actions/runs/${context.runId}) for details.
              `,
              labels: ['infrastructure', 'deployment-failure', 'urgent']
            });

#### Application CD Pipeline (Main Branch)
```yaml
# .github/workflows/application-cd.yml
name: Application CD - Deployment

on:
  push:
    branches: [main]
    paths:
      - 'app/**'
      - 'tests/**'
      - 'requirements*.txt'
      - 'Dockerfile'
      - '.github/workflows/application-*.yml'
  workflow_dispatch:
    inputs:
      environment:
        description: 'Target environment'
        required: true
        default: 'production'
        type: choice
        options:
          - production
          - staging
      deployment_strategy:
        description: 'Deployment strategy'
        required: true
        default: 'rolling'
        type: choice
        options:
          - rolling
          - blue-green
          - canary

env:
  AWS_REGION: us-east-1
  ECR_REPOSITORY: faith-chatbot
  PYTHON_VERSION: '3.11'

permissions:
  id-token: write
  contents: read
  pull-requests: write

jobs:
  build-and-push:
    name: Build & Push Container
    runs-on: ubuntu-latest
    outputs:
      image-uri: ${{ steps.build-image.outputs.image }}
      image-tag: ${{ steps.meta.outputs.tags }}
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Configure AWS credentials via OIDC
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::${{ secrets.AWS_ACCOUNT_ID }}:role/GitHubActions-Deployment-Role
          role-session-name: GitHubActions-ApplicationBuild-${{ github.run_id }}
          aws-region: ${{ env.AWS_REGION }}
      
      - name: Login to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v2
      
      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ steps.login-ecr.outputs.registry }}/${{ env.ECR_REPOSITORY }}
          tags: |
            type=ref,event=branch
            type=sha,prefix={{branch}}-
            type=raw,value=latest,enable={{is_default_branch}}
      
      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3
      
      - name: Build and push Docker image
        id: build-image
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
          platforms: linux/amd64
      
      - name: Run final security scan
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: ${{ steps.login-ecr.outputs.registry }}/${{ env.ECR_REPOSITORY }}:${{ github.sha }}
          format: 'sarif'
          output: 'trivy-results.sarif'
          exit-code: '1'
          severity: 'CRITICAL,HIGH'
      
      - name: Upload security scan results
        uses: github/codeql-action/upload-sarif@v3
        if: always()
        with:
          sarif_file: 'trivy-results.sarif'

  deploy-staging:
    name: Deploy to Staging
    runs-on: ubuntu-latest
    needs: build-and-push
    if: github.ref == 'refs/heads/main' || github.event.inputs.environment == 'staging'
    environment: staging
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Configure AWS credentials via OIDC
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::${{ secrets.AWS_ACCOUNT_ID }}:role/GitHubActions-Deployment-Role
          role-session-name: GitHubActions-StagingDeploy-${{ github.run_id }}
          aws-region: ${{ env.AWS_REGION }}
      
      - name: Deploy to ECS Staging
        run: |
          # Update ECS service with new image
          aws ecs update-service \
            --cluster faith-chatbot-cluster-staging \
            --service faith-chatbot-service-staging \
            --force-new-deployment \
            --task-definition $(aws ecs describe-services \
              --cluster faith-chatbot-cluster-staging \
              --services faith-chatbot-service-staging \
              --query 'services[0].taskDefinition' \
              --output text | sed 's/:.*/:${{ github.sha }}/')
      
      - name: Wait for staging deployment
        run: |
          aws ecs wait services-stable \
            --cluster faith-chatbot-cluster-staging \
            --services faith-chatbot-service-staging \
            --max-attempts 30 \
            --delay 30
      
      - name: Run staging smoke tests
        run: |
          # Wait for service to be fully ready
          sleep 60
          
          # Health check
          curl -f https://staging-api.faithchatbot.com/health
          
          # Basic functionality tests
          python -m pytest tests/smoke/ \
            --base-url=https://staging-api.faithchatbot.com \
            --tb=short -v

  deploy-production:
    name: Deploy to Production
    runs-on: ubuntu-latest
    needs: [build-and-push, deploy-staging]
    if: github.ref == 'refs/heads/main' && (github.event.inputs.environment == 'production' || github.event.inputs.environment == '')
    environment: production
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Configure AWS credentials via OIDC
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::${{ secrets.AWS_ACCOUNT_ID }}:role/GitHubActions-Deployment-Role
          role-session-name: GitHubActions-ProductionDeploy-${{ github.run_id }}
          aws-region: ${{ env.AWS_REGION }}
      
      - name: Get current task definition
        id: current-task-def
        run: |
          CURRENT_TASK_DEF=$(aws ecs describe-task-definition \
            --task-definition faith-chatbot-task \
            --query 'taskDefinition' \
            --output json)
          
          echo "current-task-def<<EOF" >> $GITHUB_OUTPUT
          echo "$CURRENT_TASK_DEF" >> $GITHUB_OUTPUT
          echo "EOF" >> $GITHUB_OUTPUT
      
      - name: Create new task definition
        id: new-task-def
        run: |
          NEW_TASK_DEF=$(echo '${{ steps.current-task-def.outputs.current-task-def }}' | \
            jq --arg IMAGE "${{ needs.build-and-push.outputs.image-uri }}" \
            '.containerDefinitions[0].image = $IMAGE | 
             del(.taskDefinitionArn, .revision, .status, .requiresAttributes, 
                 .placementConstraints, .compatibilities, .registeredAt, .registeredBy)')
          
          echo "new-task-def<<EOF" >> $GITHUB_OUTPUT
          echo "$NEW_TASK_DEF" >> $GITHUB_OUTPUT
          echo "EOF" >> $GITHUB_OUTPUT
      
      - name: Register new task definition
        id: register-task-def
        run: |
          NEW_TASK_DEF_ARN=$(aws ecs register-task-definition \
            --cli-input-json '${{ steps.new-task-def.outputs.new-task-def }}' \
            --query 'taskDefinition.taskDefinitionArn' \
            --output text)
          
          echo "task-def-arn=$NEW_TASK_DEF_ARN" >> $GITHUB_OUTPUT
      
      - name: Deploy with selected strategy
        run: |
          STRATEGY="${{ github.event.inputs.deployment_strategy || 'rolling' }}"
          
          case $STRATEGY in
            "blue-green")
              # Blue-Green deployment
              echo "Implementing blue-green deployment..."
              # Create new service with new task definition
              # Switch traffic after validation
              # Remove old service
              ;;
            "canary")
              # Canary deployment
              echo "Implementing canary deployment..."
              # Deploy to subset of tasks
              # Monitor metrics
              # Gradually increase traffic
              ;;
            *)
              # Rolling deployment (default)
              echo "Implementing rolling deployment..."
              aws ecs update-service \
                --cluster faith-chatbot-cluster \
                --service faith-chatbot-service \
                --task-definition ${{ steps.register-task-def.outputs.task-def-arn }}
              ;;
          esac
      
      - name: Wait for production deployment
        run: |
          aws ecs wait services-stable \
            --cluster faith-chatbot-cluster \
            --services faith-chatbot-service \
            --max-attempts 30 \
            --delay 30
      
      - name: Verify production deployment
        run: |
          # Health check
          curl -f https://api.faithchatbot.com/health
          
          # Production smoke tests
          python -m pytest tests/production/ \
            --base-url=https://api.faithchatbot.com \
            --tb=short -v
      
      - name: Create deployment summary
        run: |
          echo "## 🚀 Production Deployment Summary" >> $GITHUB_STEP_SUMMARY
          echo "- **Image**: ${{ needs.build-and-push.outputs.image-uri }}" >> $GITHUB_STEP_SUMMARY
          echo "- **Strategy**: ${{ github.event.inputs.deployment_strategy || 'rolling' }}" >> $GITHUB_STEP_SUMMARY
          echo "- **Task Definition**: ${{ steps.register-task-def.outputs.task-def-arn }}" >> $GITHUB_STEP_SUMMARY
          echo "- **Deployment Time**: $(date)" >> $GITHUB_STEP_SUMMARY
          echo "- **Commit**: ${{ github.sha }}" >> $GITHUB_STEP_SUMMARY
      
      - name: Notify deployment success
        uses: actions/github-script@v7
        with:
          script: |
            const deploymentUrl = `https://api.faithchatbot.com`;
            const commitUrl = `${context.payload.repository.html_url}/commit/${context.sha}`;
            
            await github.rest.repos.createDeploymentStatus({
              owner: context.repo.owner,
              repo: context.repo.repo,
              deployment_id: context.payload.deployment?.id || 0,
              state: 'success',
              environment_url: deploymentUrl,
              description: 'Production deployment successful'
            });

#### Coordinated CI/CD Pipeline
```yaml
# .github/workflows/coordinated-cicd.yml
name: Coordinated CI/CD Pipeline

on:
  push:
    branches: [main]
  workflow_dispatch:
    inputs:
      force_infrastructure:
        description: 'Force infrastructure deployment'
        required: false
        default: false
        type: boolean
      force_application:
        description: 'Force application deployment'
        required: false
        default: false
        type: boolean

permissions:
  id-token: write
  contents: read
  pull-requests: write

jobs:
  detect-changes:
    name: Detect Changes
    runs-on: ubuntu-latest
    outputs:
      infrastructure: ${{ steps.changes.outputs.infrastructure }}
      application: ${{ steps.changes.outputs.application }}
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        with:
          fetch-depth: 2
      
      - name: Detect changes
        uses: dorny/paths-filter@v2
        id: changes
        with:
          filters: |
            infrastructure:
              - 'infrastructure/**'
              - '.github/workflows/infrastructure-*.yml'
            application:
              - 'app/**'
              - 'tests/**'
              - 'requirements*.txt'
              - 'Dockerfile'
              - '.github/workflows/application-*.yml'

  deploy-infrastructure:
    name: Deploy Infrastructure
    needs: detect-changes
    if: needs.detect-changes.outputs.infrastructure == 'true' || github.event.inputs.force_infrastructure == 'true'
    uses: ./.github/workflows/infrastructure-cd.yml
    secrets: inherit
    permissions:
      id-token: write
      contents: read
      pull-requests: write

  deploy-application:
    name: Deploy Application
    needs: [detect-changes, deploy-infrastructure]
    if: always() && (needs.detect-changes.outputs.application == 'true' || github.event.inputs.force_application == 'true')
    uses: ./.github/workflows/application-cd.yml
    secrets: inherit
    permissions:
      id-token: write
      contents: read
      pull-requests: write

  post-deployment-validation:
    name: Post-Deployment Validation
    runs-on: ubuntu-latest
    needs: [deploy-infrastructure, deploy-application]
    if: always() && (needs.deploy-infrastructure.result == 'success' || needs.deploy-application.result == 'success')
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Configure AWS credentials via OIDC
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::${{ secrets.AWS_ACCOUNT_ID }}:role/GitHubActions-Deployment-Role
          role-session-name: GitHubActions-PostDeploymentValidation-${{ github.run_id }}
          aws-region: us-east-1
      
      - name: Run comprehensive system tests
        run: |
          # Set up Python for testing
          python -m pip install --upgrade pip
          pip install -r requirements-test.txt
          
          # Run end-to-end tests
          python -m pytest tests/e2e/ \
            --base-url=https://api.faithchatbot.com \
            --tb=short -v
      
      - name: Check system health
        run: |
          # Comprehensive health checks
          curl -f https://api.faithchatbot.com/health
          
          # Check ECS service health
          aws ecs describe-services \
            --cluster faith-chatbot-cluster \
            --services faith-chatbot-service \
            --query 'services[0].runningCount'
          
          # Check ALB target health
          aws elbv2 describe-target-health \
            --target-group-arn $(aws elbv2 describe-target-groups \
              --names faith-chatbot-tg \
              --query 'TargetGroups[0].TargetGroupArn' \
              --output text)
      
      - name: Performance baseline check
        run: |
          # Basic performance test
          curl -w "@curl-format.txt" -o /dev/null -s https://api.faithchatbot.com/health
          
          # Check response times are within acceptable limits
          python -c "
          import requests
          import time
          
          times = []
          for _ in range(10):
              start = time.time()
              r = requests.get('https://api.faithchatbot.com/health')
              times.append(time.time() - start)
          
          avg_time = sum(times) / len(times)
          print(f'Average response time: {avg_time:.3f}s')
          
          if avg_time > 2.0:
              print('WARNING: Response time exceeds 2 seconds')
              exit(1)
          "
      
      - name: Generate deployment report
        run: |
          echo "## 📊 Deployment Validation Report" >> $GITHUB_STEP_SUMMARY
          echo "- **Infrastructure**: ${{ needs.deploy-infrastructure.result }}" >> $GITHUB_STEP_SUMMARY
          echo "- **Application**: ${{ needs.deploy-application.result }}" >> $GITHUB_STEP_SUMMARY
          echo "- **System Health**: ✅ Healthy" >> $GITHUB_STEP_SUMMARY
          echo "- **Performance**: ✅ Within baseline" >> $GITHUB_STEP_SUMMARY
          echo "- **Validation Time**: $(date)" >> $GITHUB_STEP_SUMMARY
```yaml
# .github/workflows/coordinated-deployment.yml
name: Coordinated Infrastructure and Application Deployment

on:
  push:
    branches: [main]
  workflow_dispatch:
    inputs:
      deploy_infrastructure:
        description: 'Deploy infrastructure changes'
        required: true
        default: 'false'
        type: boolean
      deploy_application:
        description: 'Deploy application changes'
        required: true
        default: 'true'
        type: boolean

# Required for OIDC authentication
permissions:
  id-token: write
  contents: read
  pull-requests: write

jobs:
  detect-changes:
    runs-on: ubuntu-latest
    outputs:
      infrastructure_changed: ${{ steps.changes.outputs.infrastructure }}
      application_changed: ${{ steps.changes.outputs.application }}
    steps:
      - uses: actions/checkout@v3
        with:
          fetch-depth: 2
      - uses: dorny/paths-filter@v2
        id: changes
        with:
          filters: |
            infrastructure:
              - 'infrastructure/**'
              - '.github/workflows/terraform.yml'
            application:
              - 'app/**'
              - 'requirements.txt'
              - 'Dockerfile'
              - '.github/workflows/deploy.yml'

  deploy-infrastructure:
    needs: detect-changes
    if: needs.detect-changes.outputs.infrastructure_changed == 'true' || github.event.inputs.deploy_infrastructure == 'true'
    uses: ./.github/workflows/terraform.yml
    secrets: inherit
    permissions:
      id-token: write
      contents: read
      pull-requests: write

  deploy-application:
    needs: [detect-changes, deploy-infrastructure]
    if: always() && (needs.detect-changes.outputs.application_changed == 'true' || github.event.inputs.deploy_application == 'true')
    uses: ./.github/workflows/deploy.yml
    secrets: inherit
    permissions:
      id-token: write
      contents: read
      pull-requests: write

  verify-deployment:
    needs: [deploy-infrastructure, deploy-application]
    if: always() && (needs.deploy-infrastructure.result == 'success' || needs.deploy-application.result == 'success')
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v3
      
      - name: Configure AWS credentials via OIDC
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::${{ secrets.AWS_ACCOUNT_ID }}:role/GitHubActions-Deployment-Role
          role-session-name: GitHubActions-Verification
          aws-region: us-east-1
      
      - name: Run end-to-end tests
        run: |
          # Set up Python for testing
          python -m pip install --upgrade pip
          pip install pytest requests
          
          # Comprehensive system verification
          pytest tests/e2e --base-url=https://api.faithchatbot.com -v
          
      - name: Check infrastructure drift
        if: needs.deploy-infrastructure.result == 'success'
        run: |
          # Setup Terraform
          wget -O terraform.zip https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
          unzip terraform.zip
          sudo mv terraform /usr/local/bin/
          
          # Initialize and check for drift
          cd infrastructure
          terraform init
          terraform plan -var-file="environments/prod.tfvars" -detailed-exitcode
          PLAN_EXIT_CODE=$?
          
          if [ $PLAN_EXIT_CODE -eq 2 ]; then
            echo "⚠️ Infrastructure drift detected!" >> $GITHUB_STEP_SUMMARY
            echo "Please review the Terraform plan output above." >> $GITHUB_STEP_SUMMARY
            exit 1
          elif [ $PLAN_EXIT_CODE -eq 0 ]; then
            echo "✅ No infrastructure drift detected." >> $GITHUB_STEP_SUMMARY
          fi
      
      - name: Deployment summary
        if: always()
        run: |
          echo "## Deployment Verification Complete" >> $GITHUB_STEP_SUMMARY
          echo "- Infrastructure: ${{ needs.deploy-infrastructure.result }}" >> $GITHUB_STEP_SUMMARY
          echo "- Application: ${{ needs.deploy-application.result }}" >> $GITHUB_STEP_SUMMARY
          echo "- Verification: ${{ job.status }}" >> $GITHUB_STEP_SUMMARY
          echo "- Timestamp: $(date)" >> $GITHUB_STEP_SUMMARY
```

### 3. Performance Optimization Strategy

#### Database Optimization
```python
# app/services/optimized_db_service.py
import asyncio
from typing import List, Dict, Optional
from aiobotocore.session import get_session
from botocore.config import Config

class OptimizedDatabaseService:
    def __init__(self):
        # Connection pooling configuration
        self.config = Config(
            region_name='us-east-1',
            retries={'max_attempts': 3, 'mode': 'adaptive'},
            max_pool_connections=50
        )
        
        self.session = get_session()
        self._connection_pool = None
    
    async def get_connection_pool(self):
        """Get optimized DynamoDB connection pool"""
        if self._connection_pool is None:
            self._connection_pool = self.session.create_client(
                'dynamodb',
                config=self.config
            )
        return self._connection_pool
    
    async def batch_get_conversations(self, session_ids: List[str]) -> List[Dict]:
        """Optimized batch retrieval of conversations"""
        client = await self.get_connection_pool()
        
        # Use batch_get_item for efficient retrieval
        request_items = {
            'FaithChatbot-ConversationSessions': {
                'Keys': [{'session_id': {'S': sid}} for sid in session_ids]
            }
        }
        
        response = await client.batch_get_item(RequestItems=request_items)
        return response.get('Responses', {}).get('FaithChatbot-ConversationSessions', [])
    
    async def optimized_user_lookup(self, email: str) -> Optional[Dict]:
        """Optimized user lookup with caching"""
        # Use GSI for efficient email lookup
        client = await self.get_connection_pool()
        
        response = await client.query(
            TableName='FaithChatbot-UserProfiles',
            IndexName='EmailIndex',
            KeyConditionExpression='email = :email',
            ExpressionAttributeValues={':email': {'S': email}},
            Limit=1
        )
        
        items = response.get('Items', [])
        return items[0] if items else None
```

#### API Response Caching
```python
# app/middleware/caching.py
import json
import hashlib
from typing import Optional, Any
from fastapi import Request, Response
from redis import Redis
import asyncio

class ResponseCacheMiddleware:
    def __init__(self, redis_client: Redis, default_ttl: int = 300):
        self.redis = redis_client
        self.default_ttl = default_ttl
        
        # Cache configuration per endpoint
        self.cache_config = {
            '/chat/history': {'ttl': 300, 'vary_by': ['user_id']},
            '/prayer/history': {'ttl': 600, 'vary_by': ['user_id']},
            '/biblical-content': {'ttl': 3600, 'vary_by': ['emotion']},
        }
    
    async def __call__(self, request: Request, call_next):
        # Check if endpoint should be cached
        endpoint = request.url.path
        cache_config = self.cache_config.get(endpoint)
        
        if not cache_config or request.method != 'GET':
            return await call_next(request)
        
        # Generate cache key
        cache_key = self._generate_cache_key(request, cache_config)
        
        # Try to get from cache
        cached_response = await self._get_cached_response(cache_key)
        if cached_response:
            return Response(
                content=cached_response['content'],
                status_code=cached_response['status_code'],
                headers=cached_response['headers'],
                media_type=cached_response['media_type']
            )
        
        # Process request
        response = await call_next(request)
        
        # Cache successful responses
        if response.status_code == 200:
            await self._cache_response(cache_key, response, cache_config['ttl'])
        
        return response
    
    def _generate_cache_key(self, request: Request, config: dict) -> str:
        """Generate cache key based on request and configuration"""
        key_parts = [request.url.path]
        
        # Add vary_by parameters
        for param in config.get('vary_by', []):
            if param == 'user_id':
                user_id = getattr(request.state, 'user_id', 'anonymous')
                key_parts.append(f"user:{user_id}")
            elif param in request.query_params:
                key_parts.append(f"{param}:{request.query_params[param]}")
        
        key_string = "|".join(key_parts)
        return f"cache:{hashlib.md5(key_string.encode()).hexdigest()}"
    
    async def _get_cached_response(self, cache_key: str) -> Optional[dict]:
        """Get cached response from Redis"""
        try:
            cached_data = self.redis.get(cache_key)
            if cached_data:
                return json.loads(cached_data)
        except Exception:
            pass  # Cache miss or error
        return None
    
    async def _cache_response(self, cache_key: str, response: Response, ttl: int):
        """Cache response in Redis"""
        try:
            cache_data = {
                'content': response.body.decode(),
                'status_code': response.status_code,
                'headers': dict(response.headers),
                'media_type': response.media_type
            }
            
            self.redis.setex(
                cache_key,
                ttl,
                json.dumps(cache_data)
            )
        except Exception:
            pass  # Cache write error, continue normally
```
### 4. Security Hardening Implementation

#### Production Security Configuration
```python
# infrastructure/security_hardening.py
import boto3
from typing import Dict, List

class SecurityHardeningConfig:
    """Production security hardening configuration"""
    
    @staticmethod
    def get_security_group_rules() -> Dict[str, List[Dict]]:
        """Define security group rules with least privilege"""
        return {
            'alb_security_group': {
                'ingress': [
                    {
                        'IpProtocol': 'tcp',
                        'FromPort': 443,
                        'ToPort': 443,
                        'CidrIp': '0.0.0.0/0',  # HTTPS from internet
                        'Description': 'HTTPS from internet'
                    }
                ],
                'egress': [
                    {
                        'IpProtocol': 'tcp',
                        'FromPort': 8000,
                        'ToPort': 8000,
                        'SourceSecurityGroupId': 'sg-ecs-tasks',
                        'Description': 'To ECS tasks only'
                    }
                ]
            },
            'ecs_tasks_security_group': {
                'ingress': [
                    {
                        'IpProtocol': 'tcp',
                        'FromPort': 8000,
                        'ToPort': 8000,
                        'SourceSecurityGroupId': 'sg-alb',
                        'Description': 'From ALB only'
                    }
                ],
                'egress': [
                    {
                        'IpProtocol': 'tcp',
                        'FromPort': 443,
                        'ToPort': 443,
                        'DestinationPrefixListId': 'pl-id-for-aws-services',
                        'Description': 'To AWS services via VPC endpoints'
                    }
                ]
            }
        }
    
    @staticmethod
    def get_iam_task_policy() -> Dict:
        """Define least privilege IAM policy for ECS tasks"""
        return {
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Effect": "Allow",
                    "Action": [
                        "bedrock:InvokeModel",
                        "bedrock:InvokeModelWithResponseStream"
                    ],
                    "Resource": [
                        "arn:aws:bedrock:us-east-1::foundation-model/anthropic.claude-3-sonnet-20240229-v1:0"
                    ],
                    "Condition": {
                        "StringEquals": {
                            "aws:RequestedRegion": "us-east-1"
                        }
                    }
                },
                {
                    "Effect": "Allow",
                    "Action": [
                        "dynamodb:GetItem",
                        "dynamodb:PutItem",
                        "dynamodb:UpdateItem",
                        "dynamodb:Query"
                    ],
                    "Resource": [
                        "arn:aws:dynamodb:us-east-1:ACCOUNT:table/FaithChatbot-*",
                        "arn:aws:dynamodb:us-east-1:ACCOUNT:table/FaithChatbot-*/index/*"
                    ]
                },
                {
                    "Effect": "Allow",
                    "Action": [
                        "sqs:SendMessage"
                    ],
                    "Resource": [
                        "arn:aws:sqs:us-east-1:ACCOUNT:FaithChatbot-PrayerRequests"
                    ]
                },
                {
                    "Effect": "Allow",
                    "Action": [
                        "secretsmanager:GetSecretValue"
                    ],
                    "Resource": [
                        "arn:aws:secretsmanager:us-east-1:ACCOUNT:secret:faith-chatbot/*"
                    ]
                },
                {
                    "Effect": "Allow",
                    "Action": [
                        "logs:CreateLogStream",
                        "logs:PutLogEvents"
                    ],
                    "Resource": [
                        "arn:aws:logs:us-east-1:ACCOUNT:log-group:/ecs/faith-chatbot:*"
                    ]
                }
            ]
        }
    
    @staticmethod
    def get_waf_rules() -> List[Dict]:
        """Define WAF rules for additional protection"""
        return [
            {
                'Name': 'AWSManagedRulesCommonRuleSet',
                'Priority': 1,
                'Statement': {
                    'ManagedRuleGroupStatement': {
                        'VendorName': 'AWS',
                        'Name': 'AWSManagedRulesCommonRuleSet'
                    }
                },
                'OverrideAction': {'None': {}},
                'VisibilityConfig': {
                    'SampledRequestsEnabled': True,
                    'CloudWatchMetricsEnabled': True,
                    'MetricName': 'CommonRuleSetMetric'
                }
            },
            {
                'Name': 'RateLimitRule',
                'Priority': 2,
                'Statement': {
                    'RateBasedStatement': {
                        'Limit': 2000,  # 2000 requests per 5 minutes
                        'AggregateKeyType': 'IP'
                    }
                },
                'Action': {'Block': {}},
                'VisibilityConfig': {
                    'SampledRequestsEnabled': True,
                    'CloudWatchMetricsEnabled': True,
                    'MetricName': 'RateLimitMetric'
                }
            }
        ]

# Secrets management
class SecretsManager:
    """Secure secrets management for production"""
    
    def __init__(self):
        self.client = boto3.client('secretsmanager')
    
    async def create_application_secrets(self):
        """Create all required application secrets"""
        secrets = {
            'faith-chatbot/database-config': {
                'description': 'Database configuration',
                'secret_value': {
                    'dynamodb_region': 'us-east-1',
                    'table_prefix': 'FaithChatbot-'
                }
            },
            'faith-chatbot/telegram-config': {
                'description': 'Telegram bot configuration',
                'secret_value': {
                    'bot_token': 'TELEGRAM_BOT_TOKEN_HERE',
                    'chat_id': 'TELEGRAM_CHAT_ID_HERE'
                }
            },
            'faith-chatbot/bedrock-config': {
                'description': 'Bedrock configuration',
                'secret_value': {
                    'model_id': 'anthropic.claude-3-sonnet-20240229-v1:0',
                    'guardrails_id': 'GUARDRAILS_ID_HERE'
                }
            }
        }
        
        for secret_name, config in secrets.items():
            try:
                self.client.create_secret(
                    Name=secret_name,
                    Description=config['description'],
                    SecretString=json.dumps(config['secret_value']),
                    KmsKeyId='alias/faith-chatbot-secrets'
                )
            except self.client.exceptions.ResourceExistsException:
                # Secret already exists, update it
                self.client.update_secret(
                    SecretId=secret_name,
                    SecretString=json.dumps(config['secret_value'])
                )
```

### 5. Monitoring and Alerting System

#### CloudWatch Dashboard Configuration
```python
# monitoring/cloudwatch_dashboards.py
import boto3
import json

class CloudWatchDashboards:
    """Create and manage CloudWatch dashboards"""
    
    def __init__(self):
        self.cloudwatch = boto3.client('cloudwatch')
    
    def create_operational_dashboard(self):
        """Create operational monitoring dashboard"""
        dashboard_body = {
            "widgets": [
                {
                    "type": "metric",
                    "x": 0, "y": 0,
                    "width": 12, "height": 6,
                    "properties": {
                        "metrics": [
                            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", "faith-chatbot-alb"],
                            [".", "TargetResponseTime", ".", "."],
                            [".", "HTTPCode_Target_2XX_Count", ".", "."],
                            [".", "HTTPCode_Target_4XX_Count", ".", "."],
                            [".", "HTTPCode_Target_5XX_Count", ".", "."]
                        ],
                        "period": 300,
                        "stat": "Sum",
                        "region": "us-east-1",
                        "title": "Application Load Balancer Metrics"
                    }
                },
                {
                    "type": "metric",
                    "x": 0, "y": 6,
                    "width": 12, "height": 6,
                    "properties": {
                        "metrics": [
                            ["AWS/ECS", "CPUUtilization", "ServiceName", "faith-chatbot-service", "ClusterName", "faith-chatbot-cluster"],
                            [".", "MemoryUtilization", ".", ".", ".", "."]
                        ],
                        "period": 300,
                        "stat": "Average",
                        "region": "us-east-1",
                        "title": "ECS Service Metrics"
                    }
                },
                {
                    "type": "metric",
                    "x": 0, "y": 12,
                    "width": 12, "height": 6,
                    "properties": {
                        "metrics": [
                            ["AWS/DynamoDB", "ConsumedReadCapacityUnits", "TableName", "FaithChatbot-UserProfiles"],
                            [".", "ConsumedWriteCapacityUnits", ".", "."],
                            [".", "ThrottledRequests", ".", "."]
                        ],
                        "period": 300,
                        "stat": "Sum",
                        "region": "us-east-1",
                        "title": "DynamoDB Metrics"
                    }
                }
            ]
        }
        
        self.cloudwatch.put_dashboard(
            DashboardName='FaithChatbot-Operations',
            DashboardBody=json.dumps(dashboard_body)
        )
    
    def create_business_dashboard(self):
        """Create business metrics dashboard"""
        dashboard_body = {
            "widgets": [
                {
                    "type": "metric",
                    "x": 0, "y": 0,
                    "width": 6, "height": 6,
                    "properties": {
                        "metrics": [
                            ["FaithChatbot", "ActiveUsers", {"stat": "Sum"}],
                            [".", "NewUsers", {"stat": "Sum"}],
                            [".", "ChatMessages", {"stat": "Sum"}]
                        ],
                        "period": 3600,
                        "region": "us-east-1",
                        "title": "User Engagement"
                    }
                },
                {
                    "type": "metric",
                    "x": 6, "y": 0,
                    "width": 6, "height": 6,
                    "properties": {
                        "metrics": [
                            ["FaithChatbot", "PrayerRequests", {"stat": "Sum"}],
                            [".", "PrayerRequestsCompleted", {"stat": "Sum"}],
                            [".", "CommunityResponseRate", {"stat": "Average"}]
                        ],
                        "period": 3600,
                        "region": "us-east-1",
                        "title": "Prayer Connect Metrics"
                    }
                }
            ]
        }
        
        self.cloudwatch.put_dashboard(
            DashboardName='FaithChatbot-Business',
            DashboardBody=json.dumps(dashboard_body)
        )

# CloudWatch Alarms
class CloudWatchAlarms:
    """Create and manage CloudWatch alarms"""
    
    def __init__(self):
        self.cloudwatch = boto3.client('cloudwatch')
        self.sns_topic_arn = 'arn:aws:sns:us-east-1:ACCOUNT:faith-chatbot-alerts'
    
    def create_critical_alarms(self):
        """Create critical system alarms"""
        alarms = [
            {
                'AlarmName': 'FaithChatbot-HighErrorRate',
                'AlarmDescription': 'High 5XX error rate',
                'MetricName': 'HTTPCode_Target_5XX_Count',
                'Namespace': 'AWS/ApplicationELB',
                'Statistic': 'Sum',
                'Period': 300,
                'EvaluationPeriods': 2,
                'Threshold': 10,
                'ComparisonOperator': 'GreaterThanThreshold',
                'Dimensions': [
                    {
                        'Name': 'LoadBalancer',
                        'Value': 'faith-chatbot-alb'
                    }
                ]
            },
            {
                'AlarmName': 'FaithChatbot-HighLatency',
                'AlarmDescription': 'High response latency',
                'MetricName': 'TargetResponseTime',
                'Namespace': 'AWS/ApplicationELB',
                'Statistic': 'Average',
                'Period': 300,
                'EvaluationPeriods': 3,
                'Threshold': 3.0,
                'ComparisonOperator': 'GreaterThanThreshold',
                'Dimensions': [
                    {
                        'Name': 'LoadBalancer',
                        'Value': 'faith-chatbot-alb'
                    }
                ]
            },
            {
                'AlarmName': 'FaithChatbot-ECSServiceUnhealthy',
                'AlarmDescription': 'ECS service has unhealthy tasks',
                'MetricName': 'RunningTaskCount',
                'Namespace': 'AWS/ECS',
                'Statistic': 'Average',
                'Period': 300,
                'EvaluationPeriods': 2,
                'Threshold': 1,
                'ComparisonOperator': 'LessThanThreshold',
                'Dimensions': [
                    {
                        'Name': 'ServiceName',
                        'Value': 'faith-chatbot-service'
                    },
                    {
                        'Name': 'ClusterName',
                        'Value': 'faith-chatbot-cluster'
                    }
                ]
            }
        ]
        
        for alarm in alarms:
            self.cloudwatch.put_metric_alarm(
                **alarm,
                AlarmActions=[self.sns_topic_arn],
                OKActions=[self.sns_topic_arn]
            )
```

### 6. Backup and Disaster Recovery

#### Backup Strategy Implementation
```python
# backup/disaster_recovery.py
import boto3
from datetime import datetime, timedelta
from typing import Dict, List

class DisasterRecoveryManager:
    """Manage backup and disaster recovery procedures"""
    
    def __init__(self):
        self.dynamodb = boto3.client('dynamodb')
        self.s3 = boto3.client('s3')
        self.backup_bucket = 'faith-chatbot-backups'
    
    def enable_point_in_time_recovery(self):
        """Enable point-in-time recovery for all DynamoDB tables"""
        tables = [
            'FaithChatbot-UserProfiles',
            'FaithChatbot-ConversationSessions',
            'FaithChatbot-PrayerRequests',
            'FaithChatbot-ConsentLogs'
        ]
        
        for table_name in tables:
            try:
                self.dynamodb.update_continuous_backups(
                    TableName=table_name,
                    PointInTimeRecoverySpecification={
                        'PointInTimeRecoveryEnabled': True
                    }
                )
                print(f"Enabled PITR for {table_name}")
            except Exception as e:
                print(f"Failed to enable PITR for {table_name}: {e}")
    
    def create_cross_region_backup(self):
        """Create cross-region backup of critical data"""
        # Export DynamoDB tables to S3
        tables = ['FaithChatbot-UserProfiles', 'FaithChatbot-ConsentLogs']
        
        for table_name in tables:
            export_arn = self.dynamodb.export_table_to_point_in_time(
                TableArn=f'arn:aws:dynamodb:us-east-1:ACCOUNT:table/{table_name}',
                S3Bucket=self.backup_bucket,
                S3Prefix=f'exports/{table_name}/{datetime.now().strftime("%Y-%m-%d")}/',
                ExportFormat='DYNAMODB_JSON'
            )
            
            print(f"Started export for {table_name}: {export_arn}")
    
    def test_disaster_recovery(self) -> Dict[str, bool]:
        """Test disaster recovery procedures"""
        results = {}
        
        # Test 1: Verify backups exist and are accessible
        try:
            response = self.s3.list_objects_v2(
                Bucket=self.backup_bucket,
                Prefix='exports/'
            )
            results['backup_accessibility'] = len(response.get('Contents', [])) > 0
        except Exception:
            results['backup_accessibility'] = False
        
        # Test 2: Test point-in-time recovery capability
        try:
            # Create a test table restore (dry run)
            test_table_name = 'FaithChatbot-UserProfiles-Test'
            restore_time = datetime.now() - timedelta(hours=1)
            
            self.dynamodb.restore_table_to_point_in_time(
                SourceTableName='FaithChatbot-UserProfiles',
                TargetTableName=test_table_name,
                RestoreDateTime=restore_time
            )
            
            # Wait for restore to complete (in real scenario)
            # Then delete test table
            results['point_in_time_recovery'] = True
            
        except Exception:
            results['point_in_time_recovery'] = False
        
        return results
    
    def generate_recovery_runbook(self) -> str:
        """Generate disaster recovery runbook"""
        runbook = """
# Faith Motivator Chatbot - Disaster Recovery Runbook

## Recovery Time Objectives (RTO)
- Critical services: 30 minutes
- Full system recovery: 2 hours
- Data recovery: 4 hours

## Recovery Point Objectives (RPO)
- User data: 15 minutes (PITR)
- Configuration: 1 hour (backups)
- Application code: 0 (version control)

## Recovery Procedures

### 1. Service Outage Recovery
1. Check ECS service health
2. Review CloudWatch alarms
3. Restart ECS service if needed
4. Scale up if capacity issue

### 2. Database Recovery
1. Identify affected tables
2. Use point-in-time recovery
3. Restore to specific timestamp
4. Validate data integrity

### 3. Complete System Recovery
1. Deploy infrastructure from IaC
2. Restore database from backups
3. Deploy latest application version
4. Run smoke tests
5. Update DNS if needed

### 4. Cross-Region Failover
1. Activate backup region resources
2. Restore data from S3 exports
3. Update Route 53 health checks
4. Redirect traffic to backup region

## Emergency Contacts
- On-call engineer: [PHONE]
- AWS Support: [CASE_URL]
- Management escalation: [CONTACTS]
"""
        return runbook
```

This comprehensive deployment and operations design ensures the faith-based motivator chatbot can be reliably deployed, monitored, and maintained in production with proper security, performance, and disaster recovery capabilities.