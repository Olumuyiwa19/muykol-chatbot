# DynamoDB Tables for Faith Motivator Chatbot
# Designed for scalability and cost-effectiveness

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# KMS Key for DynamoDB encryption
resource "aws_kms_key" "dynamodb" {
  description             = "KMS key for DynamoDB encryption"
  deletion_window_in_days = 7

  tags = {
    Name = "${var.project_name}-dynamodb-key"
  }
}

resource "aws_kms_alias" "dynamodb" {
  name          = "alias/${var.project_name}-dynamodb"
  target_key_id = aws_kms_key.dynamodb.key_id
}

# UserProfile Table
resource "aws_dynamodb_table" "user_profiles" {
  name         = "${var.project_name}-UserProfiles"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "user_id"

  attribute {
    name = "user_id"
    type = "S"
  }

  attribute {
    name = "email"
    type = "S"
  }

  # Global Secondary Index for email lookup
  global_secondary_index {
    name            = "EmailIndex"
    hash_key        = "email"
    projection_type = "ALL"
  }

  # Enable point-in-time recovery
  point_in_time_recovery {
    enabled = true
  }

  # Server-side encryption
  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.dynamodb.arn
  }

  tags = {
    Name = "${var.project_name}-user-profiles"
  }
}

# ConversationSession Table
resource "aws_dynamodb_table" "conversation_sessions" {
  name         = "${var.project_name}-ConversationSessions"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "session_id"

  attribute {
    name = "session_id"
    type = "S"
  }

  attribute {
    name = "user_id"
    type = "S"
  }

  attribute {
    name = "created_at"
    type = "S"
  }

  # Global Secondary Index for user conversation lookup
  global_secondary_index {
    name            = "UserIndex"
    hash_key        = "user_id"
    range_key       = "created_at"
    projection_type = "ALL"
  }

  # TTL for automatic cleanup after 30 days
  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  # Enable point-in-time recovery
  point_in_time_recovery {
    enabled = true
  }

  # Server-side encryption
  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.dynamodb.arn
  }

  tags = {
    Name = "${var.project_name}-conversation-sessions"
  }
}

# PrayerRequest Table
resource "aws_dynamodb_table" "prayer_requests" {
  name         = "${var.project_name}-PrayerRequests"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "request_id"

  attribute {
    name = "request_id"
    type = "S"
  }

  attribute {
    name = "user_id"
    type = "S"
  }

  attribute {
    name = "status"
    type = "S"
  }

  attribute {
    name = "created_at"
    type = "S"
  }

  # Global Secondary Index for user prayer requests
  global_secondary_index {
    name            = "UserIndex"
    hash_key        = "user_id"
    range_key       = "created_at"
    projection_type = "ALL"
  }

  # Global Secondary Index for status tracking
  global_secondary_index {
    name            = "StatusIndex"
    hash_key        = "status"
    range_key       = "created_at"
    projection_type = "ALL"
  }

  # Enable point-in-time recovery
  point_in_time_recovery {
    enabled = true
  }

  # Server-side encryption
  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.dynamodb.arn
  }

  tags = {
    Name = "${var.project_name}-prayer-requests"
  }
}

# ConsentLog Table
resource "aws_dynamodb_table" "consent_logs" {
  name         = "${var.project_name}-ConsentLogs"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "log_id"

  attribute {
    name = "log_id"
    type = "S"
  }

  attribute {
    name = "user_id"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "S"
  }

  # Global Secondary Index for user consent history
  global_secondary_index {
    name            = "UserIndex"
    hash_key        = "user_id"
    range_key       = "timestamp"
    projection_type = "ALL"
  }

  # Enable point-in-time recovery
  point_in_time_recovery {
    enabled = true
  }

  # Server-side encryption
  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.dynamodb.arn
  }

  tags = {
    Name = "${var.project_name}-consent-logs"
  }
}

# CloudWatch Alarms for DynamoDB
resource "aws_cloudwatch_metric_alarm" "user_profiles_throttle" {
  alarm_name          = "${var.project_name}-user-profiles-throttle"
  alarm_description   = "DynamoDB UserProfiles table throttling"
  metric_name         = "ThrottledRequests"
  namespace           = "AWS/DynamoDB"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 2
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"

  dimensions = {
    TableName = aws_dynamodb_table.user_profiles.name
  }

  alarm_actions = [aws_sns_topic.dynamodb_alerts.arn]

  tags = {
    Name = "${var.project_name}-user-profiles-throttle-alarm"
  }
}

# SNS Topic for DynamoDB alerts
resource "aws_sns_topic" "dynamodb_alerts" {
  name = "${var.project_name}-dynamodb-alerts"

  tags = {
    Name = "${var.project_name}-dynamodb-alerts"
  }
}