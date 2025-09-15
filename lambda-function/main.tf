provider "aws" {
  region = "us-east-1"
}

# IAM Role for Lambda Function
resource "aws_iam_role" "lambda_role" {
  name = "lambda_role"

  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role_policy.json
}

data "aws_iam_policy_document" "lambda_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# IAM Policy for Lambda Function
resource "aws_iam_role_policy" "lambda_policy" {
  name = "lambda_policy"
  role = aws_iam_role.lambda_role.id

  policy = data.aws_iam_policy_document.lambda_policy.json
}

data "aws_iam_policy_document" "lambda_policy" {
  statement {
    actions = [
      "dynamodb:PutItem",
      "dynamodb:Query",
      "dynamodb:Scan",
      "dynamodb:GetItem",
    ]

    resources = [
      aws_dynamodb_table.playlist.arn,
      "${aws_dynamodb_table.playlist.arn}/index/*",
    ]
  }
}

# Attach AWSLambdaBasicExecutionRole Policy
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Package Lambda Function
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "lambda_function.py"
  output_path = "lambda_function_payload.zip"
}

# Lambda Function
resource "aws_lambda_function" "playlist_handler" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "playlist_handler"
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda_function.lambda_handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime          = "python3.12"

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.playlist.name
    }
  }
}

# API Gateway REST API
resource "aws_api_gateway_rest_api" "playlist_api" {
  name = "playlist_api"
}

data "aws_api_gateway_resource" "root_resource" {
  rest_api_id = aws_api_gateway_rest_api.playlist_api.id
  path        = "/"
}

# GET Method
resource "aws_api_gateway_method" "get_method" {
  rest_api_id   = aws_api_gateway_rest_api.playlist_api.id
  resource_id   = data.aws_api_gateway_resource.root_resource.id
  http_method   = "GET"
  authorization = "NONE"
}

# POST Method
resource "aws_api_gateway_method" "post_method" {
  rest_api_id   = aws_api_gateway_rest_api.playlist_api.id
  resource_id   = data.aws_api_gateway_resource.root_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

# GET Integration
resource "aws_api_gateway_integration" "get_integration" {
  rest_api_id             = aws_api_gateway_rest_api.playlist_api.id
  resource_id             = data.aws_api_gateway_resource.root_resource.id
  http_method             = aws_api_gateway_method.get_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.playlist_handler.invoke_arn
}

# POST Integration
resource "aws_api_gateway_integration" "post_integration" {
  rest_api_id             = aws_api_gateway_rest_api.playlist_api.id
  resource_id             = data.aws_api_gateway_resource.root_resource.id
  http_method             = aws_api_gateway_method.post_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.playlist_handler.invoke_arn
}

# Lambda Permission for API Gateway
resource "aws_lambda_permission" "api_gateway_permission" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.playlist_handler.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.playlist_api.execution_arn}/*/*"
}

# API Deployment
resource "aws_api_gateway_deployment" "api_deployment" {
  depends_on = [
    aws_api_gateway_integration.get_integration,
    aws_api_gateway_integration.post_integration,
  ]

  rest_api_id = aws_api_gateway_rest_api.playlist_api.id
}

# API Stage
resource "aws_api_gateway_stage" "api_stage" {
  deployment_id = aws_api_gateway_deployment.api_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.playlist_api.id
  stage_name    = "prod"
}

# Output API Invoke URL
output "invoke_url" {
  value = "${aws_api_gateway_stage.api_stage.invoke_url}"
}
