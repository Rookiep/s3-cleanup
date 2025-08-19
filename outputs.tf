output "lambda_function_name" {
  value = aws_lambda_function.s3_cleanup.function_name
}

output "event_rule_name" {
  value = aws_cloudwatch_event_rule.daily_schedule.name
}
