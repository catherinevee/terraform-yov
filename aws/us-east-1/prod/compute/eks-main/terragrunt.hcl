# =============================================================================
# PRODUCTION EKS MAIN CLUSTER
# =============================================================================
# This configuration deploys the main production EKS cluster with
# enterprise-grade security, high availability, and monitoring

# Include root configuration (backend, providers)
include "root" {
  path = find_in_parent_folders("root.hcl")
  expose = true
}

# Include environment-common EKS configuration
include "envcommon" {
  path = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/compute/eks.hcl"
  expose = true
  merge_strategy = "deep"
}

# Include region configuration
include "region" {
  path = find_in_parent_folders("region.hcl")
  expose = true
}

# Include environment configuration
include "env" {
  path = find_in_parent_folders("env.hcl")
  expose = true
}

# Include account configuration
include "account" {
  path = find_in_parent_folders("account.hcl")
  expose = true
}

locals {
  # Merge all exposed configurations
  root_vars = include.root.locals
  env_vars = include.env.locals
  region_vars = include.region.locals
  account_vars = include.account.locals
  common_vars = include.envcommon.locals
  
  # Production-specific overrides
  environment = "prod"
  region = "us-east-1"
  cluster_name = "prod-use1-eks-main"
  
  # Production-specific IRSA roles
  irsa_roles = {
    aws_load_balancer_controller = {
      role_name = "YOVProdAWSLoadBalancerController"
      service_account_name = "aws-load-balancer-controller"
      namespace = "kube-system"
      role_policy_arns = [
        "arn:aws:iam::345678901234:policy/AWSLoadBalancerControllerIAMPolicy"
      ]
    }
    
    external_dns = {
      role_name = "YOVProdExternalDNS"
      service_account_name = "external-dns"
      namespace = "kube-system"
      role_policy_arns = [
        "arn:aws:iam::345678901234:policy/ExternalDNSRoute53Policy"
      ]
    }
    
    cluster_autoscaler = {
      role_name = "YOVProdClusterAutoscaler"
      service_account_name = "cluster-autoscaler"
      namespace = "kube-system"
      role_policy_arns = [
        "arn:aws:iam::345678901234:policy/ClusterAutoscalerPolicy"
      ]
    }
    
    ebs_csi_driver = {
      role_name = "YOVProdEBSCSIDriver"
      service_account_name = "ebs-csi-controller-sa"
      namespace = "kube-system"
      role_policy_arns = [
        "arn:aws:iam::aws:policy/service-role/Amazon_EBS_CSI_DriverPolicy"
      ]
    }
    
    secrets_store_csi_driver = {
      role_name = "YOVProdSecretsStoreCSIDriver"
      service_account_name = "secrets-store-csi-driver"
      namespace = "kube-system"
      role_policy_arns = [
        "arn:aws:iam::345678901234:policy/SecretsManagerCSIDriverPolicy"
      ]
    }
    
    fluentbit = {
      role_name = "YOVProdFluentBit"
      service_account_name = "fluent-bit"
      namespace = "amazon-cloudwatch"
      role_policy_arns = [
        "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
      ]
    }
  }
}

# Dependencies
dependency "vpc" {
  config_path = "../../networking/vpc"
  
  mock_outputs = {
    vpc_id = "vpc-0123456789abcdef0"
    private_subnets = ["subnet-0123456789abcdef0", "subnet-0123456789abcdef1", "subnet-0123456789abcdef2"]
    intra_subnets = ["subnet-intra-0123456789abcdef0", "subnet-intra-0123456789abcdef1"]
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "fmt", "show"]
}

dependency "kms" {
  config_path = "../../security/kms-app"
  
  mock_outputs = {
    key_arn = "arn:aws:kms:us-east-1:345678901234:key/12345678-1234-1234-1234-123456789012"
    key_id = "12345678-1234-1234-1234-123456789012"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "fmt", "show"]
}

# Module source from Terraform Registry
terraform {
  source = "tfr:///terraform-aws-modules/eks/aws?version=19.15.0"
}

