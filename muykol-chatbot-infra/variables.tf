variable "aws_region" {
  description = "AWS region for resources"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
}

variable "availability_zones" {
  description = "Availability zones for multi-AZ deployment"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnets"
  type        = bool
}

variable "enable_vpn_gateway" {
  description = "Enable VPN Gateway"
  type        = bool
}

variable "cognito_domain" {
  description = "Custom domain for Cognito hosted UI"
  type        = string
}

variable "certificate_arn" {
  description = "ACM certificate ARN for custom domain"
  type        = string
  default     = null
}

variable "callback_urls" {
  description = "List of callback URLs for OAuth"
  type        = list(string)
}

variable "logout_urls" {
  description = "List of logout URLs for OAuth"
  type        = list(string)
}
