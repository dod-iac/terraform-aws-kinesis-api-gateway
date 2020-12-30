/**
 * ## Usage
 *
 * Creates an AWS API Gateway REST API that proxies a AWS Kinesis stream.
 *
 * ```hcl
 * module "kinesis_api_gateway" {
 *   source = "dod-iac/kinesis-api-gateway/aws"
 *
 *   allow_describe_stream  = false
 *   allow_get_records = true
 *   allow_list_shards  = false
 *   allow_list_streams  = false
 *   allow_put_record = true
 *   allow_put_records = false
 *
 *   authorization       = "NONE"
 *   execution_role_name = format("api-%s-%s", var.application, var.environment)
 *   name                = format("api-%s-%s", var.application, var.environment)
 *   streams             = [module.aws_kinesis_stream.arn]
 *
 *   tags = {
 *     Application = var.application
 *     Environment = var.environment
 *     Automation  = "Terraform"
 *   }
 * }
 * ```
 *
 * The following API endpoints are conditionally created by the `allow_*` variables.
 *
 * ```text
 * allow_get_records => GET /records -H "ShardIterator: XYZ" -H "Limit: 123"
 * allow_list_shards => GET /shards?StreamName=XYZ&MaxResults=123
 * allow_list_shards => GET /shards?NextToken=XYZ&MaxResults=123
 * allow_list_streams => GET /streams
 * allow_describe_stream => GET /streams/{stream-name}
 * allow_put_record => PUT /streams/{stream-name}/record
 * allow_put_records => PUT /streams/{stream-name}/records
 * allow_get_records => GET /streams/{stream-name}/sharditerator?ShardId=XYZ&ShardIteratorType=XYZ&StartingSequenceNumber=XYZ&Timestamp=XYZ
 * ```
 *
 * Once the REST API is created, to avoid an inconsistent terraform state, manually deploy the REST by using the `deploy-api` script, e.g., `scripts/deploy-api us-west-2 api-hello-experimental experimental`.
 *
 * ## Terraform Version
 *
 * Terraform 0.12. Pin module version to ~> 1.0.0 . Submit pull-requests to master branch.
 *
 * Terraform 0.11 is not supported.
 *
 * ## License
 *
 * This project constitutes a work of the United States Government and is not subject to domestic copyright protection under 17 USC § 105.  However, because the project utilizes code licensed from contributors and other third parties, it therefore is licensed under the MIT License.  See LICENSE file for more information.
 */

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_partition" "current" {}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type = "Service"
      identifiers = [
        "apigateway.amazonaws.com"
      ]
    }
  }
}

resource "aws_iam_role" "execution_role" {
  name               = var.execution_role_name
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
  tags               = var.tags
}

data "aws_iam_policy_document" "execution_role" {

  statement {
    sid = "ListStreams"
    actions = [
      "kinesis:ListStreams"
    ]
    effect    = var.allow_list_streams ? "Allow" : "Deny"
    resources = ["*"]
  }

  statement {
    sid = "DescribeStreamSummary"
    actions = [
      "kinesis:DescribeStreamSummary",
    ]
    effect    = var.allow_describe_stream ? "Allow" : "Deny"
    resources = length(var.streams) > 0 && var.allow_describe_stream ? var.streams : ["*"]
  }

  statement {
    sid = "ListShards"
    actions = [
      "kinesis:ListShards",
    ]
    effect    = var.allow_list_shards ? "Allow" : "Deny"
    resources = length(var.streams) > 0 && var.allow_list_shards ? var.streams : ["*"]
  }

  statement {
    sid = "GetRecords"
    actions = [
      "kinesis:GetRecords",
      "kinesis:GetShardIterator",
    ]
    effect    = var.allow_get_records ? "Allow" : "Deny"
    resources = length(var.streams) > 0 && var.allow_get_records ? var.streams : ["*"]
  }

  statement {
    sid = "PutRecord"
    actions = [
      "kinesis:PutRecord",
    ]
    effect    = var.allow_put_record ? "Allow" : "Deny"
    resources = length(var.streams) > 0 && var.allow_put_record ? var.streams : ["*"]
  }

  statement {
    sid = "PutRecords"
    actions = [
      "kinesis:PutRecords"
    ]
    effect    = var.allow_put_records ? "Allow" : "Deny"
    resources = length(var.streams) > 0 && var.allow_put_records ? var.streams : ["*"]
  }
}

resource "aws_iam_policy" "execution_role" {
  name   = length(var.execution_role_policy_name) > 0 ? var.execution_role_policy_name : var.execution_role_name
  path   = "/"
  policy = length(var.execution_role_policy_document) > 0 ? var.execution_role_policy_document : data.aws_iam_policy_document.execution_role.json
}

