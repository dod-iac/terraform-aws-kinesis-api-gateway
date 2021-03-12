<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Usage

Creates an AWS API Gateway REST API that proxies a AWS Kinesis stream.

```hcl
module "kinesis_api_gateway" {
  source = "dod-iac/kinesis-api-gateway/aws"

  allow_describe_stream  = false
  allow_get_records = true
  allow_list_shards  = false
  allow_list_streams  = false
  allow_put_record = true
  allow_put_records = false

  authorization       = "NONE"
  execution_role_name = format("api-%s-%s", var.application, var.environment)
  name                = format("api-%s-%s", var.application, var.environment)
  streams             = [module.aws_kinesis_stream.arn]

  tags = {
    Application = var.application
    Environment = var.environment
    Automation  = "Terraform"
  }
}
```

The following API endpoints are conditionally created by the `allow_*` variables.

```text
allow_get_records => GET /records -H "ShardIterator: XYZ" -H "Limit: 123"
allow_list_shards => GET /shards?StreamName=XYZ&MaxResults=123
allow_list_shards => GET /shards?NextToken=XYZ&MaxResults=123
allow_list_streams => GET /streams
allow_describe_stream => GET /streams/{stream-name}
allow_put_record => PUT /streams/{stream-name}/record
allow_put_records => PUT /streams/{stream-name}/records
allow_get_records => GET /streams/{stream-name}/sharditerator?ShardId=XYZ&ShardIteratorType=XYZ&StartingSequenceNumber=XYZ&Timestamp=XYZ
```

Once the REST API is created, to avoid an inconsistent terraform state, manually deploy the REST by using the `deploy-api` script, e.g., `scripts/deploy-api us-west-2 api-hello-experimental experimental`.

## Terraform Version

Terraform 0.12. Pin module version to ~> 1.0.0 . Submit pull-requests to master branch.

Terraform 0.11 is not supported.

## License

This project constitutes a work of the United States Government and is not subject to domestic copyright protection under 17 USC § 105.  However, because the project utilizes code licensed from contributors and other third parties, it therefore is licensed under the MIT License.  See LICENSE file for more information.

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 0.13 |
| aws | ~> 3.0 |

## Providers

| Name | Version |
|------|---------|
| aws | ~> 3.0 |

## Modules

No Modules.

## Resources

| Name |
|------|
| [aws_api_gateway_authorizer](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_authorizer) |
| [aws_api_gateway_integration](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_integration) |
| [aws_api_gateway_integration_response](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_integration_response) |
| [aws_api_gateway_method](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_method) |
| [aws_api_gateway_method_response](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_method_response) |
| [aws_api_gateway_request_validator](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_request_validator) |
| [aws_api_gateway_resource](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_resource) |
| [aws_api_gateway_rest_api](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_rest_api) |
| [aws_caller_identity](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) |
| [aws_iam_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) |
| [aws_iam_policy_document](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) |
| [aws_iam_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) |
| [aws_iam_role_policy_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) |
| [aws_partition](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) |
| [aws_region](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| allow\_describe\_stream | Allow the API to describe a Kinesis stream using the kinesis:DescribeStreamSummary action. | `bool` | `false` | no |
| allow\_get\_records | Allow the API to retrieve a list of records into the Kinesis stream using the kinesis:GetRecords, and kinesis:GetShardIterator actions. | `bool` | `false` | no |
| allow\_list\_shards | Allow the API to list all shards in the account using the kinesis:ListShards action. | `bool` | `false` | no |
| allow\_list\_streams | Allow the API to list all streams in the account using the kinesis:ListStreams action. | `bool` | `false` | no |
| allow\_put\_record | Allow the API to write a single record into the Kinesis stream using the kinesis:PutRecord action. | `bool` | `false` | no |
| allow\_put\_records | Allow the API to write a batch of records into the Kinesis stream using the kinesis:PutRecords action. | `bool` | `false` | no |
| api\_key\_required | Specify if an API key is required. | `bool` | `false` | no |
| authorization | The type of authorization used to authenticate requests.  Valid values are NONE or COGNITO\_USER\_POOLS. | `string` | `"NONE"` | no |
| authorizer\_name | Name of the API Gateway Authorizer.  If not provided, defaults to the name of the API Gateway. | `string` | `""` | no |
| cognito\_user\_pool\_arns | The ARNs of the Cognito User Pools used for authenticating requests. | `list(string)` | `[]` | no |
| execution\_role\_name | The name of the execution role used by the REST API. | `string` | n/a | yes |
| execution\_role\_policy\_document | The contents of the IAM policy attached to the IAM Execution role used by the REST API.  If not defined, then creates the policy based on allowed actions. | `string` | `""` | no |
| execution\_role\_policy\_name | The name of the IAM policy attached to the IAM Execution role used by the REST API.  If not defined, then uses the value of "execution\_role\_name". | `string` | `""` | no |
| name | Name of the AWS API Gateway REST API. | `string` | n/a | yes |
| request\_templates\_record\_put | Override the request templates for submitting individual records via the HTTP PUT method at the /streams/{stream-name}/record path. | `map(string)` | `{}` | no |
| streams | The ARNs of the streams the role is allowed to read from.  Use ["*"] to allow all streams. | `list(string)` | n/a | yes |
| tags | Tags applied to the AWS API Gateway REST API. | `map(string)` | `{}` | no |
| timeout\_milliseconds | Custom timeout between 50 and 29,000 milliseconds. | `number` | `"29000"` | no |

## Outputs

| Name | Description |
|------|-------------|
| rest\_api\_arn | The Amazon Resource Name (ARN) of the AWS API Gateway REST API. |
| rest\_api\_id | The ID of the AWS API Gateway REST API. |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
