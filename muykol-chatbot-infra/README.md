# Terraform Cloud Setup for muykol-chatbot

This directory contains Terraform configuration for managing AWS infrastructure using Terraform Cloud workspaces.

## Prerequisites

1. **Terraform Cloud Account**: Sign up at https://app.terraform.io
2. **Terraform CLI**: Install from https://www.terraform.io/downloads
3. **AWS Account**: With appropriate permissions for resource creation

## Quick Setup

### 1. Login to Terraform Cloud
```bash
terraform login
```

### 2. Create Organization
Create a new organization in Terraform Cloud named `muykol-chatbot` (or update the org name in `main.tf`)

### 3. Run Setup Script
```bash
cd muykol-chatbot-infra
./setup-terraform-cloud.sh
```

### 4. Configure Workspaces
For each workspace (dev, staging, prod):

1. Go to https://app.terraform.io/app/muykol-chatbot/workspaces
2. Select the workspace
3. Go to Variables tab
4. Add environment variables:
   - `AWS_ACCESS_KEY_ID` (sensitive)
   - `AWS_SECRET_ACCESS_KEY` (sensitive)
   - `AWS_DEFAULT_REGION` = `us-east-1`

### 5. Connect to GitHub
1. In workspace settings, go to Version Control
2. Connect to your GitHub repository
3. Set working directory to `muykol-chatbot-infra`
4. Configure trigger paths: `muykol-chatbot-infra/**/*`

## Workspace Structure

```
muykol-chatbot-dev      # Development environment
muykol-chatbot-staging  # Staging environment  
muykol-chatbot-prod     # Production environment
```

## Environment Variables

Each workspace uses environment-specific `.tfvars` files:
- `terraform.dev.tfvars`
- `terraform.staging.tfvars`
- `terraform.prod.tfvars`

## Manual Workspace Creation

If you prefer manual setup:

1. Create workspace in Terraform Cloud UI
2. Set workspace name: `muykol-chatbot-{env}`
3. Connect to VCS (GitHub)
4. Set working directory: `muykol-chatbot-infra`
5. Configure environment variables
6. Set Terraform variables using the appropriate `.tfvars` file

## Running Terraform

### Via Terraform Cloud UI
1. Go to workspace
2. Click "Queue plan"
3. Review plan
4. Apply if approved

### Via CLI (if needed)
```bash
# Select workspace
terraform workspace select muykol-chatbot-dev

# Plan
terraform plan -var-file="terraform.dev.tfvars"

# Apply
terraform apply -var-file="terraform.dev.tfvars"
```

## Security Best Practices

1. **AWS Credentials**: Use IAM roles with least privilege
2. **Sensitive Variables**: Mark as sensitive in Terraform Cloud
3. **State Encryption**: Terraform Cloud encrypts state by default
4. **Access Control**: Use teams and permissions in Terraform Cloud
5. **Audit Logging**: Enable in Terraform Cloud settings

## Workspace Configuration

Each workspace should have:
- **Execution Mode**: Remote
- **Auto Apply**: Disabled (manual approval)
- **Terraform Version**: ~> 1.0
- **Working Directory**: `muykol-chatbot-infra`
- **VCS Triggers**: `muykol-chatbot-infra/**/*`

## Troubleshooting

### Authentication Issues
```bash
# Re-login to Terraform Cloud
terraform logout
terraform login
```

### Workspace Not Found
Ensure the organization name in `main.tf` matches your Terraform Cloud organization.

### Permission Errors
Check AWS IAM permissions for the credentials configured in the workspace.
