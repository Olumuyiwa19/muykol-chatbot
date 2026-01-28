# Production Environment Configuration
environment = "prod"
aws_region  = "us-east-1"
vpc_cidr    = "172.20.0.0/20"

# Subnet configuration as per Phase 1 requirements
public_subnet_cidrs  = ["172.20.1.0/24", "172.20.2.0/24"]
private_subnet_cidrs = ["172.20.3.0/24", "172.20.4.0/24"]

# Full multi-AZ for production
enable_nat_gateway = true
availability_zones = ["us-east-1a", "us-east-1b"]

# Cognito configuration
cognito_domain = "auth-faithchatbot"
callback_urls = [
  "https://faithchatbot.com/auth/callback"
]
logout_urls = [
  "https://faithchatbot.com/"
]
