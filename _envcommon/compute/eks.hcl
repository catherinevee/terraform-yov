# =============================================================================
# SHARED EKS CLUSTER CONFIGURATION
# =============================================================================
# This file contains reusable EKS configuration that can be inherited
# by different environments with environment-specific customizations

# Include hierarchical configurations
include "root" {
  path = find_in_parent_folders("root.hcl")
  expose = true
}

include "region" {
  path = find_in_parent_folders("region.hcl")
  expose = true
}

include "env" {
  path = find_in_parent_folders("env.hcl")
  expose = true
}

include "account" {
  path = find_in_parent_folders("account.hcl")
  expose = true
}

locals {
  # Extract values from included configurations
  root_vars = include.root.locals
  region_vars = include.region.locals
  env_vars = include.env.locals
  account_vars = include.account.locals
  
  environment = local.env_vars.environment
  region = local.region_vars.aws_region
  region_short = local.region_vars.aws_region_short
  
  # EKS cluster naming
  cluster_name = "${local.environment}-${local.region_short}-eks-main"
  
  # Environment-specific EKS configurations
  eks_configs = {
    dev = {
      cluster_version = "1.29"
      cluster_endpoint_private_access = true
      cluster_endpoint_public_access = true
      cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"]
      
      # Node group configuration
      instance_types = ["t3.medium", "t3a.medium"]
      capacity_type = "SPOT"
      min_size = 1
      max_size = 5
      desired_size = 2
      
      # Disk configuration
      disk_size = 20
      disk_type = "gp3"
      disk_iops = 3000
      disk_throughput = 125
      
      # Networking
      cluster_security_group_additional_rules = {
        egress_nodes_ephemeral_ports_tcp = {
          description = "To node 1025-65535"
          protocol = "tcp"
          from_port = 1025
          to_port = 65535
          type = "egress"
          source_node_security_group = true
        }
      }
      
      # Add-ons
      cluster_addons = {
        coredns = {
          addon_version = "v1.11.1-eksbuild.4"
          configuration_values = jsonencode({
            replicaCount = 2
            resources = {
              requests = { cpu = "100m", memory = "128Mi" }
              limits = { cpu = "200m", memory = "256Mi" }
            }
          })
        }
        vpc-cni = {
          addon_version = "v1.14.1-eksbuild.1"
          configuration_values = jsonencode({
            env = {
              ENABLE_PREFIX_DELEGATION = "true"
              WARM_PREFIX_TARGET = "1"
            }
          })
        }
        kube-proxy = {
          addon_version = "v1.29.0-eksbuild.1"
        }
        aws-ebs-csi-driver = {
          addon_version = "v1.25.0-eksbuild.1"
        }
      }
      
      # Logging
      cluster_enabled_log_types = ["api", "audit"]
      cloudwatch_log_group_retention_in_days = 7
      
      # Node group defaults
      eks_managed_node_group_defaults = {
        ami_type = "AL2_x86_64"
        platform = "linux"
        enable_monitoring = false
        
        metadata_options = {
          http_endpoint = "enabled"
          http_tokens = "required"
          http_put_response_hop_limit = 2
          instance_metadata_tags = "disabled"
        }
        
        block_device_mappings = {
          xvda = {
            device_name = "/dev/xvda"
            ebs = {
              volume_size = 20
              volume_type = "gp3"
              iops = 3000
              throughput = 125
              encrypted = true
              delete_on_termination = true
            }
          }
        }
      }
    }
    
    staging = {
      cluster_version = "1.29"
      cluster_endpoint_private_access = true
      cluster_endpoint_public_access = true
      cluster_endpoint_public_access_cidrs = ["10.0.0.0/8"]
      
      # Node group configuration
      instance_types = ["t3.large", "m5.large"]
      capacity_type = "SPOT"
      min_size = 2
      max_size = 8
      desired_size = 3
      
      # Disk configuration
      disk_size = 50
      disk_type = "gp3"
      disk_iops = 3000
      disk_throughput = 250
      
      # Add-ons
      cluster_addons = {
        coredns = {
          addon_version = "v1.11.1-eksbuild.4"
          configuration_values = jsonencode({
            replicaCount = 2
            resources = {
              requests = { cpu = "100m", memory = "128Mi" }
              limits = { cpu = "300m", memory = "512Mi" }
            }
          })
        }
        vpc-cni = {
          addon_version = "v1.14.1-eksbuild.1"
          configuration_values = jsonencode({
            env = {
              ENABLE_PREFIX_DELEGATION = "true"
              WARM_PREFIX_TARGET = "1"
              ENABLE_POD_ENI = "true"
            }
          })
        }
        kube-proxy = {
          addon_version = "v1.29.0-eksbuild.1"
        }
        aws-ebs-csi-driver = {
          addon_version = "v1.25.0-eksbuild.1"
        }
        aws-efs-csi-driver = {
          addon_version = "v1.7.0-eksbuild.1"
        }
      }
      
      # Logging
      cluster_enabled_log_types = ["api", "audit", "authenticator"]
      cloudwatch_log_group_retention_in_days = 30
      
      # Enhanced monitoring
      eks_managed_node_group_defaults = {
        ami_type = "AL2_x86_64"
        platform = "linux"
        enable_monitoring = true
        
        metadata_options = {
          http_endpoint = "enabled"
          http_tokens = "required"
          http_put_response_hop_limit = 2
          instance_metadata_tags = "enabled"
        }
        
        block_device_mappings = {
          xvda = {
            device_name = "/dev/xvda"
            ebs = {
              volume_size = 50
              volume_type = "gp3"
              iops = 3000
              throughput = 250
              encrypted = true
              delete_on_termination = true
            }
          }
        }
      }
    }
    
    prod = {
      cluster_version = "1.28"  # Stable version for production
      cluster_endpoint_private_access = true
      cluster_endpoint_public_access = false  # Private only for production
      cluster_endpoint_public_access_cidrs = []
      
      # Node group configuration
      instance_types = ["m5.xlarge", "m5.2xlarge", "m5a.xlarge"]
      capacity_type = "ON_DEMAND"  # No spot instances in production
      min_size = 3
      max_size = 20
      desired_size = 6
      
      # Disk configuration
      disk_size = 100
      disk_type = "gp3"
      disk_iops = 10000
      disk_throughput = 1000
      
      # Production security group rules
      cluster_security_group_additional_rules = {
        egress_nodes_ephemeral_ports_tcp = {
          description = "To node 1025-65535"
          protocol = "tcp"
          from_port = 1025
          to_port = 65535
          type = "egress"
          source_node_security_group = true
        }
        ingress_nodes_kube_api = {
          description = "Node groups to cluster API"
          protocol = "tcp"
          from_port = 443
          to_port = 443
          type = "ingress"
          source_node_security_group = true
        }
      }
      
      # Production-grade add-ons
      cluster_addons = {
        coredns = {
          addon_version = "v1.10.1-eksbuild.6"  # Stable version
          configuration_values = jsonencode({
            replicaCount = 3
            resources = {
              requests = { cpu = "200m", memory = "256Mi" }
              limits = { cpu = "500m", memory = "512Mi" }
            }
            nodeSelector = {
              "node-type" = "system"
            }
            tolerations = [{
              key = "CriticalAddonsOnly"
              operator = "Exists"
            }]
          })
        }
        vpc-cni = {
          addon_version = "v1.14.1-eksbuild.1"
          configuration_values = jsonencode({
            env = {
              ENABLE_PREFIX_DELEGATION = "true"
              WARM_PREFIX_TARGET = "2"
              ENABLE_POD_ENI = "true"
              DISABLE_TCP_EARLY_DEMUX = "true"
              ENABLE_BANDWIDTH_PLUGIN = "true"
            }
          })
        }
        kube-proxy = {
          addon_version = "v1.28.2-eksbuild.2"
        }
        aws-ebs-csi-driver = {
          addon_version = "v1.25.0-eksbuild.1"
        }
        aws-efs-csi-driver = {
          addon_version = "v1.7.0-eksbuild.1"
        }
        adot = {
          addon_version = "v0.88.0-eksbuild.1"
        }
      }
      
      # Comprehensive logging for production
      cluster_enabled_log_types = [
        "api", "audit", "authenticator", "controllerManager", "scheduler"
      ]
      cloudwatch_log_group_retention_in_days = 90
      
      # Production node group defaults
      eks_managed_node_group_defaults = {
        ami_type = "AL2_x86_64"
        platform = "linux"
        enable_monitoring = true
        
        metadata_options = {
          http_endpoint = "enabled"
          http_tokens = "required"
          http_put_response_hop_limit = 2
          instance_metadata_tags = "enabled"
        }
        
        block_device_mappings = {
          xvda = {
            device_name = "/dev/xvda"
            ebs = {
              volume_size = 100
              volume_type = "gp3"
              iops = 10000
              throughput = 1000
              encrypted = true
              delete_on_termination = true
            }
          }
        }
        
        # Production node labels and taints
        labels = {
          Environment = "production"
          ManagedBy = "Terragrunt"
        }
        
        # User data for enhanced security
        pre_bootstrap_user_data = <<-EOT
          #!/bin/bash
          # Enhanced security configuration for production nodes
          
          # Update all packages
          yum update -y
          
          # Install additional security tools
          yum install -y amazon-cloudwatch-agent
          
          # Configure CloudWatch agent
          cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'EOF'
          {
            "agent": {
              "metrics_collection_interval": 60,
              "run_as_user": "cwagent"
            },
            "metrics": {
              "namespace": "CWAgent",
              "metrics_collected": {
                "cpu": {
                  "measurement": ["cpu_usage_idle", "cpu_usage_iowait"],
                  "metrics_collection_interval": 60
                },
                "disk": {
                  "measurement": ["used_percent"],
                  "metrics_collection_interval": 60,
                  "resources": ["*"]
                },
                "mem": {
                  "measurement": ["mem_used_percent"],
                  "metrics_collection_interval": 60
                }
              }
            },
            "logs": {
              "logs_collected": {
                "files": {
                  "collect_list": [
                    {
                      "file_path": "/var/log/messages",
                      "log_group_name": "/aws/ec2/production/system",
                      "log_stream_name": "{instance_id}-messages"
                    }
                  ]
                }
              }
            }
          }
          EOF
          
          # Start CloudWatch agent
          /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
            -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s
          
          # Configure kubelet with production settings
          echo 'KUBELET_EXTRA_ARGS=--max-pods=250 --kube-reserved=cpu=250m,memory=1Gi,ephemeral-storage=1Gi --system-reserved=cpu=250m,memory=0.5Gi,ephemeral-storage=1Gi --eviction-hard=memory.available<200Mi,nodefs.available<10%' >> /etc/kubernetes/kubelet/kubelet-config.json
        EOT
      }
    }
  }
  
  current_eks_config = local.eks_configs[local.environment]
  
  # Common node groups for all environments
  base_node_groups = {
    general = {
      name = "${local.cluster_name}-general"
      
      instance_types = local.current_eks_config.instance_types
      capacity_type = local.current_eks_config.capacity_type
      
      min_size = local.current_eks_config.min_size
      max_size = local.current_eks_config.max_size
      desired_size = local.current_eks_config.desired_size
      
      disk_size = local.current_eks_config.disk_size
      disk_type = local.current_eks_config.disk_type
      
      labels = {
        Environment = local.environment
        NodeGroup = "general"
        ManagedBy = "Terragrunt"
        WorkloadType = "general"
      }
      
      taints = {}
      
      update_config = {
        max_unavailable_percentage = local.environment == "prod" ? 25 : 50
      }
      
      tags = {
        Name = "${local.cluster_name}-general"
        NodeGroup = "general"
        Environment = local.environment
      }
    }
  }
  
  # Environment-specific additional node groups
  additional_node_groups = local.environment == "prod" ? {
    system = {
      name = "${local.cluster_name}-system"
      
      instance_types = ["m5.large"]
      capacity_type = "ON_DEMAND"
      
      min_size = 2
      max_size = 4
      desired_size = 3
      
      disk_size = 50
      disk_type = "gp3"
      
      labels = {
        Environment = local.environment
        NodeGroup = "system"
        ManagedBy = "Terragrunt"
        WorkloadType = "system"
        "node-type" = "system"
      }
      
      taints = {
        CriticalAddonsOnly = {
          key = "CriticalAddonsOnly"
          value = "true"
          effect = "NO_SCHEDULE"
        }
      }
      
      tags = {
        Name = "${local.cluster_name}-system"
        NodeGroup = "system"
        Environment = local.environment
        Purpose = "SystemWorkloads"
      }
    }
    
    compute = {
      name = "${local.cluster_name}-compute"
      
      instance_types = ["c5.2xlarge", "c5.4xlarge"]
      capacity_type = "ON_DEMAND"
      
      min_size = 0
      max_size = 10
      desired_size = 2
      
      disk_size = 100
      disk_type = "gp3"
      
      labels = {
        Environment = local.environment
        NodeGroup = "compute"
        ManagedBy = "Terragrunt"
        WorkloadType = "compute-intensive"
      }
      
      taints = {
        ComputeIntensive = {
          key = "workload-type"
          value = "compute-intensive"
          effect = "NO_SCHEDULE"
        }
      }
      
      tags = {
        Name = "${local.cluster_name}-compute"
        NodeGroup = "compute"
        Environment = local.environment
        Purpose = "ComputeWorkloads"
      }
    }
  } : {}
  
  # Merge node groups
  all_node_groups = merge(local.base_node_groups, local.additional_node_groups)
}

