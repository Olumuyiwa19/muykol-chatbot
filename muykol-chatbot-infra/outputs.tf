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

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.ecs.cluster_name
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = module.alb.dns_name
}

output "dynamodb_table_names" {
  description = "Names of DynamoDB tables"
  value = {
    user_profiles      = module.dynamodb.user_profiles_table_name
    conversation_sessions = module.dynamodb.conversation_sessions_table_name
    prayer_requests    = module.dynamodb.prayer_requests_table_name
  }
}
