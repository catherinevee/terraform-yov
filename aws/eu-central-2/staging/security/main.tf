# Production-like security group for staging environment
variable "vpc_id" {
  description = "VPC ID where the security group will be created"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
}

variable "tags" {
  description = "Tags to apply to the security group"
  type        = map(string)
  default     = {}
}

# Web tier security group (ALB/public-facing)
resource "aws_security_group" "web_tier" {
  name_prefix = "staging-euc2-web-sg-"
  description = "Security group for web tier in staging environment"
  vpc_id      = var.vpc_id

  # Allow HTTPS access
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Allow HTTP access (for redirect to HTTPS)
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Allow staging testing port
  ingress {
    description = "Staging testing port"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Allow all outbound traffic
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "staging-euc2-web-tier-sg"
    Tier = "web"
  })
}

# Application tier security group
resource "aws_security_group" "app_tier" {
  name_prefix = "staging-euc2-app-sg-"
  description = "Security group for application tier in staging environment"
  vpc_id      = var.vpc_id

  # Allow SSH access from VPC (for staging debugging)
  ingress {
    description = "SSH from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Allow application port from web tier
  ingress {
    description     = "App port from web tier"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.web_tier.id]
  }

  # Allow secondary app port from web tier
  ingress {
    description     = "Secondary app port from web tier"
    from_port       = 8081
    to_port         = 8081
    protocol        = "tcp"
    security_groups = [aws_security_group.web_tier.id]
  }

  # Allow metrics endpoint from VPC
  ingress {
    description = "Metrics endpoint from VPC"
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Allow all outbound traffic
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "staging-euc2-app-tier-sg"
    Tier = "application"
  })
}

# Database tier security group
resource "aws_security_group" "database_tier" {
  name_prefix = "staging-euc2-db-sg-"
  description = "Security group for database tier in staging environment"
  vpc_id      = var.vpc_id

  # Allow PostgreSQL from application tier
  ingress {
    description     = "PostgreSQL from app tier"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app_tier.id]
  }

  # Allow PostgreSQL from VPC (for staging testing/debugging)
  ingress {
    description = "PostgreSQL from VPC for testing"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Allow Redis from application tier
  ingress {
    description     = "Redis from app tier"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.app_tier.id]
  }

  # Allow Redis from VPC (for staging testing)
  ingress {
    description = "Redis from VPC for testing"
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # No outbound rules for database tier (restrictive)
  tags = merge(var.tags, {
    Name = "staging-euc2-database-tier-sg"
    Tier = "database"
  })
}

# EKS cluster security group (if needed)
resource "aws_security_group" "eks_cluster" {
  name_prefix = "staging-euc2-eks-cluster-sg-"
  description = "Security group for EKS cluster in staging environment"
  vpc_id      = var.vpc_id

  # Allow HTTPS API access from VPC
  ingress {
    description = "HTTPS API access from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Allow HTTPS API access for staging testing
  ingress {
    description = "HTTPS API access for testing"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]  # Can be restricted to office IPs later
  }

  # Allow all outbound traffic
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "staging-euc2-eks-cluster-sg"
    Tier = "kubernetes"
    Component = "cluster"
  })
}

# EKS node security group
resource "aws_security_group" "eks_nodes" {
  name_prefix = "staging-euc2-eks-nodes-sg-"
  description = "Security group for EKS nodes in staging environment"
  vpc_id      = var.vpc_id

  # Allow all traffic from EKS cluster
  ingress {
    description     = "All traffic from EKS cluster"
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_cluster.id]
  }

  # Allow SSH access from VPC
  ingress {
    description = "SSH access from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Allow NodePort services from VPC
  ingress {
    description = "NodePort services from VPC"
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Allow inter-node communication
  ingress {
    description = "Inter-node communication"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    self        = true
  }

  # Allow all outbound traffic
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "staging-euc2-eks-nodes-sg"
    Tier = "kubernetes"
    Component = "nodes"
  })
}

# Outputs
output "web_tier_security_group_id" {
  description = "ID of the web tier security group"
  value       = aws_security_group.web_tier.id
}

output "app_tier_security_group_id" {
  description = "ID of the application tier security group"
  value       = aws_security_group.app_tier.id
}

output "database_tier_security_group_id" {
  description = "ID of the database tier security group"
  value       = aws_security_group.database_tier.id
}

output "eks_cluster_security_group_id" {
  description = "ID of the EKS cluster security group"
  value       = aws_security_group.eks_cluster.id
}

output "eks_nodes_security_group_id" {
  description = "ID of the EKS nodes security group"
  value       = aws_security_group.eks_nodes.id
}

output "security_group_ids" {
  description = "Map of all security group IDs"
  value = {
    web_tier      = aws_security_group.web_tier.id
    app_tier      = aws_security_group.app_tier.id
    database_tier = aws_security_group.database_tier.id
    eks_cluster   = aws_security_group.eks_cluster.id
    eks_nodes     = aws_security_group.eks_nodes.id
  }
}
