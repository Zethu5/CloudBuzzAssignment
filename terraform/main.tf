provider "aws" {
  region = "eu-central-1"
}

####################
# create sns topic #
####################

variable "email_personal" {
  type = string
  description = "personal email"
}

variable "email_reviewer" {
  type = string
  description = "reviewer email"
}

resource "aws_sns_topic" "sum_two_nums_2" {
  name = "sum_two_nums_2"
}

resource "aws_sns_topic_subscription" "email_subscription" {
  topic_arn = aws_sns_topic.sum_two_nums_2.arn
  protocol  = "email"
  endpoint  = var.email_personal
}

resource "aws_sns_topic_policy" "sns_policy" {
  arn    = aws_sns_topic.sum_two_nums_2.arn
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowSNSPublish",
      "Effect": "Allow",
      "Principal": {
        "AWS": "*"
      },
      "Action": "sns:Publish",
      "Resource": "${aws_sns_topic.sum_two_nums_2.arn}"
    }
  ]
}
EOF
}

####################################
# create lambda to connecto to sns #
####################################

variable "sms_email_arn" {
  type = string
  description = "sms email arn"
}

resource "aws_lambda_function" "sum_two_nums_2" {
  function_name = "sum_two_nums_2"
  runtime = "python3.9"
  handler = "lambda_function.lambda_handler"
  role = aws_iam_role.lambda_role.arn
  timeout = 10

  filename         = "../lambda_function.zip"
  source_code_hash = filebase64sha256("../lambda_function.zip")

  environment {
    variables = {
      SNS_EMAIL_ARN = var.sms_email_arn
    }
  }
}

resource "aws_iam_role" "lambda_role" {
  name = "sum_two_num_lambda_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "lambda_policy" {
  name   = "lambda_policy"
  role   = aws_iam_role.lambda_role.id
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowPublishToSNS",
      "Effect": "Allow",
      "Action": "sns:Publish",
      "Resource": "${aws_sns_topic.sum_two_nums_2.arn}"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function_event_invoke_config" "sum_two_nums_2" {
  function_name = aws_lambda_function.sum_two_nums_2.function_name
  destination_config {
    on_success {
      destination = aws_sns_topic.sum_two_nums_2.arn
    }
  }
}

resource "aws_iam_role_policy_attachment" "lambda_sns_publish_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSNSFullAccess"
}

###################################################
# create http api gateway and make lambda trigger #
###################################################

resource "aws_apigatewayv2_api" "api_sum_two_nums2" {
  name          = "api_sum_two_nums2"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_route" "sums_two_nums2_post_route" {
  api_id    = aws_apigatewayv2_api.api_sum_two_nums2.id
  route_key = "POST /sum_two_nums"

  target = "integrations/${aws_apigatewayv2_integration.integration.id}"
}

resource "aws_apigatewayv2_integration" "integration" {
  api_id             = aws_apigatewayv2_api.api_sum_two_nums2.id
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
  integration_uri    = aws_lambda_function.sum_two_nums_2.invoke_arn
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.api_sum_two_nums2.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "api_sum_two_nums2_permission" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.sum_two_nums_2.function_name
  principal     = "apigateway.amazonaws.com"

   source_arn = "${aws_apigatewayv2_api.api_sum_two_nums2.execution_arn}/*"
}