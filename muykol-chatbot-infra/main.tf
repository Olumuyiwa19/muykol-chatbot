# Terraform Cloud Configuration for muykol-chatbot

terraform {
  required_version = ">= 1.0"

  cloud {
    organization = "Kolayemi-org"

    workspaces {
      name = "muykol-chatbot-dev" # Will be overridden by workspace selection
    }
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# AWS Provider configuration
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "muykol-chatbot"
      Environment = var.environment
      ManagedBy   = "terraform-cloud"
    }
  }
}

# VPC Module
module "vpc" {
  source = "./modules/vpc"

  project_name         = var.project_name
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  enable_nat_gateway   = var.enable_nat_gateway
  enable_vpn_gateway   = var.enable_vpn_gateway
}

# IAM Module
module "iam" {
  source = "./modules/iam"

  project_name           = var.project_name
  github_repository      = var.github_repository
  terraform_state_bucket = var.terraform_state_bucket
}

# Cognito Module
module "cognito" {
  source = "./modules/cognito"

  project_name    = var.project_name
  cognito_domain  = var.cognito_domain
  certificate_arn = var.certificate_arn
  callback_urls   = var.callback_urls
  logout_urls     = var.logout_urls
}

# DynamoDB Module
module "dynamodb" {
  source = "./modules/dynamodb"

  project_name = var.project_name
}

# SQS Module
module "sqs" {
  source = "./modules/sqs"

  project_name              = var.project_name
  ecs_task_role_arn         = module.iam.ecs_task_role_arn
  lambda_execution_role_arn = module.iam.lambda_execution_role_arn
}
