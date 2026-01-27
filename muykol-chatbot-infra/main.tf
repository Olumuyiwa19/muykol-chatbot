# Terraform Cloud Configuration for muykol-chatbot

terraform {
  required_version = ">= 1.0"
  
  cloud {
    organization = "Kolayemi-org"  # Updated to actual org name
    
    workspaces {
      tags = ["muykol-chatbot", "aws"]
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
