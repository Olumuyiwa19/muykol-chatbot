# Production Environment Configuration
environment = "prod"
aws_region  = "us-east-1"
vpc_cidr    = "10.2.0.0/16"

# Full multi-AZ for production
enable_nat_gateway = true
availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
