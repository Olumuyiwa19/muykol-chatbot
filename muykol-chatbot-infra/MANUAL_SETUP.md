# Manual Terraform Cloud Workspace Setup

If the automated script doesn't work, follow these manual steps:

## 1. Get API Token
1. Go to https://app.terraform.io/app/settings/tokens
2. Create a new API token
3. Export it: `export TF_API_TOKEN=your-token-here`

## 2. Create Organization
1. Go to https://app.terraform.io
2. Create organization: `Kolayemi-org`

## 3. Create Workspaces Manually

### For each environment (dev, staging, prod):

1. **Go to Workspaces**: https://app.terraform.io/app/muykol-chatbot/workspaces
2. **Click "New workspace"**
3. **Choose "CLI-driven workflow"**
4. **Configure workspace**:
   - Name: `muykol-chatbot-dev` (or staging/prod)
   - Description: `muykol-chatbot dev environment infrastructure`
   - Working Directory: `muykol-chatbot-infra`
   - Terraform Version: `~> 1.0`

5. **Add Variables** (in Variables tab):
   - `environment` = `dev` (terraform variable)
   - `AWS_ACCESS_KEY_ID` = `your-key` (environment variable, sensitive)
   - `AWS_SECRET_ACCESS_KEY` = `your-secret` (environment variable, sensitive)
   - `AWS_DEFAULT_REGION` = `us-east-1` (environment variable)

6. **Configure VCS** (optional):
   - Connect to GitHub repository
   - Set trigger paths: `muykol-chatbot-infra/**/*`

## 4. Test Setup

Run from your local machine:
```bash
cd muykol-chatbot-infra
terraform login
terraform init
terraform workspace select muykol-chatbot-dev
terraform plan -var-file="terraform.dev.tfvars"
```

## Quick API Test

Test if your token works:
```bash
curl -H "Authorization: Bearer $TF_API_TOKEN" \
     -H "Content-Type: application/vnd.api+json" \
     https://app.terraform.io/api/v2/organizations/muykol-chatbot
```

Should return organization details if successful.
