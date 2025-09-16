variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "common_tags" {
  type = map(string)
}

variable "enable_versioning" {
  type    = bool
  default = true
}

variable "enable_replication" {
  type    = bool
  default = false
}

variable "replica_region" {
  type    = string
  default = ""
}

locals {
  buckets = {
    documents = {
      purpose = "api-documents"
      lifecycle_rules = [
        {
          id              = "archive-old-files"
          status          = "Enabled"
          transition_days = 30
          storage_class   = "STANDARD_IA"
        },
        {
          id              = "delete-old-files"
          status          = var.environment == "prod" ? "Disabled" : "Enabled"
          expiration_days = 90
        }
      ]
    }
    uploads = {
      purpose = "user-uploads"
      cors_rules = [{
        allowed_headers = ["*"]
        allowed_methods = ["GET", "PUT", "POST"]
        allowed_origins = ["*"]
        expose_headers  = ["ETag"]
        max_age_seconds = 3000
      }]
    }
    logs = {
      purpose = "application-logs"
      lifecycle_rules = [
        {
          id              = "delete-old-logs"
          status          = "Enabled"
          expiration_days = var.environment == "prod" ? 90 : 7
        }
      ]
    }
  }
}

resource "aws_s3_bucket" "buckets" {
  for_each = local.buckets

  bucket = "${var.project}-${var.environment}-${each.value.purpose}"

  tags = merge(
    var.common_tags,
    {
      Name    = "${var.project}-${var.environment}-${each.value.purpose}"
      Purpose = each.value.purpose
    }
  )
}

resource "aws_s3_bucket_versioning" "buckets" {
  for_each = local.buckets

  bucket = aws_s3_bucket.buckets[each.key].id

  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "buckets" {
  for_each = local.buckets

  bucket = aws_s3_bucket.buckets[each.key].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "buckets" {
  for_each = local.buckets

  bucket = aws_s3_bucket.buckets[each.key].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_intelligent_tiering_configuration" "buckets" {
  for_each = var.environment == "prod" ? local.buckets : {}

  bucket = aws_s3_bucket.buckets[each.key].id
  name   = "${each.key}-intelligent-tiering"

  tiering {
    access_tier = "ARCHIVE_ACCESS"
    days        = 90
  }

  tiering {
    access_tier = "DEEP_ARCHIVE_ACCESS"
    days        = 180
  }
}

resource "aws_cloudwatch_event_rule" "s3_events" {
  name        = "${var.project}-${var.environment}-s3-events"
  description = "Capture S3 events for processing"

  event_pattern = jsonencode({
    source      = ["aws.s3"]
    detail-type = ["Object Created", "Object Removed"]
    detail = {
      bucket = {
        name = [for b in aws_s3_bucket.buckets : b.id]
      }
    }
  })

  tags = var.common_tags
}

resource "aws_cloudwatch_event_target" "cloudwatch_logs" {
  rule      = aws_cloudwatch_event_rule.s3_events.name
  target_id = "CloudWatchLogGroup"
  arn       = aws_cloudwatch_log_group.events.arn
}

resource "aws_cloudwatch_log_group" "events" {
  name              = "/aws/events/${var.project}-${var.environment}"
  retention_in_days = 7

  tags = var.common_tags
}

output "bucket_names" {
  value = {
    for k, v in aws_s3_bucket.buckets : k => v.id
  }
}

output "bucket_arns" {
  value = {
    for k, v in aws_s3_bucket.buckets : k => v.arn
  }
}

output "event_rule_arn" {
  value = aws_cloudwatch_event_rule.s3_events.arn
}