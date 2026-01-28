# Development Environment Configuration
environment = "dev"
aws_region  = "us-east-1"
vpc_cidr    = "172.20.0.0/20"

# Subnet configuration as per Phase 1 requirements
public_subnet_cidrs  = ["172.20.1.0/24", "172.20.2.0/24"]
private_subnet_cidrs = ["172.20.3.0/24", "172.20.4.0/24"]

# Cost optimization for dev - single AZ
enable_nat_gateway = false
availability_zones = ["us-east-1a"]

# Cognito configuration
cognito_domain = "auth-faithchatbot-dev"
callback_urls = [
  "http://localhost:3000/auth/callback",
  "https://dev.faithchatbot.com/auth/callback"
]
logout_urls = [
  "http://localhost:3000/",
  "https://dev.faithchatbot.com/"
]
