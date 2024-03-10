provider "aws" {
  region = "us-east-1"
  
}
# IAM User and Access Key Creation
resource "aws_iam_user" "terraform_user" {
  name = "terraform-user"
}

resource "aws_iam_access_key" "terraform_access_key" {
  user = aws_iam_user.terraform_user.name
}

#attach administratorAcces policy to IAM user
resource "aws_iam_user_policy_attachment" "admin_attachment" {
  user       = aws_iam_user.terraform_user.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# EC2 Instance Creation
module "ec2_instance" {
  source = "./module/ec2"
  count_value = 2
  ami_value = "ami-0f9c44e98edf38a2b"
  instance_type_value = "t2.micro"
}

# IAM Role for Lambda Execution
resource "aws_iam_role" "lambda_role" {
  name = "stopec2"
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }]
  })
  tags = {
    tag-key = "lambda-stopec2"
  }
}

# IAM Policy for Lambda Execution
resource "aws_iam_policy" "lambda_policy" {
  name        = "STOPEC2"
  description = "Policy for Lambda to stop EC2 instances and send SNS notification"
  
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Action": [
        "ec2:StopInstances",
        "sns:Publish",
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "*"
    }]
  })
}

# Attach Policy to Role
resource "aws_iam_role_policy_attachment" "lambda_policy_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# Lambda Function
resource "aws_lambda_function" "stop_ec2_lambda" {
  filename      = "lambda.zip"  # Path to your Lambda function code
  function_name = "StopEC2Instances"
  handler       = "lambda.lambda_handler"
  runtime       = "python3.8"
  timeout       = 900
  role          = aws_iam_role.lambda_role.arn
  source_code_hash = filebase64sha256("lambda.zip")
}

# Trigger for Lambda Function
resource "aws_cloudwatch_event_rule" "trigger_lambda_rule" {
  name        = "TriggerLambdaOnSchedule"
  description = "Trigger Lambda function to stop EC2 instances"
  schedule_expression = "cron(5 18 4 3 ? *)"  
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.trigger_lambda_rule.name
  target_id = "lambda"
  arn       = aws_lambda_function.stop_ec2_lambda.arn
}

# SNS Topic
resource "aws_sns_topic" "ec2_stop_notification" {
  name = "EC2_Stop_Notification"
}

#SNS Subscription
resource "aws_sns_topic_subscription" "snssubscription" {
  topic_arn = aws_sns_topic.ec2_stop_notification.arn
  protocol = "email"
  endpoint = "sagare.ashu18@gmail.com"
}

resource "aws_sns_topic_subscription" "snssubscription_lambda" {
  topic_arn = aws_sns_topic.ec2_stop_notification.arn
  protocol = "lambda"
  endpoint = aws_lambda_function.stop_ec2_lambda.arn
}

# Lambda Permission to Execute from CloudWatch Events
resource "aws_lambda_permission" "cloudwatch_permission" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.stop_ec2_lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.trigger_lambda_rule.arn
}

# Lambda Permission to Publish SNS
resource "aws_lambda_permission" "sns_publish_permission" {
  statement_id  = "AllowExecutionToSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.stop_ec2_lambda.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.ec2_stop_notification.arn
}

# Deletion of EC2 Instances
resource "null_resource" "delete_ec2_instances" {
  depends_on = [aws_sns_topic.ec2_stop_notification]
  count = length(module.ec2_instance.instance_ids)

  provisioner "local-exec" {
    command = "aws ec2 terminate-instances --instance-ids ${join(" ", module.ec2_instance.instance_ids[*])}"
  }
}
