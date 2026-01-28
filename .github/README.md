# GitHub Actions CI/CD Pipeline

This directory contains the GitHub Actions workflows for the Faith Motivator Chatbot project.

## Workflows

### 1. Pipeline Test (`pipeline-test.yml`)
**Purpose**: Basic pipeline functionality testing
**Triggers**: 
- Push to any branch
- Pull requests to main/develop
- Manual trigger

**Jobs**:
- Basic environment and repository structure validation
- Infrastructure and application file checks
- Python syntax validation
- Matrix and conditional logic testing

### 2. Infrastructure CI/CD (`infrastructure-ci.yml`)
**Purpose**: Terraform infrastructure validation and deployment
**Triggers**: 
- Push/PR to main/develop with changes in `muykol-chatbot-infra/`

**Jobs**:
- **terraform-validate**: Format check, init, and validate
- **security-scan**: Checkov security scanning with SARIF upload
- **terraform-plan**: Plan generation for pull requests
- **test-pipeline**: Basic pipeline functionality test

**Features**:
- Terraform validation without AWS credentials
- Security scanning with GitHub Security integration
- PR comments with plan results
- Soft-fail security checks for initial testing

### 3. Application CI/CD (`application-ci.yml`)
**Purpose**: Python application testing and Docker builds
**Triggers**: 
- Push/PR to main/develop with changes in `muykol-chatbot-app/`

**Jobs**:
- **code-quality**: Black, isort, flake8, mypy, bandit, safety
- **unit-tests**: pytest with coverage reporting
- **docker-build**: Docker build and Trivy security scanning
- **integration-tests**: LocalStack integration testing
- **test-summary**: Pipeline results summary

**Features**:
- Code quality checks with multiple tools
- Unit testing with coverage reports
- Docker security scanning
- LocalStack integration testing
- Codecov integration

## Setup Instructions

### 1. Repository Secrets (Optional for Testing)
For full functionality, configure these secrets in GitHub repository settings:

```
AWS_GITHUB_ACTIONS_ROLE_ARN=arn:aws:iam::ACCOUNT:role/GitHubActions-Infrastructure-Role
TERRAFORM_STATE_BUCKET=muykol-chatbot-terraform-state
```

### 2. GitHub Environments
Create these environments in repository settings:
- `dev`
- `staging` 
- `prod`

### 3. Branch Protection Rules
Configure branch protection for `main`:
- Require status checks to pass
- Require branches to be up to date
- Include administrators

## Testing the Pipeline

### Method 1: Manual Trigger
1. Go to Actions tab in GitHub
2. Select "Pipeline Test" workflow
3. Click "Run workflow"
4. Select branch and run

### Method 2: Push Changes
1. Make any change to trigger workflows
2. Push to any branch
3. Check Actions tab for results

### Method 3: Create Pull Request
1. Create feature branch
2. Make changes to infrastructure or application
3. Create PR to main/develop
4. Check PR for automated comments and status checks

## Workflow Features

### Security Integration
- **Checkov**: Infrastructure security scanning
- **Bandit**: Python security analysis  
- **Trivy**: Container vulnerability scanning
- **SARIF Upload**: Results appear in GitHub Security tab

### Quality Checks
- **Terraform**: Format, validate, plan
- **Python**: Black, isort, flake8, mypy
- **Testing**: pytest with coverage
- **Dependencies**: Safety vulnerability checks

### Deployment Ready
- **OIDC Authentication**: Secure AWS access
- **Multi-Environment**: Dev, staging, prod support
- **State Management**: Terraform Cloud integration
- **Drift Detection**: Infrastructure monitoring

## Troubleshooting

### Common Issues

1. **Terraform Init Fails**
   - Expected without AWS credentials
   - Will work once OIDC is configured

2. **Security Scans Fail**
   - Set to soft-fail initially
   - Review and adjust skip_check parameters

3. **Python Tests Fail**
   - Check requirements.txt exists
   - Verify Python syntax

4. **Docker Build Fails**
   - Dockerfile will be created automatically if missing
   - Check application dependencies

### Logs and Debugging
- Check Actions tab for detailed logs
- Each job shows step-by-step execution
- Failed jobs highlight specific issues
- SARIF results appear in Security tab

## Next Steps

1. **Test Basic Pipeline**: Run pipeline-test.yml
2. **Configure AWS OIDC**: Set up AWS roles and secrets
3. **Enable Full Deployment**: Configure Terraform Cloud
4. **Add Custom Checks**: Extend workflows as needed
5. **Monitor Security**: Review SARIF results regularly

The pipeline is designed to work immediately for testing and validation, with full deployment capabilities available once AWS integration is configured.