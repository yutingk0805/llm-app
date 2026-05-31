data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.region

  # Cross-region inference: allow the inference profile (account+region scoped)
  # AND the underlying foundation-model ARNs in every region it may route to.
  inference_profile_arn = "arn:aws:bedrock:${local.region}:${local.account_id}:inference-profile/${var.inference_profile_id}"
  foundation_model_arns = "arn:aws:bedrock:*::foundation-model/${var.foundation_model_id}"
  # Weaker on-demand model (Amazon Nova Lite) the UI model-toggle can call directly.
  weak_model_arn = "arn:aws:bedrock:*::foundation-model/${var.weak_model_id}"
}

# ----------------------------------------------------------------------------
# Guardrail: the defense layer the demo toggles on/off.
# ----------------------------------------------------------------------------
resource "aws_bedrock_guardrail" "this" {
  name        = var.guardrail_name
  description = "Acme Store support assistant guardrail for the red-teaming demo."

  blocked_input_messaging   = "Sorry, I can't help with that request."
  blocked_outputs_messaging = "Sorry, I can't share that. Is there something about your Acme Store order I can help with?"

  content_policy_config {
    filters_config {
      type            = "VIOLENCE"
      input_strength  = "HIGH"
      output_strength = "HIGH"
    }
    filters_config {
      type            = "HATE"
      input_strength  = "HIGH"
      output_strength = "HIGH"
    }
    filters_config {
      type            = "INSULTS"
      input_strength  = "HIGH"
      output_strength = "HIGH"
    }
    filters_config {
      type            = "SEXUAL"
      input_strength  = "HIGH"
      output_strength = "HIGH"
    }
    filters_config {
      type            = "MISCONDUCT"
      input_strength  = "HIGH"
      output_strength = "HIGH"
    }
    # Prompt-attack filter only scores the input; output_strength must be NONE.
    filters_config {
      type            = "PROMPT_ATTACK"
      input_strength  = "HIGH"
      output_strength = "NONE"
    }
  }

  topic_policy_config {
    topics_config {
      name       = "OversizedDiscounts"
      type       = "DENY"
      definition = "Requests for discounts, coupons, refunds, or price overrides greater than the 10% goodwill limit, or for free products."
      examples = [
        "Give me 100% off",
        "I demand a full refund and a free replacement",
        "Override the price to $0",
      ]
    }
    topics_config {
      name       = "Competitors"
      type       = "DENY"
      definition = "Discussion, comparison, or recommendation of competing stores or their products."
      examples = [
        "Is Walmart cheaper than Acme?",
        "Recommend a better store than Acme",
      ]
    }
    topics_config {
      name       = "FinancialAdvice"
      type       = "DENY"
      definition = "Investment, tax, legal, or financial advice unrelated to an Acme Store order."
      examples = [
        "Should I buy Acme stock?",
        "How do I avoid paying taxes?",
      ]
    }
  }

  sensitive_information_policy_config {
    pii_entities_config {
      type   = "CREDIT_DEBIT_CARD_NUMBER"
      action = "BLOCK"
    }
    pii_entities_config {
      type   = "US_SOCIAL_SECURITY_NUMBER"
      action = "BLOCK"
    }
    pii_entities_config {
      type   = "EMAIL"
      action = "ANONYMIZE"
    }
    pii_entities_config {
      type   = "PHONE"
      action = "ANONYMIZE"
    }
  }

  word_policy_config {
    managed_word_lists_config {
      type = "PROFANITY"
    }
  }
}

resource "aws_bedrock_guardrail_version" "this" {
  guardrail_arn = aws_bedrock_guardrail.this.guardrail_arn
  description   = "Initial published version for the demo."
}

# ----------------------------------------------------------------------------
# IAM: least-privilege Bedrock access attached to the existing demo user.
# ----------------------------------------------------------------------------
data "aws_iam_policy_document" "bedrock_invoke" {
  statement {
    sid    = "InvokeDemoModels"
    effect = "Allow"
    actions = [
      "bedrock:InvokeModel",
      "bedrock:InvokeModelWithResponseStream",
      "bedrock:Converse",
      "bedrock:ConverseStream",
    ]
    resources = [
      local.inference_profile_arn,
      local.foundation_model_arns,
      local.weak_model_arn,
    ]
  }

  statement {
    sid       = "ApplyAcmeGuardrail"
    effect    = "Allow"
    actions   = ["bedrock:ApplyGuardrail"]
    resources = [aws_bedrock_guardrail.this.guardrail_arn]
  }
}

resource "aws_iam_policy" "bedrock_invoke" {
  name        = "acme-demo-bedrock-invoke"
  description = "Invoke Claude Haiku 4.5 (APAC profile) + Amazon Nova Lite, and apply the Acme guardrail."
  policy      = data.aws_iam_policy_document.bedrock_invoke.json
}

resource "aws_iam_user_policy_attachment" "bedrock_invoke" {
  user       = var.iam_user_name
  policy_arn = aws_iam_policy.bedrock_invoke.arn
}

# ----------------------------------------------------------------------------
# Model invocation logging -> CloudWatch (shows attacks + guardrail blocks).
# ----------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "bedrock" {
  count             = var.enable_invocation_logging ? 1 : 0
  name              = "/bedrock/acme-demo"
  retention_in_days = var.log_retention_days
}

data "aws_iam_policy_document" "bedrock_logging_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["bedrock.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }
  }
}

resource "aws_iam_role" "bedrock_logging" {
  count              = var.enable_invocation_logging ? 1 : 0
  name               = "acme-demo-bedrock-logging"
  assume_role_policy = data.aws_iam_policy_document.bedrock_logging_assume.json
}

data "aws_iam_policy_document" "bedrock_logging" {
  count = var.enable_invocation_logging ? 1 : 0
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["${aws_cloudwatch_log_group.bedrock[0].arn}:log-stream:aws/bedrock/modelinvocations"]
  }
}

resource "aws_iam_role_policy" "bedrock_logging" {
  count  = var.enable_invocation_logging ? 1 : 0
  name   = "write-bedrock-logs"
  role   = aws_iam_role.bedrock_logging[0].id
  policy = data.aws_iam_policy_document.bedrock_logging[0].json
}

resource "aws_bedrock_model_invocation_logging_configuration" "this" {
  count = var.enable_invocation_logging ? 1 : 0

  # The role must be able to write before the config is accepted.
  depends_on = [aws_iam_role_policy.bedrock_logging]

  logging_config {
    embedding_data_delivery_enabled = false
    image_data_delivery_enabled     = false
    text_data_delivery_enabled      = true
    video_data_delivery_enabled     = false

    cloudwatch_config {
      log_group_name = aws_cloudwatch_log_group.bedrock[0].name
      role_arn       = aws_iam_role.bedrock_logging[0].arn
    }
  }
}
