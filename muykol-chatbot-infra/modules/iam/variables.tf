# IAM Module Variables

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "github_repository" {
  description = "GitHub repository in format 'owner/repo'"
  type        = string
  default     = "YOUR_ORG/faith-motivator-chatbot"
}

variable "terraform_state_bucket" {
  description = "S3 bucket for Terraform state"
  type        = string
  default     = "muykol-chatbot-terraform-state"
}