resource "aws_iam_role_policy_attachment" "execution_role" {
  role       = aws_iam_role.execution_role.name
  policy_arn = aws_iam_policy.execution_role.arn
}

resource "aws_api_gateway_rest_api" "main" {
  name = var.name
  endpoint_configuration {
    types = ["REGIONAL"]
  }
  tags = var.tags
}

resource "aws_api_gateway_authorizer" "cognito_user_pools" {
  count           = var.authorization == "COGNITO_USER_POOLS" ? 1 : 0
  identity_source = "method.request.header.Authorization"
  name            = length(var.authorizer_name) > 0 ? var.authorizer_name : var.name
  rest_api_id     = aws_api_gateway_rest_api.main.id
  type            = "COGNITO_USER_POOLS"
  provider_arns   = var.cognito_user_pool_arns
}

resource "aws_api_gateway_request_validator" "parameters" {
  name                        = "Validate query string parameters and headers"
  rest_api_id                 = aws_api_gateway_rest_api.main.id
  validate_request_body       = false
  validate_request_parameters = true
}

#
# Records / GET
#

resource "aws_api_gateway_resource" "records" {
  path_part   = "records"
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  rest_api_id = aws_api_gateway_rest_api.main.id
}

resource "aws_api_gateway_method" "records_get" {
  count       = var.allow_get_records ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.records.id
  http_method = "GET"

  api_key_required = var.api_key_required
  authorization    = var.authorization
  authorizer_id    = var.authorization == "COGNITO_USER_POOLS" ? aws_api_gateway_authorizer.cognito_user_pools.0.id : null

  request_parameters = {
    "method.request.header.ShardIterator" = true
    "method.request.header.Limit"         = false
  }

  request_validator_id = aws_api_gateway_request_validator.parameters.id
}

resource "aws_api_gateway_method_response" "records_get_200" {
  count       = var.allow_get_records ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.records.id
  http_method = aws_api_gateway_method.records_get.0.http_method
  status_code = "200"
  response_models = {
    "application/json" = "Empty"
  }
  response_parameters = {}
}

resource "aws_api_gateway_integration" "records_get" {
  count                   = var.allow_get_records ? 1 : 0
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.records.id
  http_method             = aws_api_gateway_method.records_get.0.http_method
  integration_http_method = "POST"
  type                    = "AWS"
  timeout_milliseconds    = var.timeout_milliseconds
  uri = format(
    "arn:%s:apigateway:%s:kinesis:action/GetRecords",
    data.aws_partition.current.partition,
    data.aws_region.current.name
  )
  credentials = aws_iam_role.execution_role.arn
  request_parameters = {
    "integration.request.header.Content-Type" = "'application/x-amz-json-1.1'"
  }
  request_templates = {
    "application/json" = <<EOT
    {
      #if( "$input.params('Limit')" != "" )
      "Limit": $input.params('Limit'),
      #end
      "ShardIterator": "$input.params('ShardIterator')"
    }
    EOT
  }
}

resource "aws_api_gateway_integration_response" "records_get" {
  count               = var.allow_get_records ? 1 : 0
  rest_api_id         = aws_api_gateway_rest_api.main.id
  resource_id         = aws_api_gateway_resource.records.id
  http_method         = aws_api_gateway_method.records_get.0.http_method
  status_code         = aws_api_gateway_method_response.records_get_200.0.status_code
  response_parameters = {}
}

#
# Shards
#

resource "aws_api_gateway_resource" "shards" {
  path_part   = "shards"
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  rest_api_id = aws_api_gateway_rest_api.main.id
}

resource "aws_api_gateway_method" "shards_get" {
  count       = var.allow_list_shards ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.shards.id
  http_method = "GET"

  api_key_required = var.api_key_required
  authorization    = var.authorization
  authorizer_id    = var.authorization == "COGNITO_USER_POOLS" ? aws_api_gateway_authorizer.cognito_user_pools.0.id : null

  request_parameters = {
    "method.request.querystring.StreamName" = false
    "method.request.querystring.NextToken"  = false
    "method.request.querystring.MaxResults" = false
  }

  request_validator_id = aws_api_gateway_request_validator.parameters.id
}

resource "aws_api_gateway_method_response" "shards_get_200" {
  count       = var.allow_list_shards ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.shards.id
  http_method = aws_api_gateway_method.shards_get.0.http_method
  status_code = "200"
  response_models = {
    "application/json" = "Empty"
  }
  response_parameters = {}
}

