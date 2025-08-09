# Simple security group for development environment
variable "vpc_id" {
  description = "VPC ID where the security group will be created"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block for internal access"
  type        = string
  default     = "10.0.0.0/16"
}

variable "tags" {
  description = "Tags to apply to the security group"
  type        = map(string)
  default     = {}
}

# Create a simple security group
resource "aws_security_group" "dev_basic" {
  name_prefix = "dev-use1-basic-sg-"
  description = "Basic security group for development environment"
  vpc_id      = var.vpc_id

  # SSH access only from VPC (removed public access for security)
  # Note: Use bastion host or VPN for SSH access
  ingress {
    description = "SSH from VPC only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.50.0.0/16"]  # Only from VPC CIDR
  }

  # Allow HTTP access
  ingress {
    description = "HTTP from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Allow HTTPS access from VPC only  
  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Development HTTP port - restrict to VPC only
  ingress {
    description = "Development HTTP from VPC"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["10.50.0.0/16"]  # Only from VPC CIDR
  }

  # React development server - restrict to VPC only
  ingress {
    description = "React dev server from VPC"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["10.50.0.0/16"]  # Only from VPC CIDR
  }

  # Allow PostgreSQL from VPC
  ingress {
    description = "PostgreSQL from VPC"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.50.0.0/16"]
  }

  # Allow all outbound traffic
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}

# Outputs
output "security_group_id" {
  description = "ID of the security group"
  value       = aws_security_group.dev_basic.id
}

output "security_group_arn" {
  description = "ARN of the security group"
  value       = aws_security_group.dev_basic.arn
}

output "security_group_name" {
  description = "Name of the security group"
  value       = aws_security_group.dev_basic.name
}

output "security_group_vpc_id" {
  description = "VPC ID of the security group"
  value       = aws_security_group.dev_basic.vpc_id
}
