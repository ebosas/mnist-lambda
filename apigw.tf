#-------------------------------------------------------------#
# Lambda Function
#-------------------------------------------------------------#

resource "null_resource" "lambda_build" {
  triggers = {
    # If binary removed
    binary_exists = fileexists("${path.module}/build/mnist")

    # If go files change
    go_files = join("", [
      for file in fileset("${path.module}/mnist", "*.go") : filebase64sha256("${path.module}/mnist/${file}")
    ])
  }

  provisioner "local-exec" {
    command = "GOOS=linux go build -ldflags '-s -w' -o ${path.module}/build/mnist ${path.module}/mnist/"
  }
}

data "archive_file" "lambda_mnist" {
  depends_on = [null_resource.lambda_build]

  type = "zip"

  source_file = "${path.module}/build/mnist"
  output_path = "${path.module}/build/mnist.zip"
}

resource "aws_lambda_function" "mnist" {
  function_name    = "MNIST"
  filename         = data.archive_file.lambda_mnist.output_path
  source_code_hash = data.archive_file.lambda_mnist.output_base64sha256
  role             = aws_iam_role.lambda_exec.arn
  runtime          = "go1.x"
  handler          = "mnist"
  memory_size      = 128
  timeout          = 10
}

resource "aws_cloudwatch_log_group" "mnist" {
  name = "/aws/lambda/${aws_lambda_function.mnist.function_name}"

  retention_in_days = 14
}

resource "aws_iam_role" "lambda_exec" {
  name = "serverless_lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Sid    = ""
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

#-------------------------------------------------------------#
# API Gateway
#-------------------------------------------------------------#

resource "aws_apigatewayv2_api" "lambda" {
  name          = "serverless_lambda_gw"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "lambda" {
  api_id = aws_apigatewayv2_api.lambda.id

  name        = "prod"
  auto_deploy = true

  default_route_settings {
    throttling_burst_limit = 100
    throttling_rate_limit  = 200
  }

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gw.arn

    format = jsonencode({
      requestId               = "$context.requestId"
      sourceIp                = "$context.identity.sourceIp"
      requestTime             = "$context.requestTime"
      protocol                = "$context.protocol"
      httpMethod              = "$context.httpMethod"
      resourcePath            = "$context.resourcePath"
      routeKey                = "$context.routeKey"
      status                  = "$context.status"
      responseLength          = "$context.responseLength"
      integrationErrorMessage = "$context.integrationErrorMessage"
      }
    )
  }
}

resource "aws_apigatewayv2_integration" "mnist" {
  api_id = aws_apigatewayv2_api.lambda.id

  integration_uri    = aws_lambda_function.mnist.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

resource "aws_apigatewayv2_route" "mnist" {
  api_id = aws_apigatewayv2_api.lambda.id

  route_key = "POST /api/mnist"
  target    = "integrations/${aws_apigatewayv2_integration.mnist.id}"
}

resource "aws_cloudwatch_log_group" "api_gw" {
  name = "/aws/api_gw/${aws_apigatewayv2_api.lambda.name}"

  retention_in_days = 14
}

resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.mnist.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.lambda.execution_arn}/*/*"
}