resource "aws_api_gateway_integration" "shards_get" {
  count                   = var.allow_list_shards ? 1 : 0
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.shards.id
  http_method             = aws_api_gateway_method.shards_get.0.http_method
  integration_http_method = "POST"
  type                    = "AWS"
  timeout_milliseconds    = var.timeout_milliseconds
  uri = format(
    "arn:%s:apigateway:%s:kinesis:action/ListShards",
    data.aws_partition.current.partition,
    data.aws_region.current.name
  )
  credentials = aws_iam_role.execution_role.arn
  request_parameters = {
    "integration.request.header.Content-Type" = "'application/x-amz-json-1.1'"
  }
  request_templates = {
    "application/json" = <<EOT
    {
      #if( "$input.params('MaxResults')" != "" )
      "MaxResults": $input.params('MaxResults'),
      #end
      #if( "$input.params('NextToken')" != "" )
      "NextToken": "$input.params('NextToken')"
      #else
      "StreamName": "$input.params('StreamName')"
      #end
    }
    EOT
  }
}

resource "aws_api_gateway_integration_response" "shards_get" {
  count               = var.allow_list_shards ? 1 : 0
  rest_api_id         = aws_api_gateway_rest_api.main.id
  resource_id         = aws_api_gateway_resource.shards.id
  http_method         = aws_api_gateway_method.shards_get.0.http_method
  status_code         = aws_api_gateway_method_response.shards_get_200.0.status_code
  response_parameters = {}
}

#
# Streams
#

resource "aws_api_gateway_resource" "streams" {
  path_part   = "streams"
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  rest_api_id = aws_api_gateway_rest_api.main.id
}

resource "aws_api_gateway_method" "streams_get" {
  count       = var.allow_list_streams ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.streams.id
  http_method = "GET"

  api_key_required = var.api_key_required
  authorization    = var.authorization
  authorizer_id    = var.authorization == "COGNITO_USER_POOLS" ? aws_api_gateway_authorizer.cognito_user_pools.0.id : null

  request_validator_id = aws_api_gateway_request_validator.parameters.id
}

resource "aws_api_gateway_method_response" "streams_get_200" {
  count       = var.allow_list_streams ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.streams.id
  http_method = aws_api_gateway_method.streams_get.0.http_method
  status_code = "200"
  response_models = {
    "application/json" = "Empty"
  }
  response_parameters = {}
}

resource "aws_api_gateway_integration" "streams_get" {
  count                   = var.allow_list_streams ? 1 : 0
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.streams.id
  http_method             = aws_api_gateway_method.streams_get.0.http_method
  integration_http_method = "POST"
  type                    = "AWS"
  timeout_milliseconds    = var.timeout_milliseconds
  uri = format(
    "arn:%s:apigateway:%s:kinesis:action/ListStreams",
    data.aws_partition.current.partition,
    data.aws_region.current.name
  )
  credentials = aws_iam_role.execution_role.arn
  request_parameters = {
    "integration.request.header.Content-Type" = "'application/x-amz-json-1.1'"
  }
  request_templates = {
    "application/json" = jsonencode({})
  }
}

resource "aws_api_gateway_integration_response" "streams_get" {
  count               = var.allow_list_streams ? 1 : 0
  rest_api_id         = aws_api_gateway_rest_api.main.id
  resource_id         = aws_api_gateway_resource.streams.id
  http_method         = aws_api_gateway_method.streams_get.0.http_method
  status_code         = aws_api_gateway_method_response.streams_get_200.0.status_code
  response_parameters = {}
}

#
# Stream
#

resource "aws_api_gateway_resource" "stream" {
  path_part   = "{stream-name}"
  parent_id   = aws_api_gateway_resource.streams.id
  rest_api_id = aws_api_gateway_rest_api.main.id
}

resource "aws_api_gateway_method" "stream_get" {
  count       = var.allow_describe_stream ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.stream.id
  http_method = "GET"

  api_key_required = var.api_key_required
  authorization    = var.authorization
  authorizer_id    = var.authorization == "COGNITO_USER_POOLS" ? aws_api_gateway_authorizer.cognito_user_pools.0.id : null

  request_parameters = {}

  request_validator_id = aws_api_gateway_request_validator.parameters.id
}

resource "aws_api_gateway_method_response" "stream_get_200" {
  count       = var.allow_describe_stream ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.stream.id
  http_method = aws_api_gateway_method.stream_get.0.http_method
  status_code = "200"
  response_models = {
    "application/json" = "Empty"
  }
  response_parameters = {}
}

