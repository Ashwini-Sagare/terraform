output "SNSarn" {
  description = "SNS alerting topics"
  value = aws_sns_topic.ec2_stop_notification.arn
}