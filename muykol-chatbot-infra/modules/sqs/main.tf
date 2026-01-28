# SQS Queues for Faith Motivator Chatbot
# Handles asynchronous prayer request processing

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# KMS Key for SQS encryption
resource "aws_kms_key" "sqs" {
  description             = "KMS key for SQS encryption"
  deletion_window_in_days = 7

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow SQS service"
        Effect = "Allow"
        Principal = {
          Service = "sqs.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-sqs-key"
  }
}

resource "aws_kms_alias" "sqs" {
  name          = "alias/${var.project_name}-sqs"
  target_key_id = aws_kms_key.sqs.key_id
}

# Dead Letter Queue for Prayer Requests
resource "aws_sqs_queue" "prayer_requests_dlq" {
  name = "${var.project_name}-PrayerRequests-DLQ"

  # Message retention
  message_retention_seconds = 1209600 # 14 days

  # KMS encryption
  kms_master_key_id                 = aws_kms_key.sqs.key_id
  kms_data_key_reuse_period_seconds = 300

  tags = {
    Name = "${var.project_name}-prayer-requests-dlq"
  }
}

# Main Prayer Requests Queue
resource "aws_sqs_queue" "prayer_requests" {
  name = "${var.project_name}-PrayerRequests"

  # Message settings
  visibility_timeout_seconds = 300     # 5 minutes
  message_retention_seconds  = 1209600 # 14 days
  max_message_size           = 262144  # 256 KB
  delay_seconds              = 0

  # Long polling
  receive_wait_time_seconds = 20

  # Dead letter queue configuration
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.prayer_requests_dlq.arn
    maxReceiveCount     = 3
  })

  # KMS encryption
  kms_master_key_id                 = aws_kms_key.sqs.key_id
  kms_data_key_reuse_period_seconds = 300

  tags = {
    Name = "${var.project_name}-prayer-requests"
  }
}

# Queue Policy for ECS tasks to send messages
resource "aws_sqs_queue_policy" "prayer_requests_policy" {
  queue_url = aws_sqs_queue.prayer_requests.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowECSTasksToSendMessages"
        Effect = "Allow"
        Principal = {
          AWS = var.ecs_task_role_arn
        }
        Action = [
          "sqs:SendMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = aws_sqs_queue.prayer_requests.arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      },
      {
        Sid    = "AllowLambdaToReceiveMessages"
        Effect = "Allow"
        Principal = {
          AWS = var.lambda_execution_role_arn
        }
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = aws_sqs_queue.prayer_requests.arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}

# CloudWatch Alarms for SQS monitoring
resource "aws_cloudwatch_metric_alarm" "prayer_requests_queue_depth" {
  alarm_name          = "${var.project_name}-prayer-requests-queue-depth"
  alarm_description   = "Prayer requests queue depth is high"
  metric_name         = "ApproximateNumberOfVisibleMessages"
  namespace           = "AWS/SQS"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = 100
  comparison_operator = "GreaterThanThreshold"

  dimensions = {
    QueueName = aws_sqs_queue.prayer_requests.name
  }

  alarm_actions = [aws_sns_topic.sqs_alerts.arn]

  tags = {
    Name = "${var.project_name}-prayer-requests-queue-depth-alarm"
  }
}

resource "aws_cloudwatch_metric_alarm" "prayer_requests_dlq_messages" {
  alarm_name          = "${var.project_name}-prayer-requests-dlq-messages"
  alarm_description   = "Messages in prayer requests DLQ"
  metric_name         = "ApproximateNumberOfVisibleMessages"
  namespace           = "AWS/SQS"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"

  dimensions = {
    QueueName = aws_sqs_queue.prayer_requests_dlq.name
  }

  alarm_actions = [aws_sns_topic.sqs_alerts.arn]

  tags = {
    Name = "${var.project_name}-prayer-requests-dlq-alarm"
  }
}

# SNS Topic for SQS alerts
resource "aws_sns_topic" "sqs_alerts" {
  name = "${var.project_name}-sqs-alerts"

  tags = {
    Name = "${var.project_name}-sqs-alerts"
  }
}