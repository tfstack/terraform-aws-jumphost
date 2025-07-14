#!/bin/bash
exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1
set -o nounset -o pipefail

echo "Starting user_data script execution for RHEL 9..."

# Get AWS region from instance metadata
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
AWS_REGION=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/placement/region)
echo "AWS Region: $AWS_REGION"

%{ if enable_ssm ~}
# Install & enable SSM Agent
echo "Installing SSM Agent for RHEL 9..."
mkdir -p /tmp/ssm
cd /tmp/ssm
curl -O "https://s3.$${AWS_REGION}.amazonaws.com/amazon-ssm-$${AWS_REGION}/latest/linux_amd64/amazon-ssm-agent.rpm"
dnf install -y amazon-ssm-agent.rpm
systemctl enable --now amazon-ssm-agent

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
cd /
%{ endif ~}

%{ if enable_instance_connect ~}
# Install EC2 Instance Connect
echo "Installing EC2 Instance Connect for RHEL 9..."
mkdir -p /tmp/ec2-instance-connect
cd /tmp/ec2-instance-connect
curl -O "https://amazon-ec2-instance-connect-$${AWS_REGION}.s3.$${AWS_REGION}.amazonaws.com/latest/linux_amd64/ec2-instance-connect.rpm"
curl -O "https://amazon-ec2-instance-connect-$${AWS_REGION}.s3.$${AWS_REGION}.amazonaws.com/latest/linux_amd64/ec2-instance-connect-selinux.noarch.rpm"
dnf install -y ec2-instance-connect.rpm ec2-instance-connect-selinux.rpm

# Configure SSH for EC2 Instance Connect
echo "Configuring SSH for EC2 Instance Connect..."
echo 'AuthorizedKeysCommand /opt/aws/bin/eic_run_authorized_keys %u %f' >>/etc/ssh/sshd_config
echo 'AuthorizedKeysCommandUser ec2-user' >>/etc/ssh/sshd_config
restorecon -v /opt/aws/bin/eic_run_authorized_keys
systemctl restart sshd
cd /
%{ endif ~}

%{ if enable_cloudwatch_agent ~}
# Install CloudWatch Agent
echo "Installing CloudWatch Agent..."
mkdir -p /tmp/cloudwatch-agent
cd /tmp/cloudwatch-agent
curl -O "https://s3.$${AWS_REGION}.amazonaws.com/amazoncloudwatch-agent-$${AWS_REGION}/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm"
dnf install -y amazon-cloudwatch-agent.rpm
systemctl enable amazon-cloudwatch-agent
%{ endif ~}

echo "User data script execution completed."
