terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws",
      version = "~> 3.27"
    }
  }
  # backend "s3" {
  #   region  = "ap-southeast-1"
  #   profile = "srvadm"
  #   bucket = "tf_demo_bucket"
  # }
}

provider "aws" {
  profile = "srvadm"
  region  = "ap-southeast-1"
}

data "archive_file" "rf_demo_lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/src/app.py"
  output_path = "${path.module}/lambda.zip"
}

#dynamodb

resource "aws_dynamodb_table" "tf_demo_hello_table" {
  name           = "tf_demo_hello_table"
  hash_key       = "id"
  read_capacity  = 1
  write_capacity = 1

  attribute {
    name = "id"
    type = "S"
  }
}

# role for lambda exec & dynamodb crud

resource "aws_iam_role" "tf_demo_lambda_exec" {
  name = "tf_demo_lambda_role"
  assume_role_policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Action" : "sts:AssumeRole",
          "Principal" : {
            "Service" : "lambda.amazonaws.com"
          },
          "Effect" : "Allow",
          "Sid" : ""
        }
      ]
    }
  )
  inline_policy {
    name = "tf_demo_dynamodb_crud"
    policy = jsonencode({
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Action" : [
            "dynamodb:GetItem",
            "dynamodb:DeleteItem",
            "dynamodb:PutItem",
            "dynamodb:Scan",
            "dynamodb:Query",
            "dynamodb:UpdateItem",
            "dynamodb:BatchWriteItem",
            "dynamodb:BatchGetItem",
            "dynamodb:DescribeTable",
            "dynamodb:ConditionCheckItem"
          ],
          "Resource" : [
            "${aws_dynamodb_table.tf_demo_hello_table.arn}"
          ],
          "Effect" : "Allow"
        }
      ]
    })
  }
}


#lambda function

resource "aws_lambda_function" "tf_demo_function" {
  function_name    = "tf_demo_function"
  filename         = data.archive_file.rf_demo_lambda_zip.output_path
  source_code_hash = filebase64sha256(data.archive_file.rf_demo_lambda_zip.output_path)
  handler          = "app.lambda_handler"
  runtime          = "python3.8"
  role             = aws_iam_role.tf_demo_lambda_exec.arn
}

resource "aws_lambda_permission" "tf_demo_api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.tf_demo_function.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.tf_demo_api.execution_arn}/*/*"
}


#api gateway proxy & rest api

resource "aws_api_gateway_rest_api" "tf_demo_api" {
  name        = "tf_demo_api"
  description = "Terraform serverless demo api gateway"
}

resource "aws_api_gateway_resource" "tf_demo_proxy" {
  rest_api_id = aws_api_gateway_rest_api.tf_demo_api.id
  parent_id   = aws_api_gateway_rest_api.tf_demo_api.root_resource_id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "tf_demo_proxy" {
  resource_id   = aws_api_gateway_resource.tf_demo_proxy.id
  rest_api_id   = aws_api_gateway_rest_api.tf_demo_api.id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda" {
  rest_api_id = aws_api_gateway_rest_api.tf_demo_api.id
  resource_id = aws_api_gateway_method.tf_demo_proxy.resource_id
  http_method = aws_api_gateway_method.tf_demo_proxy.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.tf_demo_function.invoke_arn
}

resource "aws_api_gateway_method" "tf_demo_proxy_root" {
  rest_api_id   = aws_api_gateway_rest_api.tf_demo_api.id
  resource_id   = aws_api_gateway_rest_api.tf_demo_api.root_resource_id
  http_method   = "ANY"
  authorization = "NONE"
}


resource "aws_api_gateway_integration" "lambda_root" {
  rest_api_id = aws_api_gateway_rest_api.tf_demo_api.id
  resource_id = aws_api_gateway_rest_api.tf_demo_api.root_resource_id
  http_method = aws_api_gateway_method.tf_demo_proxy_root.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.tf_demo_function.invoke_arn
}

resource "aws_api_gateway_deployment" "tf_demo_api_deploy" {
  depends_on = [
    aws_api_gateway_integration.lambda,
    aws_api_gateway_integration.lambda_root
  ]
  rest_api_id = aws_api_gateway_rest_api.tf_demo_api.id
  stage_name  = "test"
}


#output
output "lambda_function_name" {
  value = aws_lambda_function.tf_demo_function.function_name
}

output "dynamodb_name" {
  value = aws_dynamodb_table.tf_demo_hello_table.name
}

output "api_url" {
  value = aws_api_gateway_deployment.tf_demo_api_deploy.invoke_url
}
