output "rest_api_arn" {
  description = "The Amazon Resource Name (ARN) of the AWS API Gateway REST API."
  value       = aws_api_gateway_rest_api.main.arn
}

output "rest_api_id" {
  description = "The ID of the AWS API Gateway REST API."
  value       = aws_api_gateway_rest_api.main.id
}
