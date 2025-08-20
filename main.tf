terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# ────────────────────────────────
# Create S3 Bucket (for logs)
# ────────────────────────────────
resource "aws_s3_bucket" "logs_bucket" {
  bucket        = var.bucket_name
  force_destroy = true # allow terraform destroy even if bucket has objects

  tags = {
    Name = "S3 Logs Bucket"
  }
}

# ────────────────────────────────
# Package Lambda Code (Python script zipped)
# ────────────────────────────────
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/cleanup.py"
  output_path = "${path.module}/lambda/cleanup.zip"
}

# ────────────────────────────────
# IAM Role for Lambda
# ────────────────────────────────
resource "aws_iam_role" "lambda_role" {
  name = "s3-cleanup-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# ────────────────────────────────
# IAM Policy: Allow Lambda to delete S3 objects + write logs
# ────────────────────────────────
resource "aws_iam_role_policy" "lambda_policy" {
  name = "s3-cleanup-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetObject",
          "s3:DeleteObject"
        ]
        Resource = [
          aws_s3_bucket.logs_bucket.arn,
          "${aws_s3_bucket.logs_bucket.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

# ────────────────────────────────
# Lambda Function
# ────────────────────────────────
resource "aws_lambda_function" "s3_cleanup" {
  function_name = "s3-cleanup-function"
  handler       = "cleanup.lambda_handler"
  runtime       = "python3.9"
  role          = aws_iam_role.lambda_role.arn
  filename      = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      BUCKET_NAME       = aws_s3_bucket.logs_bucket.bucket
      RETENTION_DAYS    = var.retention_days
      MIN_FILE_SIZE_KB  = var.min_file_size_kb
    }
  }

  depends_on = [aws_s3_bucket.logs_bucket]
}

# ────────────────────────────────
# EventBridge Schedule (Daily at 00:00 UTC)
# ────────────────────────────────
resource "aws_cloudwatch_event_rule" "daily_schedule" {
  name                = "s3-cleanup-daily"
  description         = "Run daily to clean up old S3 logs"
  schedule_expression = "cron(0 0 * * ? *)" # every day at midnight UTC
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.daily_schedule.name
  target_id = "s3-cleanup"
  arn       = aws_lambda_function.s3_cleanup.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.s3_cleanup.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_schedule.arn
}
