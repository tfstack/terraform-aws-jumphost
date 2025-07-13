#!/bin/bash
exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1
set -o nounset -o pipefail

echo "Starting user_data script execution for Amazon Linux 2..."

# Get AWS region from instance metadata
AWS_REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
echo "AWS Region: $AWS_REGION"

# Test network connectivity
echo "Testing network connectivity..."
if ! curl -s --connect-timeout 10 https://www.google.com >/dev/null; then
    echo "WARNING: No internet connectivity detected"
else
    echo "Internet connectivity confirmed"
fi

# Basic system update
echo "Performing system updates..."
yum update -y || echo "System update failed, continuing..."

%{ if enable_ssm ~}
# Install & enable SSM Agent
echo "Installing SSM Agent for Amazon Linux 2..."
yum install -y amazon-ssm-agent || echo "SSM Agent installation failed"
systemctl enable --now amazon-ssm-agent || echo "Failed to enable SSM Agent"

# Wait for SSM agent to be active
echo "Waiting for SSM Agent to become active..."
for i in {1..30}; do
    if systemctl is-active --quiet amazon-ssm-agent; then
        echo "SSM Agent is active"
        break
    fi
    echo "Waiting for SSM Agent... attempt $i/30"
    sleep 2
done
%{ endif ~}

%{ if enable_instance_connect ~}
# Install EC2 Instance Connect
echo "Installing EC2 Instance Connect for Amazon Linux 2..."
yum install -y ec2-instance-connect || echo "EC2 Instance Connect installation failed"
%{ endif ~}

%{ if enable_cloudwatch_agent ~}
# Install CloudWatch Agent
echo "Installing CloudWatch Agent..."
mkdir -p /opt/aws/amazon-cloudwatch-agent/etc
yum install -y amazon-cloudwatch-agent || echo "CloudWatch Agent installation failed"
systemctl enable amazon-cloudwatch-agent || echo "Failed to enable CloudWatch Agent"
%{ endif ~}

# Additional user commands
${user_data_extra}

%{ if patch_and_reboot ~}
# Reboot after patching
echo "Scheduling reboot in 10 seconds..."
(sleep 10 && reboot -f) &
%{ endif ~}

echo "User data script execution completed."
