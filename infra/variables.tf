variable "aws_region" {
  description = "Region the demo runs in. Sydney has Bedrock + Guardrails + the Australia inference profile."
  type        = string
  default     = "ap-southeast-2"
}

variable "iam_user_name" {
  description = "Name of an EXISTING IAM user to attach the Bedrock policy to (the user whose keys run the app)."
  type        = string
}

variable "inference_profile_id" {
  description = "Claude Haiku 4.5 Australia cross-region inference profile ID used by the app."
  type        = string
  default     = "au.anthropic.claude-haiku-4-5-20251001-v1:0"
}

variable "foundation_model_id" {
  description = "Bare foundation-model ID the inference profile routes to (for IAM resource ARNs)."
  type        = string
  default     = "anthropic.claude-haiku-4-5-20251001-v1:0"
}

variable "weak_model_id" {
  description = "Weaker on-demand model used by the UI 'model' toggle (for IAM resource ARNs)."
  type        = string
  default     = "amazon.nova-lite-v1:0"
}

variable "guardrail_name" {
  description = "Name of the Bedrock guardrail."
  type        = string
  default     = "acme-support-guardrail"
}

variable "enable_invocation_logging" {
  description = "Create the account/region Bedrock model-invocation logging config (singleton). Set false if one already exists."
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "CloudWatch retention for Bedrock invocation logs (keep short to stay cheap)."
  type        = number
  default     = 7
}
