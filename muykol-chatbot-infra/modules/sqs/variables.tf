# SQS Module Variables

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "ecs_task_role_arn" {
  description = "ARN of the ECS task role that can send messages"
  type        = string
}

variable "lambda_execution_role_arn" {
  description = "ARN of the Lambda execution role that can receive messages"
  type        = string
}