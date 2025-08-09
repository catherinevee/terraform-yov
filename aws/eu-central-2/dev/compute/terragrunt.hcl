# =============================================================================
# DEVELOPMENT COMPUTE CONFIGURATION
# =============================================================================
# Compute resources for eu-central-2 development environment

# Include the regional configuration
include {
  path = find_in_parent_folders()
}

# Include configurations
locals {
  region_vars = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  env_vars    = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  
  # Extract configurations
  regional_networking = local.region_vars.locals.regional_networking
  env_config    = local.env_vars.locals.env_config
  
  # Compute configuration for development (cost-optimized)
  compute_config = {
    # EKS cluster configuration (minimal for development)
    eks = {
      cluster_name    = "dev-euc2-eks"
      cluster_version = "1.28"
      
      # Cluster configuration (cost-optimized)
      cluster_config = {
        endpoint_private_access = true
        endpoint_public_access  = true    # Allow public access for dev
        public_access_cidrs     = ["0.0.0.0/0"]  # More permissive for dev
        
        # Logging (minimal for cost)
        enabled_cluster_log_types = ["api"]  # Only API logs for cost
        log_retention_in_days     = 7        # Shorter retention
        
        # Encryption (basic)
        cluster_encryption_config = [
          {
            provider_key_arn = null  # Will use KMS key from security module
            resources        = ["secrets"]
          }
        ]
        
        # Add-ons (minimal)
        cluster_addons = {
          aws-ebs-csi-driver = {
            addon_version = "v1.25.0-eksbuild.1"
            resolve_conflicts = "OVERWRITE"
          }
          coredns = {
            addon_version = "v1.10.1-eksbuild.4"
            resolve_conflicts = "OVERWRITE"
          }
          kube-proxy = {
            addon_version = "v1.28.2-eksbuild.2"
            resolve_conflicts = "OVERWRITE"
          }
          vpc-cni = {
            addon_version = "v1.15.1-eksbuild.1"
            resolve_conflicts = "OVERWRITE"
          }
        }
      }
      
      # Node groups (cost-optimized)
      node_groups = {
        # Primary node group - burstable instances
        primary = {
          name           = "dev-euc2-eks-nodes-primary"
          instance_types = ["t3.medium", "t3.large"]  # Burstable instances
          ami_type       = "AL2_x86_64"
          capacity_type  = "SPOT"  # Use spot instances for cost savings
          
          # Scaling configuration (minimal)
          min_size     = 1
          max_size     = 3
          desired_size = 1
          
          # Disk configuration (smaller)
          disk_size = 50  # Smaller disk for dev
          disk_type = "gp3"
          
          # Network configuration
          subnet_ids = null  # Will be set from networking dependency
          
          # Instance configuration
          remote_access = {
            ec2_ssh_key = null  # No SSH key for now
            source_security_group_ids = []
          }
          
          # Kubernetes labels
          k8s_labels = {
            Environment = "development"
            NodeGroup   = "primary"
            InstanceType = "burstable"
          }
          
          # Taints (none for primary)
          taints = []
          
          # Launch template configuration
          create_launch_template = true
          launch_template_name   = "dev-euc2-eks-nodes-primary"
          launch_template_description = "Launch template for primary EKS nodes in development"
          
          # User data
          user_data_base64 = null  # Use default EKS optimized AMI user data
          
          # Update configuration
          update_config = {
            max_unavailable_percentage = 50  # Faster updates in dev
          }
        }
        
        # Workload node group - for specific workloads
        workload = {
          name           = "dev-euc2-eks-nodes-workload"
          instance_types = ["t3.large"]
          ami_type       = "AL2_x86_64"
          capacity_type  = "SPOT"  # Use spot instances
          
          # Scaling configuration (can scale to zero)
          min_size     = 0  # Can scale to zero when not needed
          max_size     = 2
          desired_size = 0  # Start with zero nodes
          
          # Disk configuration
          disk_size = 100  # Larger disk for workloads
          disk_type = "gp3"
          
          # Kubernetes labels
          k8s_labels = {
            Environment = "development"
            NodeGroup   = "workload"
            InstanceType = "compute-optimized"
          }
          
          # Taints for dedicated workloads
          taints = [
            {
              key    = "workload"
              value  = "dedicated"
              effect = "NO_SCHEDULE"
            }
          ]
          
          # Launch template configuration
          create_launch_template = true
          launch_template_name   = "dev-euc2-eks-nodes-workload"
          launch_template_description = "Launch template for workload EKS nodes in development"
          
          # Update configuration
          update_config = {
            max_unavailable_percentage = 25
          }
        }
      }
    }
    
    # Auto Scaling Groups (if needed outside EKS)
    asg = {
      # Web tier ASG (cost-optimized)
      web_tier = {
        name     = "dev-euc2-web-asg"
        min_size = 1
        max_size = 2
        desired_capacity = 1
        
        # Launch template configuration
        launch_template = {
          name          = "dev-euc2-web-lt"
          image_id      = null  # Will use latest Amazon Linux 2
          instance_type = "t3.medium"  # Burstable instance
          key_name      = null  # No SSH key for now
          
          # Security groups (from security module)
          security_groups = null  # Will be set from dependency
          
          # User data
          user_data = base64encode(<<-EOF
            #!/bin/bash
            yum update -y
            yum install -y docker
            systemctl start docker
            systemctl enable docker
            usermod -a -G docker ec2-user
            
            # Install CloudWatch agent for basic monitoring
            yum install -y amazon-cloudwatch-agent
            
            # Configure auto-shutdown for cost savings
            echo "0 18 * * MON-FRI /sbin/shutdown -h now" | crontab -
          EOF
          )
          
          # Block device mappings
          block_device_mappings = [
            {
              device_name = "/dev/xvda"
              ebs = {
                volume_type           = "gp3"
                volume_size          = 30  # Smaller root volume
                delete_on_termination = true
                encrypted            = true
                kms_key_id          = null  # Will use KMS key from security
              }
            }
          ]
          
          # Instance metadata options
          metadata_options = {
            http_endpoint = "enabled"
            http_tokens   = "required"  # IMDSv2 only
            http_put_response_hop_limit = 1
          }
          
          # Spot instance configuration
          instance_market_options = {
            market_type = "spot"
            spot_options = {
              max_price = "0.05"  # Maximum price for t3.medium
            }
          }
        }
        
        # Health check configuration
        health_check_type         = "EC2"  # Cheaper than ELB
        health_check_grace_period = 300
        default_cooldown         = 300
        
        # Termination policies
        termination_policies = ["OldestInstance"]
        
        # Subnet configuration
        vpc_zone_identifier = null  # Will be set from networking dependency
        
        # Target group attachment (if using ALB)
        target_group_arns = []
        
        # Instance refresh configuration
        instance_refresh = {
          strategy = "Rolling"
          preferences = {
            min_healthy_percentage = 50  # Faster refresh in dev
          }
        }
      }
      
      # Application tier ASG (can scale to zero)
      app_tier = {
        name     = "dev-euc2-app-asg"
        min_size = 0  # Can scale to zero
        max_size = 2
        desired_capacity = 0  # Start with zero
        
        # Launch template configuration
        launch_template = {
          name          = "dev-euc2-app-lt"
          image_id      = null  # Will use latest Amazon Linux 2
          instance_type = "t3.large"  # Slightly larger for app workloads
          key_name      = null
          
          # User data for application setup
          user_data = base64encode(<<-EOF
            #!/bin/bash
            yum update -y
            yum install -y docker git
            systemctl start docker
            systemctl enable docker
            usermod -a -G docker ec2-user
            
            # Install development tools
            yum groupinstall -y "Development Tools"
            yum install -y python3 python3-pip nodejs npm
            
            # Configure auto-shutdown for cost savings
            echo "0 18 * * MON-FRI /sbin/shutdown -h now" | crontab -
          EOF
          )
          
          # Block device mappings
          block_device_mappings = [
            {
              device_name = "/dev/xvda"
              ebs = {
                volume_type           = "gp3"
                volume_size          = 50  # Larger for application code
                delete_on_termination = true
                encrypted            = true
                kms_key_id          = null
              }
            }
          ]
          
          # Spot instance configuration
          instance_market_options = {
            market_type = "spot"
            spot_options = {
              max_price = "0.10"  # Maximum price for t3.large
            }
          }
        }
        
        # Health check configuration
        health_check_type         = "EC2"
        health_check_grace_period = 600  # Longer grace period for app startup
        default_cooldown         = 300
        
        # Termination policies
        termination_policies = ["OldestInstance"]
      }
    }
    
    # Load balancer configuration (cost-optimized)
    load_balancer = {
      # Application Load Balancer
      alb = {
        name               = "dev-euc2-alb"
        load_balancer_type = "application"
        scheme             = "internet-facing"
        
        # Subnets (public subnets from networking)
        subnets = null  # Will be set from networking dependency
        
        # Security groups
        security_groups = null  # Will be set from security dependency
        
        # Configuration
        idle_timeout                     = 60
        enable_deletion_protection       = false  # Easy to delete in dev
        enable_cross_zone_load_balancing = false  # Not needed for 2 AZs
        enable_http2                     = true
        
        # Access logs (disabled for cost)
        access_logs = {
          bucket  = null
          enabled = false
        }
        
        # Listeners
        listeners = {
          # HTTP listener (redirect to HTTPS)
          http = {
            port     = 80
            protocol = "HTTP"
            default_action = {
              type = "redirect"
              redirect = {
                port        = "443"
                protocol    = "HTTPS"
                status_code = "HTTP_301"
              }
            }
          }
          
          # HTTPS listener (self-signed cert for dev)
          https = {
            port            = 443
            protocol        = "HTTPS"
            ssl_policy      = "ELBSecurityPolicy-TLS-1-2-2017-01"
            certificate_arn = null  # Will use self-signed or ACM cert
            
            default_action = {
              type = "fixed-response"
              fixed_response = {
                content_type = "text/html"
                message_body = "<h1>Development Environment</h1><p>Load balancer is running</p>"
                status_code  = "200"
              }
            }
          }
        }
        
        # Target groups
        target_groups = {
          web = {
            name             = "dev-euc2-web-tg"
            port             = 80
            protocol         = "HTTP"
            protocol_version = "HTTP1"
            target_type      = "instance"
            
            health_check = {
              enabled             = true
              healthy_threshold   = 2
              unhealthy_threshold = 2
              timeout             = 5
              interval            = 30
              path                = "/"
              matcher             = "200"
              port                = "traffic-port"
              protocol            = "HTTP"
            }
            
            stickiness = {
              enabled = false
              type    = "lb_cookie"
            }
          }
          
          api = {
            name             = "dev-euc2-api-tg"
            port             = 8080
            protocol         = "HTTP"
            protocol_version = "HTTP1"
            target_type      = "instance"
            
            health_check = {
              enabled             = true
              healthy_threshold   = 2
              unhealthy_threshold = 3
              timeout             = 10
              interval            = 30
              path                = "/health"
              matcher             = "200"
              port                = "8080"
              protocol            = "HTTP"
            }
          }
        }
      }
    }
  }
}

