# VPC Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.vpc.public_subnet_ids
}

output "alb_security_group_id" {
  description = "ID of the ALB security group"
  value       = module.vpc.alb_security_group_id
}

output "ecs_tasks_security_group_id" {
  description = "ID of the ECS tasks security group"
  value       = module.vpc.ecs_tasks_security_group_id
}

# IAM Outputs
output "ecs_task_execution_role_arn" {
  description = "ARN of the ECS task execution role"
  value       = module.iam.ecs_task_execution_role_arn
}

output "ecs_task_role_arn" {
  description = "ARN of the ECS task role"
  value       = module.iam.ecs_task_role_arn
}

output "github_actions_infrastructure_role_arn" {
  description = "ARN of the GitHub Actions infrastructure role"
  value       = module.iam.github_actions_infrastructure_role_arn
}

output "github_actions_deployment_role_arn" {
  description = "ARN of the GitHub Actions deployment role"
  value       = module.iam.github_actions_deployment_role_arn
}

# Cognito Outputs
output "cognito_user_pool_id" {
  description = "ID of the Cognito User Pool"
  value       = module.cognito.user_pool_id
}

output "cognito_user_pool_client_id" {
  description = "ID of the Cognito User Pool Client"
  value       = module.cognito.user_pool_client_id
}

output "cognito_hosted_ui_url" {
  description = "Hosted UI URL for the Cognito User Pool"
  value       = module.cognito.user_pool_hosted_ui_url
}

output "cognito_jwks_url" {
  description = "JWKS URL for token validation"
  value       = module.cognito.user_pool_jwks_url
}

# DynamoDB Outputs
output "dynamodb_table_names" {
  description = "Names of DynamoDB tables"
  value = {
    user_profiles         = module.dynamodb.user_profiles_table_name
    conversation_sessions = module.dynamodb.conversation_sessions_table_name
    prayer_requests       = module.dynamodb.prayer_requests_table_name
    consent_logs          = module.dynamodb.consent_logs_table_name
  }
}

# SQS Outputs
output "sqs_queue_urls" {
  description = "URLs of SQS queues"
  value = {
    prayer_requests     = module.sqs.prayer_requests_queue_url
    prayer_requests_dlq = module.sqs.prayer_requests_dlq_url
  }
}

# Core infrastructure modules will be added during implementation
# For now, commenting out module references

# output "ecs_cluster_name" {
#   description = "Name of the ECS cluster"
#   value       = module.ecs.cluster_name
# }

# output "alb_dns_name" {
#   description = "DNS name of the Application Load Balancer"
#   value       = module.alb.dns_name
# }

# output "dynamodb_table_names" {
#   description = "Names of DynamoDB tables"
#   value = {
#     user_profiles      = module.dynamodb.user_profiles_table_name
#     conversation_sessions = module.dynamodb.conversation_sessions_table_name
#     prayer_requests    = module.dynamodb.prayer_requests_table_name
#   }
# }
