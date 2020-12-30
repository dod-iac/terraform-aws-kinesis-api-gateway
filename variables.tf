variable "authorization" {
  type        = string
  description = "The type of authorization used to authenticate requests.  Valid values are NONE or COGNITO_USER_POOLS."
  default     = "NONE"
}

variable "authorizer_name" {
  type        = string
  description = "Name of the API Gateway Authorizer.  If not provided, defaults to the name of the API Gateway."
  default     = ""
}

variable "cognito_user_pool_arns" {
  type        = list(string)
  description = "The ARNs of the Cognito User Pools used for authenticating requests."
  default     = []
}

variable "allow_describe_stream" {
  type        = bool
  description = "Allow the API to describe a Kinesis stream using the kinesis:DescribeStreamSummary action."
  default     = false
}

variable "allow_get_records" {
  type        = bool
  description = "Allow the API to retrieve a list of records into the Kinesis stream using the kinesis:GetRecords, and kinesis:GetShardIterator actions."
  default     = false
}

variable "allow_list_shards" {
  type        = bool
  description = "Allow the API to list all shards in the account using the kinesis:ListShards action."
  default     = false
}

variable "allow_list_streams" {
  type        = bool
  description = "Allow the API to list all streams in the account using the kinesis:ListStreams action."
  default     = false
}

variable "allow_put_record" {
  type        = bool
  description = "Allow the API to write a single record into the Kinesis stream using the kinesis:PutRecord action."
  default     = false
}

variable "allow_put_records" {
  type        = bool
  description = "Allow the API to write a batch of records into the Kinesis stream using the kinesis:PutRecords action."
  default     = false
}

variable "api_key_required" {
  type        = bool
  description = "Specify if an API key is required."
  default     = false
}

variable "execution_role_name" {
  type        = string
  description = "The name of the execution role used by the REST API."
}

variable "execution_role_policy_document" {
  type        = string
  description = "The contents of the IAM policy attached to the IAM Execution role used by the REST API.  If not defined, then creates the policy based on allowed actions."
  default     = ""
}

variable "execution_role_policy_name" {
  type        = string
  description = "The name of the IAM policy attached to the IAM Execution role used by the REST API.  If not defined, then uses the value of \"execution_role_name\"."
  default     = ""
}

variable "name" {
  type        = string
  description = "Name of the AWS API Gateway REST API."
}

variable "request_templates_record_put" {
  type        = map(string)
  description = "Override the request templates for submitting individual records via the HTTP PUT method at the /streams/{stream-name}/record path."
  default     = {}
}

variable "streams" {
  type        = list(string)
  description = "The ARNs of the streams the role is allowed to read from.  Use [\"*\"] to allow all streams."
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to the AWS API Gateway REST API."
  default     = {}
}

variable "timeout_milliseconds" {
  type        = number
  description = "Custom timeout between 50 and 29,000 milliseconds."
  default     = "29000"
}
