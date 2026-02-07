# Infracost Quick Reference Guide

## 🎯 What You'll See in PRs

When you create a pull request that modifies infrastructure, Infracost will automatically:

1. ✅ Analyze cost changes
2. 💬 Post a comment with cost breakdown
3. 📊 Show monthly cost differences

## 📝 Example PR Comment

```markdown
💰 Infracost estimate: monthly cost will increase by $45 📈

Project: muykol-chatbot-dev

+ aws_nat_gateway.main[0]
  +$45.00

~ aws_dynamodb_table.user_profiles
  Monthly cost depends on usage
  +$0.00

Monthly cost change for muykol-chatbot-dev
Amount:  +$45 ($60 → $105)
Percent: +75%
```

## 🚦 Understanding the Symbols

- `+` New resource being added
- `-` Resource being removed
- `~` Resource being modified
- `↻` Resource being replaced

## 💡 Cost Interpretation

### Free Tier Resources
Some resources show `$0.00` but may incur costs based on usage:
- **DynamoDB**: On-demand pricing (pay per request)
- **SQS**: First 1M requests/month free
- **Cognito**: First 50K MAUs free
- **Lambda**: First 1M requests/month free

### Fixed Cost Resources
These have predictable monthly costs:
- **NAT Gateway**: ~$45/month per gateway
- **VPC Endpoints**: ~$7-10/month per interface endpoint
- **KMS Keys**: $1/month per key
- **ALB**: ~$20-25/month

### Variable Cost Resources
Costs depend on usage:
- **Bedrock API**: Pay per request (varies by model)
- **Data Transfer**: $0.09/GB after free tier
- **CloudWatch Logs**: $0.50/GB ingested

## 🎬 Action Items When You See Cost Increases

### Small Increase (<$10/month)
- ✅ Review the change
- ✅ Ensure it's necessary
- ✅ Proceed with merge if justified

### Medium Increase ($10-$50/month)
- ⚠️ Review carefully
- ⚠️ Consider alternatives
- ⚠️ Get team approval
- ⚠️ Document the reason

### Large Increase (>$50/month)
- 🛑 Stop and review
- 🛑 Discuss with team lead
- 🛑 Explore cost optimization options
- 🛑 Require explicit approval before merge

## 🔧 Common Cost Optimizations

### 1. NAT Gateway ($45/month savings)
```hcl
# Development
enable_nat_gateway = false  # Use VPC endpoints instead

# Production
enable_nat_gateway = true   # Required for high availability
```

### 2. VPC Endpoints
```hcl
# Only enable endpoints you actually use
# Gateway endpoints (S3, DynamoDB) are free - always use these!
# Interface endpoints cost ~$7-10/month each
```

### 3. Multi-AZ Deployment
```hcl
# Development
availability_zones = ["us-east-1a"]  # Single AZ

# Production
availability_zones = ["us-east-1a", "us-east-1b"]  # Multi-AZ
```

### 4. DynamoDB
```hcl
# Low/unpredictable traffic
billing_mode = "PAY_PER_REQUEST"  # On-demand

# High/predictable traffic
billing_mode = "PROVISIONED"  # Reserved capacity (cheaper at scale)
```

## 📊 Current Environment Costs

### Development (dev.tfvars)
- **Target**: $60-90/month
- **Key Costs**:
  - VPC Endpoints: ~$56-80/month
  - KMS Keys: $2/month
  - CloudWatch Logs: ~$2-5/month
  - DynamoDB: Usage-based
  - SQS: Free tier

### Production (when deployed)
- **Estimated**: $200-400/month
- **Additional Costs**:
  - NAT Gateways: ~$90/month (2 AZs)
  - ALB: ~$20-25/month
  - ECS Fargate: ~$50-150/month
  - Bedrock API: Usage-based
  - Increased data transfer

## 🎓 Best Practices

1. **Review Before Merge**: Always check Infracost comments before merging
2. **Question Surprises**: If costs are higher than expected, investigate why
3. **Document Decisions**: Add comments explaining why cost increases are necessary
4. **Monitor Actual Costs**: Compare Infracost estimates with actual AWS bills
5. **Update Usage Files**: Keep `infracost-usage-dev.yml` updated with realistic usage

## 🔗 Useful Links

- [Infracost Setup Guide](../muykol-chatbot-infra/INFRACOST_SETUP.md)
- [AWS Pricing Calculator](https://calculator.aws/)
- [Infracost Documentation](https://www.infracost.io/docs/)

## ❓ FAQ

**Q: Why does my PR show $0 cost change?**
A: Either no cost-impacting resources changed, or the resources have usage-based pricing that can't be estimated without usage data.

**Q: Can I run Infracost locally?**
A: Yes! See the [setup guide](../muykol-chatbot-infra/INFRACOST_SETUP.md#local-cost-estimation) for instructions.

**Q: Are these estimates accurate?**
A: Infracost uses official AWS pricing data, but actual costs may vary based on:
- Actual usage patterns
- Data transfer amounts
- Free tier eligibility
- Regional pricing differences

**Q: What if Infracost is wrong?**
A: Report discrepancies to the team. We can update usage files or investigate pricing data issues.

## 🚀 Getting Started

1. **First Time Setup**: Add `INFRACOST_API_KEY` to GitHub Secrets (see [setup guide](../muykol-chatbot-infra/INFRACOST_SETUP.md))
2. **Create a Test PR**: Make a small infrastructure change to see Infracost in action
3. **Review the Comment**: Familiarize yourself with the cost breakdown format
4. **Start Using**: Incorporate cost review into your PR workflow

---

**Remember**: Cost awareness is part of responsible infrastructure management. Use Infracost to make informed decisions! 💰
