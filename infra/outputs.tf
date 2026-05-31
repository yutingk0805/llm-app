output "guardrail_id" {
  description = "Set as BEDROCK_GUARDRAIL_ID in the app's .env.local."
  value       = aws_bedrock_guardrail.this.guardrail_id
}

output "guardrail_arn" {
  value = aws_bedrock_guardrail.this.guardrail_arn
}

output "guardrail_version" {
  description = "Set as BEDROCK_GUARDRAIL_VERSION in the app's .env.local."
  value       = aws_bedrock_guardrail_version.this.version
}

output "inference_profile_id" {
  description = "Set as BEDROCK_MODEL_ID in the app's .env.local."
  value       = var.inference_profile_id
}

output "log_group_name" {
  description = "CloudWatch log group with model-invocation + guardrail traces."
  value       = var.enable_invocation_logging ? aws_cloudwatch_log_group.bedrock[0].name : null
}

output "env_local_block" {
  description = "Copy-paste into app .env.local."
  value       = <<-EOT
    AWS_REGION=${var.aws_region}
    BEDROCK_MODEL_ID=${var.inference_profile_id}
    BEDROCK_GUARDRAIL_ID=${aws_bedrock_guardrail.this.guardrail_id}
    BEDROCK_GUARDRAIL_VERSION=${aws_bedrock_guardrail_version.this.version}
  EOT
}