resource "aws_api_gateway_integration" "stream_get" {
  count                   = var.allow_describe_stream ? 1 : 0
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.stream.id
  http_method             = aws_api_gateway_method.stream_get.0.http_method
  integration_http_method = "POST"
  type                    = "AWS"
  timeout_milliseconds    = var.timeout_milliseconds
  uri = format(
    "arn:%s:apigateway:%s:kinesis:action/DescribeStreamSummary",
    data.aws_partition.current.partition,
    data.aws_region.current.name
  )
  credentials = aws_iam_role.execution_role.arn
  request_parameters = {
    "integration.request.header.Content-Type" = "'application/x-amz-json-1.1'"
  }
  request_templates = {
    "application/json" = <<EOT
    {
        "StreamName": "$input.params('stream-name')"
    }
    EOT
  }
}

resource "aws_api_gateway_integration_response" "stream_get" {
  count               = var.allow_describe_stream ? 1 : 0
  rest_api_id         = aws_api_gateway_rest_api.main.id
  resource_id         = aws_api_gateway_resource.stream.id
  http_method         = aws_api_gateway_method.stream_get.0.http_method
  status_code         = aws_api_gateway_method_response.stream_get_200.0.status_code
  response_parameters = {}
}

#
# Record
#

resource "aws_api_gateway_resource" "record" {
  path_part   = "record"
  parent_id   = aws_api_gateway_resource.stream.id
  rest_api_id = aws_api_gateway_rest_api.main.id
}

resource "aws_api_gateway_method" "record_put" {
  count       = var.allow_put_record ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.record.id
  http_method = "PUT"

  api_key_required = var.api_key_required
  authorization    = var.authorization
  authorizer_id    = var.authorization == "COGNITO_USER_POOLS" ? aws_api_gateway_authorizer.cognito_user_pools.0.id : null

  request_parameters = {}

  request_validator_id = aws_api_gateway_request_validator.parameters.id
}

resource "aws_api_gateway_method_response" "record_put_200" {
  count       = var.allow_put_record ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.record.id
  http_method = aws_api_gateway_method.record_put.0.http_method
  status_code = "200"
  response_models = {
    "application/json" = "Empty"
  }
  response_parameters = {}
}

resource "aws_api_gateway_integration" "record_put" {
  count                   = var.allow_put_record ? 1 : 0
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.record.id
  http_method             = aws_api_gateway_method.record_put.0.http_method
  integration_http_method = "POST"
  type                    = "AWS"
  timeout_milliseconds    = var.timeout_milliseconds
  uri = format(
    "arn:%s:apigateway:%s:kinesis:action/PutRecord",
    data.aws_partition.current.partition,
    data.aws_region.current.name
  )
  credentials = aws_iam_role.execution_role.arn
  request_parameters = {
    "integration.request.header.Content-Type" = "'application/x-amz-json-1.1'"
  }
  request_templates = length(var.request_templates_record_put) > 0 ? var.request_templates_record_put : {
    "application/json" = <<EOT
    {
        "StreamName": "$input.params('stream-name')",
        "Data": "$util.base64Encode($input.json('$.Data'))",
        "PartitionKey": "$input.path('$.PartitionKey')"
    }
    EOT
  }
}

resource "aws_api_gateway_integration_response" "record_put" {
  count               = var.allow_put_record ? 1 : 0
  rest_api_id         = aws_api_gateway_rest_api.main.id
  resource_id         = aws_api_gateway_resource.record.id
  http_method         = aws_api_gateway_method.record_put.0.http_method
  status_code         = aws_api_gateway_method_response.record_put_200.0.status_code
  response_parameters = {}
}

#
# Records
#

resource "aws_api_gateway_resource" "stream_records" {
  path_part   = "records"
  parent_id   = aws_api_gateway_resource.stream.id
  rest_api_id = aws_api_gateway_rest_api.main.id
}

#
# Records / PUT
#

resource "aws_api_gateway_method" "records_put" {
  count       = var.allow_put_records ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.stream_records.id
  http_method = "PUT"

  api_key_required = var.api_key_required
  authorization    = var.authorization
  authorizer_id    = var.authorization == "COGNITO_USER_POOLS" ? aws_api_gateway_authorizer.cognito_user_pools.0.id : null
}

resource "aws_api_gateway_method_response" "records_put_200" {
  count       = var.allow_put_records ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.stream_records.id
  http_method = aws_api_gateway_method.records_put.0.http_method
  status_code = "200"
  response_models = {
    "application/json" = "Empty"
  }
  response_parameters = {}
}

