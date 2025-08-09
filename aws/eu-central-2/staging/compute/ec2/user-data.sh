#!/bin/bash
# =============================================================================
# STAGING EC2 USER DATA SCRIPT
# =============================================================================
# Initial setup script for staging EC2 instances

# Variables
ENVIRONMENT="${environment}"
REGION="${region}"

# Update system
yum update -y

# Install essential packages
yum install -y \
    docker \
    git \
    curl \
    wget \
    htop \
    tree \
    jq \
    aws-cli \
    amazon-cloudwatch-agent

# Start and enable Docker
systemctl start docker
systemctl enable docker
usermod -a -G docker ec2-user

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Install Node.js (for web applications)
curl -fsSL https://rpm.nodesource.com/setup_lts.x | bash -
yum install -y nodejs

# Install Python 3 and pip
yum install -y python3 python3-pip

# Configure CloudWatch agent (basic configuration)
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << EOF
{
    "agent": {
        "metrics_collection_interval": 60,
        "run_as_user": "cwagent"
    },
    "metrics": {
        "namespace": "CWAgent",
        "metrics_collected": {
            "cpu": {
                "measurement": [
                    "cpu_usage_idle",
                    "cpu_usage_iowait",
                    "cpu_usage_user",
                    "cpu_usage_system"
                ],
                "metrics_collection_interval": 60,
                "totalcpu": false
            },
            "disk": {
                "measurement": [
                    "used_percent"
                ],
                "metrics_collection_interval": 60,
                "resources": [
                    "*"
                ]
            },
            "diskio": {
                "measurement": [
                    "io_time"
                ],
                "metrics_collection_interval": 60,
                "resources": [
                    "*"
                ]
            },
            "mem": {
                "measurement": [
                    "mem_used_percent"
                ],
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
                        "log_group_name": "/aws/ec2/staging",
                        "log_stream_name": "{instance_id}/messages"
                    },
                    {
                        "file_path": "/var/log/secure",
                        "log_group_name": "/aws/ec2/staging",
                        "log_stream_name": "{instance_id}/secure"
                    }
                ]
            }
        }
    }
}
EOF

# Start CloudWatch agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config \
    -m ec2 \
    -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
    -s

# Create staging user for deployments
useradd -m -s /bin/bash staging
usermod -a -G docker staging

# Set up SSH key directory for staging user
mkdir -p /home/staging/.ssh
chmod 700 /home/staging/.ssh
chown staging:staging /home/staging/.ssh

# Create application directory
mkdir -p /opt/staging-app
chown staging:staging /opt/staging-app

# Set up environment variables
cat > /etc/environment << EOF
ENVIRONMENT=$ENVIRONMENT
REGION=$REGION
NODE_ENV=staging
EOF

# Set up log rotation
cat > /etc/logrotate.d/staging-app << EOF
/opt/staging-app/logs/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 644 staging staging
}
EOF

# Install and configure fail2ban for security
yum install -y epel-release
yum install -y fail2ban

systemctl enable fail2ban
systemctl start fail2ban

# Set up basic firewall rules (in addition to security groups)
cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3

[sshd]
enabled = true
port = ssh
logpath = /var/log/secure
EOF

systemctl restart fail2ban

# Signal that user data script has completed
/opt/aws/bin/cfn-signal -e $? --stack staging-euc2-stack --resource StagingEC2Instance --region $REGION

echo "Staging EC2 instance setup completed at $(date)" >> /var/log/user-data.log
