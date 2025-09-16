resource "aws_dynamodb_table" "tables" {
  for_each = var.dynamodb_tables

  name         = "${var.project}-${var.environment}-${each.key}"
  billing_mode = each.value.billing_mode

  hash_key  = each.value.hash_key
  range_key = each.value.range_key

  read_capacity  = each.value.billing_mode == "PROVISIONED" ? each.value.read_capacity : null
  write_capacity = each.value.billing_mode == "PROVISIONED" ? each.value.write_capacity : null

  dynamic "attribute" {
    for_each = each.value.attributes
    content {
      name = attribute.value.name
      type = attribute.value.type
    }
  }

  dynamic "global_secondary_index" {
    for_each = each.value.global_secondary_indexes != null ? each.value.global_secondary_indexes : []
    content {
      name            = global_secondary_index.value.name
      hash_key        = global_secondary_index.value.hash_key
      range_key       = global_secondary_index.value.range_key
      projection_type = global_secondary_index.value.projection_type
      read_capacity   = each.value.billing_mode == "PROVISIONED" ? global_secondary_index.value.read_capacity : null
      write_capacity  = each.value.billing_mode == "PROVISIONED" ? global_secondary_index.value.write_capacity : null
    }
  }

  ttl {
    enabled        = each.value.enable_ttl != null ? each.value.enable_ttl : false
    attribute_name = each.value.ttl_attribute != null ? each.value.ttl_attribute : "ttl"
  }

  point_in_time_recovery {
    enabled = each.value.enable_point_in_time_recovery != null ? each.value.enable_point_in_time_recovery : true
  }

  stream_enabled   = each.value.enable_streams != null ? each.value.enable_streams : true
  stream_view_type = each.value.stream_view_type != null ? each.value.stream_view_type : "NEW_AND_OLD_IMAGES"

  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arn != "" ? var.kms_key_arn : null
  }

  dynamic "replica" {
    for_each = var.enable_multi_region ? var.replica_regions : []
    content {
      region_name = replica.value
      kms_key_arn = var.kms_key_arn != "" ? var.kms_key_arn : null
    }
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project}-${var.environment}-${each.key}"
    }
  )

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_appautoscaling_target" "dynamodb_table_read_target" {
  for_each = var.enable_autoscaling && var.environment != "dev" ? {
    for k, v in var.dynamodb_tables : k => v
    if v.billing_mode == "PROVISIONED"
  } : {}

  max_capacity       = var.autoscaling_config.max_read_capacity
  min_capacity       = var.autoscaling_config.min_read_capacity
  resource_id        = "table/${aws_dynamodb_table.tables[each.key].name}"
  scalable_dimension = "dynamodb:table:ReadCapacityUnits"
  service_namespace  = "dynamodb"
}

resource "aws_appautoscaling_target" "dynamodb_table_write_target" {
  for_each = var.enable_autoscaling && var.environment != "dev" ? {
    for k, v in var.dynamodb_tables : k => v
    if v.billing_mode == "PROVISIONED"
  } : {}

  max_capacity       = var.autoscaling_config.max_write_capacity
  min_capacity       = var.autoscaling_config.min_write_capacity
  resource_id        = "table/${aws_dynamodb_table.tables[each.key].name}"
  scalable_dimension = "dynamodb:table:WriteCapacityUnits"
  service_namespace  = "dynamodb"
}

resource "aws_appautoscaling_policy" "dynamodb_table_read_policy" {
  for_each = var.enable_autoscaling && var.environment != "dev" ? {
    for k, v in var.dynamodb_tables : k => v
    if v.billing_mode == "PROVISIONED"
  } : {}

  name               = "${var.project}-${var.environment}-${each.key}-read-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.dynamodb_table_read_target[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.dynamodb_table_read_target[each.key].scalable_dimension
  service_namespace  = aws_appautoscaling_target.dynamodb_table_read_target[each.key].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "DynamoDBReadCapacityUtilization"
    }
    target_value = var.autoscaling_config.target_tracking_read
  }
}

resource "aws_appautoscaling_policy" "dynamodb_table_write_policy" {
  for_each = var.enable_autoscaling && var.environment != "dev" ? {
    for k, v in var.dynamodb_tables : k => v
    if v.billing_mode == "PROVISIONED"
  } : {}

  name               = "${var.project}-${var.environment}-${each.key}-write-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.dynamodb_table_write_target[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.dynamodb_table_write_target[each.key].scalable_dimension
  service_namespace  = aws_appautoscaling_target.dynamodb_table_write_target[each.key].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "DynamoDBWriteCapacityUtilization"
    }
    target_value = var.autoscaling_config.target_tracking_write
  }
}

