resource "aws_api_gateway_rest_api" "main" {
  name        = "${var.project}-${var.environment}"
  description = "REST API for ${var.project} ${var.environment} environment"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = var.common_tags
}

resource "aws_api_gateway_request_validator" "main" {
  name                        = "${var.project}-${var.environment}-validator"
  rest_api_id                 = aws_api_gateway_rest_api.main.id
  validate_request_body       = true
  validate_request_parameters = true
}

resource "aws_api_gateway_gateway_response" "cors" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  status_code   = "4XX"
  response_type = "DEFAULT_4XX"

  response_templates = {
    "application/json" = "{\"message\":$context.error.messageString}"
  }

  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Origin"  = "'${join(",", var.allowed_origins)}'"
    "gatewayresponse.header.Access-Control-Allow-Headers" = "'*'"
    "gatewayresponse.header.Access-Control-Allow-Methods" = "'*'"
  }
}

resource "aws_api_gateway_deployment" "main" {
  rest_api_id = aws_api_gateway_rest_api.main.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_rest_api.main.root_resource_id,
      aws_api_gateway_gateway_response.cors,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "main" {
  deployment_id = aws_api_gateway_deployment.main.id
  rest_api_id   = aws_api_gateway_rest_api.main.id
  stage_name    = var.environment

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      caller         = "$context.identity.caller"
      user           = "$context.identity.user"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      resourcePath   = "$context.resourcePath"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
    })
  }

  xray_tracing_enabled = var.enable_xray

  tags = var.common_tags
}

resource "aws_api_gateway_method_settings" "main" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  stage_name  = aws_api_gateway_stage.main.stage_name
  method_path = "*/*"

  settings {
    metrics_enabled    = true
    logging_level      = "INFO"
    data_trace_enabled = var.environment != "prod"
    throttling_rate_limit  = var.api_throttle_rate
    throttling_burst_limit = var.api_throttle_burst
  }
}

resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/${var.project}-${var.environment}"
  retention_in_days = var.log_retention_days
  kms_key_id        = aws_kms_key.logs.arn

  tags = var.common_tags
}

resource "aws_kms_key" "logs" {
  description             = "KMS key for API Gateway logs encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  tags = var.common_tags
}

resource "aws_kms_alias" "logs" {
  name          = "alias/${var.project}-${var.environment}-api-logs"
  target_key_id = aws_kms_key.logs.key_id
}

resource "aws_api_gateway_usage_plan" "plans" {
  for_each = var.api_usage_plans

  name        = "${var.project}-${var.environment}-${each.key}"
  description = "Usage plan for ${each.key} tier"

  api_stages {
    api_id = aws_api_gateway_rest_api.main.id
    stage  = aws_api_gateway_stage.main.stage_name
  }

  quota_settings {
    limit  = each.value.quota_limit
    period = each.value.quota_period
  }

  throttle_settings {
    rate_limit  = each.value.rate_limit
    burst_limit = each.value.burst_limit
  }

  tags = var.common_tags
}

resource "aws_api_gateway_api_key" "keys" {
  for_each = var.api_usage_plans

  name        = "${var.project}-${var.environment}-${each.key}-key"
  description = "API key for ${each.key} usage plan"
  enabled     = true

  tags = var.common_tags
}

resource "aws_api_gateway_usage_plan_key" "plan_keys" {
  for_each = var.api_usage_plans

  key_id        = aws_api_gateway_api_key.keys[each.key].id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.plans[each.key].id
}

resource "aws_cloudfront_distribution" "api_cdn" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "${var.project}-${var.environment} API CDN"
  default_root_object = ""
  price_class         = var.environment == "prod" ? "PriceClass_All" : "PriceClass_200"

  origin {
    domain_name = "${aws_api_gateway_rest_api.main.id}.execute-api.${data.aws_region.current.name}.amazonaws.com"
    origin_id   = "api-gateway-${var.environment}"
    origin_path = "/${var.environment}"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "api-gateway-${var.environment}"

    forwarded_values {
      query_string = true
      headers      = ["Authorization", "Origin", "Accept", "Content-Type"]

      cookies {
        forward = "all"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 86400
    compress               = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = var.domain_name == "" ? true : false
    acm_certificate_arn            = var.certificate_arn
    minimum_protocol_version       = "TLSv1.2_2021"
    ssl_support_method             = var.domain_name == "" ? null : "sni-only"
  }

  web_acl_id = var.enable_waf ? aws_wafv2_web_acl.main[0].arn : null

  tags = var.common_tags
}

resource "aws_wafv2_web_acl" "main" {
  count = var.enable_waf ? 1 : 0

  name  = "${var.project}-${var.environment}-waf"
  scope = "CLOUDFRONT"

  default_action {
    allow {}
  }

  rule {
    name     = "RateLimitRule"
    priority = 1

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 10000
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimitRule"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "CommonRuleSetMetric"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 3

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "KnownBadInputsRuleSetMetric"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "WAFMetric"
    sampled_requests_enabled   = true
  }

  tags = var.common_tags
}

data "aws_region" "current" {}