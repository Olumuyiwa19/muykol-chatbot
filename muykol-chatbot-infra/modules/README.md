# Terraform Modules

This directory contains reusable Terraform modules for the muykol-chatbot infrastructure.

## Module Structure

```
modules/
├── vpc/          # VPC, subnets, routing
├── ecs/          # ECS cluster and services
├── dynamodb/     # DynamoDB tables
├── alb/          # Application Load Balancer
└── cognito/      # AWS Cognito User Pool
```

## Usage

Modules will be implemented during Phase 1 infrastructure setup.

Example usage:
```hcl
module "vpc" {
  source = "./modules/vpc"
  
  environment        = var.environment
  vpc_cidr          = var.vpc_cidr
  availability_zones = var.availability_zones
}
```

## Development

Each module should include:
- `main.tf` - Main resources
- `variables.tf` - Input variables
- `outputs.tf` - Output values
- `README.md` - Module documentation