resource "aws_dynamodb_contributor_insights" "tables" {
  for_each = var.environment == "prod" ? var.dynamodb_tables : {}

  table_name = aws_dynamodb_table.tables[each.key].name
}

resource "aws_rds_cluster" "aurora_serverless" {
  count = var.enable_aurora ? 1 : 0

  cluster_identifier = "${var.project}-${var.environment}-aurora"
  engine             = "aurora-mysql"
  engine_mode        = "provisioned"
  engine_version     = var.aurora_config.engine_version
  database_name      = var.aurora_config.database_name
  master_username    = var.aurora_config.master_username
  master_password    = random_password.aurora_password[0].result

  serverlessv2_scaling_configuration {
    max_capacity = var.aurora_config.max_capacity
    min_capacity = var.aurora_config.min_capacity
  }

  backup_retention_period      = var.aurora_config.backup_retention_period
  preferred_backup_window      = var.aurora_config.preferred_backup_window
  preferred_maintenance_window = var.aurora_config.preferred_maintenance_window

  db_subnet_group_name   = aws_db_subnet_group.aurora[0].name
  vpc_security_group_ids = [aws_security_group.aurora[0].id]

  storage_encrypted = true
  kms_key_id        = var.kms_key_arn != "" ? var.kms_key_arn : null

  enabled_cloudwatch_logs_exports = ["audit", "error", "general", "slowquery"]

  skip_final_snapshot       = var.environment != "prod"
  final_snapshot_identifier = var.environment == "prod" ? "${var.project}-${var.environment}-aurora-final-${formatdate("YYYYMMDDHHmmss", timestamp())}" : null

  apply_immediately = var.environment != "prod"

  enable_http_endpoint = var.aurora_config.enable_http_endpoint

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project}-${var.environment}-aurora"
    }
  )
}

resource "aws_rds_cluster_instance" "aurora_serverless" {
  count = var.enable_aurora ? 1 : 0

  identifier         = "${var.project}-${var.environment}-aurora-instance-1"
  cluster_identifier = aws_rds_cluster.aurora_serverless[0].id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.aurora_serverless[0].engine
  engine_version     = aws_rds_cluster.aurora_serverless[0].engine_version

  performance_insights_enabled = var.environment == "prod"
  monitoring_interval          = var.environment == "prod" ? 60 : 0
  monitoring_role_arn          = var.environment == "prod" ? aws_iam_role.aurora_monitoring[0].arn : null

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project}-${var.environment}-aurora-instance-1"
    }
  )
}

resource "random_password" "aurora_password" {
  count = var.enable_aurora ? 1 : 0

  length  = 32
  special = true
}

resource "aws_secretsmanager_secret" "aurora_password" {
  count = var.enable_aurora ? 1 : 0

  name                    = "${var.project}-${var.environment}-aurora-password"
  description             = "Aurora Serverless master password"
  recovery_window_in_days = var.environment == "prod" ? 30 : 7

  tags = var.common_tags
}

resource "aws_secretsmanager_secret_version" "aurora_password" {
  count = var.enable_aurora ? 1 : 0

  secret_id = aws_secretsmanager_secret.aurora_password[0].id
  secret_string = jsonencode({
    username = var.aurora_config.master_username
    password = random_password.aurora_password[0].result
    engine   = "mysql"
    host     = aws_rds_cluster.aurora_serverless[0].endpoint
    port     = 3306
    database = var.aurora_config.database_name
  })
}

resource "aws_db_subnet_group" "aurora" {
  count = var.enable_aurora ? 1 : 0

  name       = "${var.project}-${var.environment}-aurora-subnet-group"
  subnet_ids = var.vpc_subnet_ids

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project}-${var.environment}-aurora-subnet-group"
    }
  )
}

resource "aws_security_group" "aurora" {
  count = var.enable_aurora ? 1 : 0

  name        = "${var.project}-${var.environment}-aurora-sg"
  description = "Security group for Aurora Serverless"
  vpc_id      = data.aws_subnet.vpc[0].vpc_id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.main[0].cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project}-${var.environment}-aurora-sg"
    }
  )
}

resource "aws_iam_role" "aurora_monitoring" {
  count = var.enable_aurora && var.environment == "prod" ? 1 : 0

  name = "${var.project}-${var.environment}-aurora-monitoring"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy_attachment" "aurora_monitoring" {
  count = var.enable_aurora && var.environment == "prod" ? 1 : 0

  role       = aws_iam_role.aurora_monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

data "aws_subnet" "vpc" {
  count = var.enable_aurora ? 1 : 0
  id    = var.vpc_subnet_ids[0]
}

data "aws_vpc" "main" {
  count = var.enable_aurora ? 1 : 0
  id    = data.aws_subnet.vpc[0].vpc_id
}