# Production-specific EKS inputs
inputs = merge(
  include.envcommon.inputs,
  {
    # Production cluster name
    cluster_name = local.cluster_name
    
    # Production-specific cluster configuration
    cluster_version = "1.28"  # LTS version for production stability
    
    # Enhanced cluster endpoint security for production
    cluster_endpoint_private_access = true
    cluster_endpoint_public_access = false  # Private only
    cluster_endpoint_public_access_cidrs = []
    
    # Production-grade service CIDR
    cluster_service_ipv4_cidr = "172.20.0.0/16"
    
    # Production IP family
    cluster_ip_family = "ipv4"
    
    # Enhanced security groups for production
    cluster_security_group_additional_rules = {
      egress_nodes_ephemeral_ports_tcp = {
        description = "Cluster to node groups on ephemeral ports"
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
      
      # Allow communication from VPC endpoints
      ingress_vpc_endpoints = {
        description = "VPC endpoints to cluster API"
        protocol = "tcp"
        from_port = 443
        to_port = 443
        type = "ingress"
        cidr_blocks = ["10.30.0.0/16"]
      }
    }
    
    # Node security group rules for production
    node_security_group_additional_rules = {
      ingress_self_all = {
        description = "Node to node all ports/protocols"
        protocol = "-1"
        from_port = 0
        to_port = 0
        type = "ingress"
        self = true
      }
      
      ingress_cluster_all = {
        description = "Cluster to node all ports/protocols"
        protocol = "-1"
        from_port = 0
        to_port = 0
        type = "ingress"
        source_cluster_security_group = true
      }
      
      egress_all = {
        description = "Node all egress"
        protocol = "-1"
        from_port = 0
        to_port = 0
        type = "egress"
        cidr_blocks = ["0.0.0.0/0"]
      }
      
      # Deny egress to metadata service from pods (security hardening)
      egress_deny_metadata = {
        description = "Deny access to metadata service from pods"
        protocol = "tcp"
        from_port = 80
        to_port = 80
        type = "egress"
        cidr_blocks = ["169.254.169.254/32"]
      }
    }
    
    # Production add-ons with specific versions for stability
    cluster_addons = {
      coredns = {
        addon_version = "v1.10.1-eksbuild.6"
        service_account_role_arn = "arn:aws:iam::345678901234:role/YOVProdCoreDNSRole"
        
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
          affinity = {
            podAntiAffinity = {
              preferredDuringSchedulingIgnoredDuringExecution = [{
                weight = 100
                podAffinityTerm = {
                  labelSelector = {
                    matchExpressions = [{
                      key = "k8s-app"
                      operator = "In"
                      values = ["kube-dns"]
                    }]
                  }
                  topologyKey = "kubernetes.io/hostname"
                }
              }]
            }
          }
        })
      }
      
      vpc-cni = {
        addon_version = "v1.14.1-eksbuild.1"
        service_account_role_arn = "arn:aws:iam::345678901234:role/YOVProdVPCCNIRole"
        
        configuration_values = jsonencode({
          env = {
            ENABLE_PREFIX_DELEGATION = "true"
            WARM_PREFIX_TARGET = "2"
            ENABLE_POD_ENI = "true"
            DISABLE_TCP_EARLY_DEMUX = "true"
            ENABLE_BANDWIDTH_PLUGIN = "true"
            ENABLE_NETWORK_POLICY = "true"
          }
        })
      }
      
      kube-proxy = {
        addon_version = "v1.28.2-eksbuild.2"
        
        configuration_values = jsonencode({
          resources = {
            requests = { cpu = "100m", memory = "128Mi" }
            limits = { cpu = "200m", memory = "256Mi" }
          }
        })
      }
      
      aws-ebs-csi-driver = {
        addon_version = "v1.25.0-eksbuild.1"
        service_account_role_arn = "arn:aws:iam::345678901234:role/YOVProdEBSCSIDriver"
        
        configuration_values = jsonencode({
          controller = {
            replicaCount = 2
            resources = {
              requests = { cpu = "100m", memory = "128Mi" }
              limits = { cpu = "500m", memory = "512Mi" }
            }
            nodeSelector = {
              "node-type" = "system"
            }
            tolerations = [{
              key = "CriticalAddonsOnly"
              operator = "Exists"
            }]
          }
        })
      }
      
      aws-efs-csi-driver = {
        addon_version = "v1.7.0-eksbuild.1"
        service_account_role_arn = "arn:aws:iam::345678901234:role/YOVProdEFSCSIDriver"
      }
      
      adot = {
        addon_version = "v0.88.0-eksbuild.1"
        service_account_role_arn = "arn:aws:iam::345678901234:role/YOVProdADOTCollector"
        
        configuration_values = jsonencode({
          collector = {
            amp = {
              enabled = true
              endpoint = "https://aps-workspaces.us-east-1.amazonaws.com/workspaces/ws-12345678-1234-1234-1234-123456789012"
            }
          }
        })
      }
    }
    
    # Production node groups with enhanced configuration
    eks_managed_node_groups = {
      system = {
        name = "${local.cluster_name}-system"
        use_name_prefix = false
        
        ami_type = "AL2_x86_64"
        platform = "linux"
        
        instance_types = ["m5.large", "m5.xlarge"]
        capacity_type = "ON_DEMAND"
        
        min_size = 3
        max_size = 6
        desired_size = 3
        
        disk_size = 50
        disk_type = "gp3"
        disk_iops = 3000
        disk_throughput = 250
        
        # System workload configuration
        labels = {
          Environment = "production"
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
        
        update_config = {
          max_unavailable = 1
        }
        
        # Enhanced monitoring for system nodes
        enable_monitoring = true
        
        metadata_options = {
          http_endpoint = "enabled"
          http_tokens = "required"
          http_put_response_hop_limit = 1  # More restrictive for system nodes
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
              kms_key_id = dependency.kms.outputs.key_arn
              delete_on_termination = true
            }
          }
        }
        
        pre_bootstrap_user_data = <<-EOT
          #!/bin/bash
          
          # System node configuration
          echo "Configuring system node..."
          
          # Enhanced security settings
          echo 'net.ipv4.conf.all.send_redirects = 0' >> /etc/sysctl.conf
          echo 'net.ipv4.conf.default.send_redirects = 0' >> /etc/sysctl.conf
          echo 'net.ipv4.conf.all.accept_redirects = 0' >> /etc/sysctl.conf
          echo 'net.ipv4.conf.default.accept_redirects = 0' >> /etc/sysctl.conf
          sysctl -p
          
          # Install CloudWatch agent
          yum install -y amazon-cloudwatch-agent
          
          # Configure CloudWatch agent for system metrics
          cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'EOF'
          {
            "agent": {
              "metrics_collection_interval": 60,
              "run_as_user": "cwagent"
            },
            "metrics": {
              "namespace": "EKS/Production/SystemNodes",
              "metrics_collected": {
                "cpu": {
                  "measurement": ["cpu_usage_idle", "cpu_usage_iowait", "cpu_usage_user", "cpu_usage_system"],
                  "metrics_collection_interval": 60,
                  "totalcpu": true
                },
                "disk": {
                  "measurement": ["used_percent", "inodes_free"],
                  "metrics_collection_interval": 60,
                  "resources": ["*"]
                },
                "mem": {
                  "measurement": ["mem_used_percent", "mem_available_percent"],
                  "metrics_collection_interval": 60
                },
                "netstat": {
                  "measurement": ["tcp_established", "tcp_time_wait"],
                  "metrics_collection_interval": 60
                }
              }
            }
          }
          EOF
          
          # Start CloudWatch agent
          /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
            -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s
        EOT
        
        tags = {
          Name = "${local.cluster_name}-system-node"
          NodeGroup = "system"
          Environment = "production"
          Purpose = "SystemWorkloads"
          CriticalAddons = "true"
        }
      }
      
      general = {
        name = "${local.cluster_name}-general"
        use_name_prefix = false
        
        ami_type = "AL2_x86_64"
        platform = "linux"
        
        instance_types = ["m5.xlarge", "m5.2xlarge", "m5a.xlarge"]
        capacity_type = "ON_DEMAND"
        
        min_size = 3
        max_size = 20
        desired_size = 6
        
        disk_size = 100
        disk_type = "gp3"
        disk_iops = 10000
        disk_throughput = 1000
        
        labels = {
          Environment = "production"
          NodeGroup = "general"
          ManagedBy = "Terragrunt"
          WorkloadType = "general"
        }
        
        update_config = {
          max_unavailable_percentage = 25
        }
        
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
              kms_key_id = dependency.kms.outputs.key_arn
              delete_on_termination = true
            }
          }
        }
        
        pre_bootstrap_user_data = <<-EOT
          #!/bin/bash
          
          # General node configuration
          echo "Configuring general production node..."
          
          # Update system
          yum update -y
          
          # Install monitoring tools
          yum install -y amazon-cloudwatch-agent htop iotop
          
          # Configure kubelet for production workloads
          mkdir -p /etc/kubernetes/kubelet
          echo 'KUBELET_EXTRA_ARGS=--max-pods=250 --kube-reserved=cpu=250m,memory=1Gi,ephemeral-storage=1Gi --system-reserved=cpu=250m,memory=0.5Gi,ephemeral-storage=1Gi --eviction-hard=memory.available<200Mi,nodefs.available<10%' >> /etc/kubernetes/kubelet/kubelet-config.json
        EOT
        
        tags = {
          Name = "${local.cluster_name}-general-node"
          NodeGroup = "general"
          Environment = "production"
          Purpose = "GeneralWorkloads"
          "k8s.io/cluster-autoscaler/enabled" = "true"
          "k8s.io/cluster-autoscaler/${local.cluster_name}" = "owned"
        }
      }
      
      compute = {
        name = "${local.cluster_name}-compute"
        use_name_prefix = false
        
        ami_type = "AL2_x86_64"
        platform = "linux"
        
        instance_types = ["c5.2xlarge", "c5.4xlarge", "c5n.2xlarge"]
        capacity_type = "ON_DEMAND"
        
        min_size = 0
        max_size = 10
        desired_size = 2
        
        disk_size = 100
        disk_type = "gp3"
        disk_iops = 15000
        disk_throughput = 1000
        
        labels = {
          Environment = "production"
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
        
        update_config = {
          max_unavailable = 1
        }
        
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
              iops = 15000
              throughput = 1000
              encrypted = true
              kms_key_id = dependency.kms.outputs.key_arn
              delete_on_termination = true
            }
          }
        }
        
        tags = {
          Name = "${local.cluster_name}-compute-node"
          NodeGroup = "compute"
          Environment = "production"
          Purpose = "ComputeWorkloads"
          "k8s.io/cluster-autoscaler/enabled" = "true"
          "k8s.io/cluster-autoscaler/${local.cluster_name}" = "owned"
        }
      }
    }
    
    # Production AWS Auth configuration
    aws_auth_roles = [
      {
        rolearn = "arn:aws:iam::345678901234:role/YOVKubernetesAdminRole"
        username = "yov-admin"
        groups = ["system:masters"]
      },
      {
        rolearn = "arn:aws:iam::345678901234:role/YOVKubernetesOperatorRole"
        username = "yov-operator"
        groups = ["yov:operators", "yov:developers"]
      },
      {
        rolearn = "arn:aws:iam::345678901234:role/YOVKubernetesReadOnlyRole"
        username = "yov-readonly"
        groups = ["yov:readonly"]
      }
    ]
    
    # No individual users in production - use roles only
    aws_auth_users = []
    
    # Production-specific tags
    tags = merge(
      include.envcommon.inputs.tags,
      {
        Name = local.cluster_name
        ClusterType = "production-main"
        CriticalityLevel = "critical"
        DataClassification = "confidential"
        
        # Production specific
        ProductionCluster = "true"
        MaintenanceWindow = "sun:04:00-sun:06:00"
        BackupRequired = "true"
        DRRequired = "true"
        
        # Compliance
        SOXCompliance = "required"
        PCIDSSCompliance = "level1"
        SecurityAudit = "quarterly"
        PenetrationTesting = "annual"
        
        # Operational
        OnCallTeam = "platform-team"
        EscalationContact = "platform-oncall@yov.com"
        DocumentationURL = "https://wiki.yov.com/eks/production"
        RunbookURL = "https://runbook.yov.com/eks/production"
        
        # Cost
        ChargeCode = "PROD-PLATFORM-001"
        CostOptimization = "monitor-and-optimize"
      }
    )
  }
)