# Dependencies
dependency "vpc" {
  config_path = "${get_terragrunt_dir()}/../../networking/vpc"
  
  mock_outputs = {
    vpc_id = "vpc-mock123456789"
    private_subnets = ["subnet-mock-private-1a", "subnet-mock-private-1b", "subnet-mock-private-1c"]
    intra_subnets = ["subnet-mock-intra-1a", "subnet-mock-intra-1b"]
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "fmt", "show"]
}

dependency "kms" {
  config_path = "${get_terragrunt_dir()}/../../security/kms-app"
  
  mock_outputs = {
    key_arn = "arn:aws:kms:us-east-1:123456789012:key/mock-uuid"
    key_id = "mock-uuid"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "fmt", "show"]
}

# Terraform module source
terraform {
  source = "tfr:///terraform-aws-modules/eks/aws?version=19.15.0"
}

# Common inputs for EKS module
inputs = {
  # Cluster configuration
  cluster_name = local.cluster_name
  cluster_version = local.current_eks_config.cluster_version
  
  # VPC configuration
  vpc_id = dependency.vpc.outputs.vpc_id
  subnet_ids = dependency.vpc.outputs.private_subnets
  control_plane_subnet_ids = dependency.vpc.outputs.intra_subnets
  
  # Cluster endpoint configuration
  cluster_endpoint_private_access = local.current_eks_config.cluster_endpoint_private_access
  cluster_endpoint_public_access = local.current_eks_config.cluster_endpoint_public_access
  cluster_endpoint_public_access_cidrs = local.current_eks_config.cluster_endpoint_public_access_cidrs
  
  # Cluster encryption
  cluster_encryption_config = {
    provider_key_arn = dependency.kms.outputs.key_arn
    resources = ["secrets"]
  }
  
  # Security group rules
  cluster_security_group_additional_rules = try(local.current_eks_config.cluster_security_group_additional_rules, {})
  
  # Logging
  cluster_enabled_log_types = local.current_eks_config.cluster_enabled_log_types
  cloudwatch_log_group_retention_in_days = local.current_eks_config.cloudwatch_log_group_retention_in_days
  
  # Add-ons
  cluster_addons = local.current_eks_config.cluster_addons
  
  # IRSA (IAM Roles for Service Accounts)
  enable_irsa = true
  
  # Node groups
  eks_managed_node_group_defaults = local.current_eks_config.eks_managed_node_group_defaults
  eks_managed_node_groups = local.all_node_groups
  
  # AWS Auth ConfigMap
  manage_aws_auth_configmap = true
  
  aws_auth_roles = [
    {
      rolearn = "arn:aws:iam::${local.account_vars.account_ids[local.environment]}:role/YOVKubernetesAdminRole"
      username = "admin"
      groups = ["system:masters"]
    },
    {
      rolearn = "arn:aws:iam::${local.account_vars.account_ids[local.environment]}:role/YOVKubernetesDeveloperRole"
      username = "developer"
      groups = ["yov:developers"]
    }
  ]
  
  aws_auth_users = local.environment != "prod" ? [
    {
      userarn = "arn:aws:iam::${local.account_vars.account_ids[local.environment]}:user/eks-developer"
      username = "eks-developer"
      groups = ["yov:developers"]
    }
  ] : []
  
  # Tags
  tags = merge(
    local.root_vars.common_tags,
    local.env_vars.environment_tags,
    {
      Name = local.cluster_name
      Purpose = "KubernetesCluster"
      ClusterType = "Production"
      KubernetesVersion = local.current_eks_config.cluster_version
      
      # EKS specific tags
      "kubernetes.io/cluster/${local.cluster_name}" = "owned"
      
      # Security tags
      EncryptionEnabled = "true"
      PrivateEndpoint = local.current_eks_config.cluster_endpoint_public_access ? "false" : "true"
      LoggingEnabled = "true"
      
      # Operational tags
      BackupRequired = local.environment == "prod" ? "true" : "false"
      MonitoringLevel = local.environment == "prod" ? "enhanced" : "basic"
      AlertingEnabled = local.environment != "dev" ? "true" : "false"
    }
  )
}