resource "aws_api_gateway_integration" "records_put" {
  count                   = var.allow_put_records ? 1 : 0
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.stream_records.id
  http_method             = aws_api_gateway_method.records_put.0.http_method
  integration_http_method = "POST"
  type                    = "AWS"
  timeout_milliseconds    = var.timeout_milliseconds
  uri = format(
    "arn:%s:apigateway:%s:kinesis:action/PutRecords",
    data.aws_partition.current.partition,
    data.aws_region.current.name
  )
  credentials = aws_iam_role.execution_role.arn
  request_parameters = {
    "integration.request.header.Content-Type" = "'application/x-amz-json-1.1'"
  }
  request_templates = {
    "application/json" = <<EOT
    {
      "StreamName": "$input.params('stream-name')",
      "Records": [
        #foreach($elem in $input.path('$.Records'))
        {
          "Data": "$util.base64Encode($elem.Data)",
          "PartitionKey": "$elem.PartitionKey"
        }#if($foreach.hasNext),#end
        #end
      ]
    }
    EOT
  }
}

resource "aws_api_gateway_integration_response" "records_put" {
  count               = var.allow_put_records ? 1 : 0
  rest_api_id         = aws_api_gateway_rest_api.main.id
  resource_id         = aws_api_gateway_resource.stream_records.id
  http_method         = aws_api_gateway_method.records_put.0.http_method
  status_code         = aws_api_gateway_method_response.records_put_200.0.status_code
  response_parameters = {}
}

#
# Records
#

resource "aws_api_gateway_resource" "sharditerator" {
  path_part   = "sharditerator"
  parent_id   = aws_api_gateway_resource.stream.id
  rest_api_id = aws_api_gateway_rest_api.main.id
}

#
# Shard Iterator / Get
#

resource "aws_api_gateway_method" "sharditerator_get" {
  count       = var.allow_get_records ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.sharditerator.id
  http_method = "GET"

  api_key_required = var.api_key_required
  authorization    = var.authorization
  authorizer_id    = var.authorization == "COGNITO_USER_POOLS" ? aws_api_gateway_authorizer.cognito_user_pools.0.id : null

  request_parameters = {
    "method.request.querystring.ShardId"                = true
    "method.request.querystring.ShardIteratorType"      = false
    "method.request.querystring.StartingSequenceNumber" = false
    "method.request.querystring.Timestamp"              = false
  }

  request_validator_id = aws_api_gateway_request_validator.parameters.id
}

resource "aws_api_gateway_method_response" "sharditerator_get_200" {
  count       = var.allow_get_records ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.sharditerator.id
  http_method = aws_api_gateway_method.sharditerator_get.0.http_method
  status_code = "200"
  response_models = {
    "application/json" = "Empty"
  }
  response_parameters = {}
}

resource "aws_api_gateway_integration" "sharditerator_get" {
  count                   = var.allow_get_records ? 1 : 0
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.sharditerator.id
  http_method             = aws_api_gateway_method.sharditerator_get.0.http_method
  integration_http_method = "POST"
  type                    = "AWS"
  timeout_milliseconds    = var.timeout_milliseconds
  uri = format(
    "arn:%s:apigateway:%s:kinesis:action/GetShardIterator",
    data.aws_partition.current.partition,
    data.aws_region.current.name
  )
  credentials = aws_iam_role.execution_role.arn
  request_parameters = {
    "integration.request.header.Content-Type" = "'application/x-amz-json-1.1'"
  }
  request_templates = {
    "application/json" = <<EOT
    {
      #if( "$input.params('Timestamp')" != "" )
      "Timestamp": $input.params('Timestamp'),
      #end
      #if( "$input.params('StartingSequenceNumber')" != "" )
      "StartingSequenceNumber": "$input.params('StartingSequenceNumber')",
      #end
      #if( "$input.params('ShardIteratorType')" != "" )
      "ShardIteratorType": "$input.params('ShardIteratorType')",
      #else
      "ShardIteratorType": "TRIM_HORIZON",
      #end
      "ShardId": "$input.params('ShardId')",
      "StreamName": "$input.params('stream-name')"
    }
    EOT
  }
}

resource "aws_api_gateway_integration_response" "sharditerator_get" {
  count               = var.allow_get_records ? 1 : 0
  rest_api_id         = aws_api_gateway_rest_api.main.id
  resource_id         = aws_api_gateway_resource.sharditerator.id
  http_method         = aws_api_gateway_method.sharditerator_get.0.http_method
  status_code         = aws_api_gateway_method_response.sharditerator_get_200.0.status_code
  response_parameters = {}
}
