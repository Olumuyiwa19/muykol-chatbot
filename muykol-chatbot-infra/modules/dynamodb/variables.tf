# DynamoDB Module Variables

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "ecs_task_role_arn" {
  description = "ARN of the ECS task role that needs access to DynamoDB"
  type        = string
}