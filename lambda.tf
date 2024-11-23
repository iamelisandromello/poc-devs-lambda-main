## PROVIDES ##
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.5.0"
    }
  }
}
# configure Provider
provider "aws" {
  region = var.region
}

## VARIABLES ##
variable "project_name" {}
variable "region" { default = "us-east-1" }
variable "security_groups" { default = ["sg-0f9bc85367b78c588"] }
variable "subnet_ids" {
  type    = list(string)
  default = ["subnet-012c98d53fbceda0c", "subnet-0dad44b83545d52dc"]
}

## LOCAL VALUES ##
locals {
  tags = {
    Project     = title(var.project_name)
    Managed-by  = "terraform"
    Service     = "api"
    Tier        = "back-end"
    Environment = "develop"
  }
}

## TERRAFORM BACKEND ##
terraform {
  backend "s3" {  #--> o bucket S3 será informado no gitlab-ci.yml 
  }
}

## IAM RESOURCES ##
# Allows another service like EventBridge and etc. access the Lambda function
resource "aws_iam_role" "lambda_role" {
  name = "lambda-pocdevs"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })
}

# create a policy allow access the lambda to services: S3|SQS
resource "aws_iam_policy" "lambda_policy" {
  name = "policy-lambda-pocdevs-dev"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowAccessServices"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:SendMessage"
        ]
        Resource = [
          "arn:aws:s3:::*",
          "arn:aws:sqs:${var.region}:${data.aws_caller_identity.current.id}:*"
        ]
      },
    ]
  })
}

# appends an AWS managed policy in the lambda function
resource "aws_iam_role_policy_attachment" "policy_attach-VPC" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}
# policy with log permission in cloudwatch
resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name              = "pocdevs-dev"
  retention_in_days = "60"
}

## LAMBDA RESOURCES ##
# provides a Lambda Function resource
resource "aws_lambda_function" "lambda_function" {
  function_name    = "lambda-pocdevs"
  role             = aws_iam_role.lambda_role.arn
  handler          = "index.handler"
  runtime          = "nodejs14.x"
  architectures    = ["x86_64"]
  memory_size      = 128
  timeout          = 5
  publish          = true
  filename         = data.archive_file.lambda_file.output_path
  source_code_hash = data.archive_file.lambda_file.output_base64sha256
  layers           = [aws_lambda_layer_version.layer.arn]
  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = var.security_groups
  }
  environment {
    variables = {
      env = "dev"
    }
  }
  tags = local.tags
}
# provides the files and code for the Lambda function
data "archive_file" "lambda_file" {
  source_dir  = "./src"
  type        = "zip"
  output_path = "files/lambda-code.zip"
}

## LAMBDA LAYERS ##
# provides .zip file with dependencies for the Lambda layer
resource "aws_lambda_layer_version" "layer" {
  layer_name          = "layer-pocdevs"
  description         = "node_modules content for project lambda"
  filename            = data.archive_file.layer_file.output_path
  source_code_hash    = data.archive_file.layer_file.output_base64sha256
  compatible_runtimes = ["nodejs14.x"]
}
# provides the files and code for the Lambda layer
data "archive_file" "layer_file" {
  source_dir  = "./layers"
  type        = "zip"
  output_path = "files/layers-pocdevs.zip"
}

## DATA SOURCES ##
data "aws_caller_identity" "current" {}

## OUTPUTS ##
output "lambda_function" {
  value = aws_lambda_function.lambda_function.function_name
}
output "lambda_layer" {
  value = aws_lambda_layer_version.layer.layer_name
}