# Terraform configuration
terraform {
  source = "${get_parent_terragrunt_dir()}/modules//compute"
}

# Input variables for the compute module
inputs = {
  # VPC configuration from networking
  vpc_id              = dependency.networking.outputs.vpc_id
  private_subnet_ids  = dependency.networking.outputs.private_subnet_ids
  public_subnet_ids   = dependency.networking.outputs.public_subnet_ids
  
  # Security group IDs from security module
  security_group_ids = {
    eks_cluster = dependency.security.outputs.security_group_ids.eks_cluster
    eks_nodes   = dependency.security.outputs.security_group_ids.eks_nodes
    web_tier    = dependency.security.outputs.security_group_ids.web_tier
    app_tier    = dependency.security.outputs.security_group_ids.app_tier
    alb         = dependency.security.outputs.security_group_ids.alb
  }
  
  # KMS key IDs from security module
  kms_key_ids = {
    ebs = dependency.security.outputs.kms_key_ids.ebs
  }
  
  # EKS configuration
  eks_cluster_config = local.compute_config.eks
  
  # Auto Scaling Groups configuration
  asg_config = local.compute_config.asg
  
  # Load balancer configuration
  load_balancer_config = local.compute_config.load_balancer
  
  # Tags
  tags = merge(
    local.env_vars.locals.environment_tags,
    {
      Name        = "dev-euc2-compute"
      Component   = "compute"
      Module      = "compute"
      Purpose     = "development-compute"
      CostCenter  = "development"
      Region      = "eu-central-2"
    }
  )
  
  # EKS specific tags
  eks_tags = {
    "kubernetes.io/cluster/dev-euc2-eks" = "owned"
  }
  
  # Auto-shutdown configuration
  auto_shutdown = local.env_vars.locals.auto_shutdown
}

# Dependencies
dependency "networking" {
  config_path = "../networking"
  
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = {
    vpc_id             = "vpc-mock12345"
    public_subnet_ids  = ["subnet-mock1", "subnet-mock2"]
    private_subnet_ids = ["subnet-mock3", "subnet-mock4"]
    database_subnet_ids = ["subnet-mock5", "subnet-mock6"]
  }
}

dependency "security" {
  config_path = "../security"
  
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = {
    security_group_ids = {
      eks_cluster = "sg-mock1"
      eks_nodes   = "sg-mock2"
      web_tier    = "sg-mock3"
      app_tier    = "sg-mock4"
      alb         = "sg-mock5"
    }
    kms_key_ids = {
      ebs = "arn:aws:kms:eu-central-2:123456789012:key/mock-key-id"
    }
  }
}
