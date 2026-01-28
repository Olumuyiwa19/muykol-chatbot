# Cognito Module Variables

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "cognito_domain" {
  description = "Custom domain for Cognito hosted UI"
  type        = string
  default     = "auth-faithchatbot"
}

variable "certificate_arn" {
  description = "ACM certificate ARN for custom domain"
  type        = string
  default     = null
}

variable "callback_urls" {
  description = "List of callback URLs for OAuth"
  type        = list(string)
  default = [
    "http://localhost:3000/auth/callback",
    "https://faithchatbot.com/auth/callback"
  ]
}

variable "logout_urls" {
  description = "List of logout URLs for OAuth"
  type        = list(string)
  default = [
    "http://localhost:3000/",
    "https://faithchatbot.com/"
  ]
}