# DynamoDB Module Outputs

output "user_profiles_table_name" {
  description = "Name of the UserProfiles table"
  value       = aws_dynamodb_table.user_profiles.name
}

output "user_profiles_table_arn" {
  description = "ARN of the UserProfiles table"
  value       = aws_dynamodb_table.user_profiles.arn
}

output "conversation_sessions_table_name" {
  description = "Name of the ConversationSessions table"
  value       = aws_dynamodb_table.conversation_sessions.name
}

output "conversation_sessions_table_arn" {
  description = "ARN of the ConversationSessions table"
  value       = aws_dynamodb_table.conversation_sessions.arn
}

output "prayer_requests_table_name" {
  description = "Name of the PrayerRequests table"
  value       = aws_dynamodb_table.prayer_requests.name
}

output "prayer_requests_table_arn" {
  description = "ARN of the PrayerRequests table"
  value       = aws_dynamodb_table.prayer_requests.arn
}

output "consent_logs_table_name" {
  description = "Name of the ConsentLogs table"
  value       = aws_dynamodb_table.consent_logs.name
}

output "consent_logs_table_arn" {
  description = "ARN of the ConsentLogs table"
  value       = aws_dynamodb_table.consent_logs.arn
}

output "dynamodb_kms_key_id" {
  description = "ID of the KMS key used for DynamoDB encryption"
  value       = aws_kms_key.dynamodb.key_id
}

output "dynamodb_kms_key_arn" {
  description = "ARN of the KMS key used for DynamoDB encryption"
  value       = aws_kms_key.dynamodb.arn
}

output "dynamodb_alerts_topic_arn" {
  description = "ARN of the SNS topic for DynamoDB alerts"
  value       = aws_sns_topic.dynamodb_alerts.arn
}