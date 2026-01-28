# SQS Module Outputs

output "prayer_requests_queue_url" {
  description = "URL of the prayer requests queue"
  value       = aws_sqs_queue.prayer_requests.id
}

output "prayer_requests_queue_arn" {
  description = "ARN of the prayer requests queue"
  value       = aws_sqs_queue.prayer_requests.arn
}

output "prayer_requests_queue_name" {
  description = "Name of the prayer requests queue"
  value       = aws_sqs_queue.prayer_requests.name
}

output "prayer_requests_dlq_url" {
  description = "URL of the prayer requests dead letter queue"
  value       = aws_sqs_queue.prayer_requests_dlq.id
}

output "prayer_requests_dlq_arn" {
  description = "ARN of the prayer requests dead letter queue"
  value       = aws_sqs_queue.prayer_requests_dlq.arn
}

output "prayer_requests_dlq_name" {
  description = "Name of the prayer requests dead letter queue"
  value       = aws_sqs_queue.prayer_requests_dlq.name
}

output "sqs_kms_key_id" {
  description = "ID of the KMS key used for SQS encryption"
  value       = aws_kms_key.sqs.key_id
}

output "sqs_kms_key_arn" {
  description = "ARN of the KMS key used for SQS encryption"
  value       = aws_kms_key.sqs.arn
}

output "sqs_alerts_topic_arn" {
  description = "ARN of the SNS topic for SQS alerts"
  value       = aws_sns_topic.sqs_alerts.arn
}