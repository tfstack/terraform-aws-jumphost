#############################
# Locals
#############################

locals {
  # Map of owners for AMI lookup
  ami_owners = {
    amazonlinux2    = "amazon"
    amazonlinux2023 = "amazon"
    ubuntu          = "099720109477" # Canonical
    rhel8           = "309956199498" # Red Hat
    rhel9           = "309956199498" # Red Hat
  }

  # Name patterns used for AMI lookup
  ami_name_patterns = {
    amazonlinux2    = "amzn2-ami-hvm-*x86_64-gp2"
    amazonlinux2023 = "al2023-ami-*-x86_64*"
    ubuntu          = "ubuntu/images/hvm-ssd/ubuntu-*-20.04-amd64-server-*"
    rhel8           = "RHEL-8.*_HVM-*x86_64*"
    rhel9           = "RHEL-9.*_HVM-*x86_64*"
  }

  # Tags applied to all resources
  common_tags = merge({
    Name   = var.name,
    Module = "terraform-aws-jumphost",
  }, var.tags)
}

data "aws_region" "current" {}

#############################
# AMI lookup (optional)
#############################

data "aws_ami" "selected" {
  count       = var.ami_id_override == "" ? 1 : 0
  most_recent = true

  owners = [local.ami_owners[var.ami_type]]

  filter {
    name   = "name"
    values = [local.ami_name_patterns[var.ami_type]]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Resolve the AMI ID, preferring the override
locals {
  ami_id = var.ami_id_override != "" ? var.ami_id_override : (var.ami_id_override == "" ? data.aws_ami.selected[0].id : null)
}

#############################
# IAM (optional)
#############################

data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  count              = (var.enable_ssm || var.enable_cloudwatch_agent) && var.iam_instance_profile_name == "" && var.create ? 1 : 0
  name               = "${var.name}-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
  tags               = local.common_tags
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  count      = var.enable_ssm && var.iam_instance_profile_name == "" && var.create ? 1 : 0
  role       = aws_iam_role.this[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cw_agent" {
  count      = var.enable_cloudwatch_agent && var.iam_instance_profile_name == "" && var.create ? 1 : 0
  role       = aws_iam_role.this[0].name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "this" {
  count = var.iam_instance_profile_name == "" && (var.enable_ssm || var.enable_cloudwatch_agent) && var.create ? 1 : 0
  name  = "${var.name}-profile"
  role  = aws_iam_role.this[0].name
  tags  = local.common_tags
}

#############################
# Security Group (optional)
#############################

resource "aws_security_group" "this" {
  count = var.create_security_group && var.create ? 1 : 0

  name        = "${var.name}-sg"
  description = "Jumphost security group allowing SSH access"
  vpc_id      = var.vpc_id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  # Allow HTTPS for AWS SSM (when enabled)
  dynamic "ingress" {
    for_each = var.enable_ssm ? [1] : []
    content {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow HTTPS for AWS Systems Manager"
    }
  }

  ingress {
    description = "ICMP (ping)"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.common_tags
}

#############################
# EC2 Instance Connect Endpoint (optional)
#############################

resource "aws_ec2_instance_connect_endpoint" "this" {
  count = var.enable_instance_connect_endpoint && var.create ? 1 : 0

  subnet_id = var.instance_connect_endpoint_subnet_id

  tags = merge(local.common_tags, {
    Name = "${var.name}-eice"
  })
}

#############################
# Derived locals
#############################

locals {
  instance_profile_name = var.iam_instance_profile_name != "" ? var.iam_instance_profile_name : ((var.enable_ssm || var.enable_cloudwatch_agent) ? aws_iam_instance_profile.this[0].name : null)

  effective_security_group_ids = (
    var.create_security_group ? (
      length(var.vpc_security_group_ids) > 0 ? concat(var.vpc_security_group_ids, [aws_security_group.this[0].id]) : [aws_security_group.this[0].id]
    ) : var.vpc_security_group_ids
  )
}

#############################
# User data
#############################

locals {
  base_user_data = <<-EOT
    #!/bin/bash
    exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1
    set -o nounset -o pipefail

    echo "Starting user_data script execution..."

    # Determine distro ID
    DISTRO_ID=$(awk -F= '$1=="ID"{print $2}' /etc/os-release | tr -d '"')
    echo "Detected distro ID: $DISTRO_ID"

    # Get AWS region from instance metadata
    AWS_REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
    echo "AWS Region: $AWS_REGION"

    # Test network connectivity
    echo "Testing network connectivity..."
    if ! curl -s --connect-timeout 10 https://www.google.com > /dev/null; then
      echo "WARNING: No internet connectivity detected"
    else
      echo "Internet connectivity confirmed"
    fi

    # Basic system update (don't fail on errors)
    echo "Performing system updates..."
    if command -v dnf >/dev/null 2>&1; then
      dnf update -y || echo "System update failed, continuing..."
    elif command -v yum >/dev/null 2>&1; then
      yum update -y || echo "System update failed, continuing..."
    elif command -v apt-get >/dev/null 2>&1; then
      apt-get update -y && apt-get upgrade -y || echo "System update failed, continuing..."
    fi

    # Install & enable SSM Agent
    echo "Installing SSM Agent..."
    case "$DISTRO_ID" in
      amzn)
        echo "Installing SSM Agent for Amazon Linux..."
        if grep -q '2023' /etc/os-release; then
          dnf install -y amazon-ssm-agent || echo "SSM Agent installation failed"
        else
          yum install -y amazon-ssm-agent || echo "SSM Agent installation failed"
        fi
        systemctl enable --now amazon-ssm-agent || echo "Failed to enable SSM Agent"
        ;;
      rhel)
        echo "Installing SSM Agent for RedHat..."
        mkdir -p /tmp/ssm
        cd /tmp/ssm
        # Use current region instead of hardcoded us-west-2
        curl -O "https://s3.$${AWS_REGION}.amazonaws.com/amazon-ssm-$${AWS_REGION}/latest/linux_amd64/amazon-ssm-agent.rpm" || echo "Failed to download SSM Agent RPM"
        if [ -f amazon-ssm-agent.rpm ]; then
          dnf install -y amazon-ssm-agent.rpm || echo "SSM Agent RPM installation failed"
          systemctl enable --now amazon-ssm-agent || echo "Failed to enable SSM Agent"
        else
          echo "SSM Agent RPM not found, trying alternative installation..."
          # Alternative: try to install from AWS Systems Manager
          dnf install -y amazon-ssm-agent || echo "Alternative SSM Agent installation failed"
          systemctl enable --now amazon-ssm-agent || echo "Failed to enable SSM Agent"
        fi
        ;;
      ubuntu|debian)
        echo "Installing SSM Agent for Ubuntu/Debian..."
        apt-get update -y
        apt-get install -y snapd
        snap install amazon-ssm-agent --classic || echo "SSM Agent snap installation failed"
        systemctl enable --now snap.amazon-ssm-agent.amazon-ssm-agent.service || echo "Failed to enable SSM Agent"
        ;;
      *)
        echo "Unsupported distro ID: $DISTRO_ID"
        ;;
    esac

    # Wait for SSM agent to be active
    echo "Waiting for SSM Agent to become active..."
    for i in {1..30}; do
      if systemctl is-active --quiet amazon-ssm-agent || \
         systemctl is-active --quiet snap.amazon-ssm-agent.amazon-ssm-agent.service; then
        echo "SSM Agent is active"
        break
      fi
      echo "Waiting for SSM Agent... attempt $i/30"
      sleep 2
    done

    # Optionally install EC2 Instance Connect
    if [ "${var.enable_instance_connect}" = "true" ]; then
      echo "Installing EC2 Instance Connect..."
      if command -v yum >/dev/null 2>&1 || command -v dnf >/dev/null 2>&1; then
        # For RedHat 8/9, install from S3
        if [ "$DISTRO_ID" = "rhel" ]; then
          echo "Installing EC2 Instance Connect for RedHat..."
          mkdir -p /tmp/ec2-instance-connect
          cd /tmp/ec2-instance-connect
          # Use current region instead of hardcoded us-west-2
          curl "https://amazon-ec2-instance-connect-$${AWS_REGION}.s3.$${AWS_REGION}.amazonaws.com/latest/linux_amd64/ec2-instance-connect.rpm" -o ec2-instance-connect.rpm || echo "Failed to download EC2 Instance Connect RPM"
          curl "https://amazon-ec2-instance-connect-$${AWS_REGION}.s3.$${AWS_REGION}.amazonaws.com/latest/linux_amd64/ec2-instance-connect-selinux.noarch.rpm" -o ec2-instance-connect-selinux.rpm || echo "Failed to download EC2 Instance Connect SELinux RPM"

          if [ -f ec2-instance-connect.rpm ] && [ -f ec2-instance-connect-selinux.rpm ]; then
            dnf install -y ec2-instance-connect.rpm ec2-instance-connect-selinux.rpm || echo "EC2 Instance Connect installation failed"

            # Patch sshd config to allow EC2 Instance Connect
            echo "Configuring SSH for EC2 Instance Connect..."
            echo 'AuthorizedKeysCommand /opt/aws/bin/eic_run_authorized_keys %u %f' >> /etc/ssh/sshd_config
            echo 'AuthorizedKeysCommandUser ec2-user' >> /etc/ssh/sshd_config
            restorecon -v /opt/aws/bin/eic_run_authorized_keys || echo "Failed to restore SELinux context"
            systemctl restart sshd || echo "Failed to restart SSH daemon"
          else
            echo "EC2 Instance Connect RPMs not found, trying alternative installation..."
            dnf install -y ec2-instance-connect || echo "Alternative EC2 Instance Connect installation failed"
          fi
        else
          echo "Installing EC2 Instance Connect for other distros..."
          (yum install -y ec2-instance-connect || dnf install -y ec2-instance-connect) || echo "EC2 Instance Connect installation failed"
        fi
      elif command -v apt-get >/dev/null 2>&1; then
        echo "Installing EC2 Instance Connect for Debian/Ubuntu..."
        apt-get install -y ec2-instance-connect || echo "EC2 Instance Connect installation failed"
      fi
    fi

    # Optionally install CloudWatch Agent
    if [ "${var.enable_cloudwatch_agent}" = "true" ]; then
      echo "Installing CloudWatch Agent..."
      mkdir -p /opt/aws/amazon-cloudwatch-agent/etc
      if command -v yum >/dev/null 2>&1 || command -v dnf >/dev/null 2>&1; then
        (yum install -y amazon-cloudwatch-agent || dnf install -y amazon-cloudwatch-agent) || echo "CloudWatch Agent installation failed"
      elif command -v apt-get >/dev/null 2>&1; then
        apt-get install -y amazon-cloudwatch-agent || echo "CloudWatch Agent installation failed"
      fi
      systemctl enable amazon-cloudwatch-agent || echo "Failed to enable CloudWatch Agent"
    fi

    # Optional reboot after patching
    if [ "${var.patch_and_reboot}" = "true" ]; then
      echo "Scheduling reboot in 10 seconds..."
      (sleep 10 && reboot -f) &
    fi

    echo "User data script execution completed."
  EOT

  user_data_final = var.user_data_override != "" ? var.user_data_override : "${trimspace(local.base_user_data)}\n${var.user_data_extra}"
}

#############################
# EC2 Instance
#############################

resource "aws_instance" "this" {
  count         = var.create ? 1 : 0
  ami           = local.ami_id
  instance_type = var.instance_type
  subnet_id     = var.subnet_id

  vpc_security_group_ids      = local.effective_security_group_ids
  iam_instance_profile        = local.instance_profile_name
  associate_public_ip_address = var.assign_eip
  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    encrypted   = var.root_volume_encrypted
    volume_size = var.root_volume_size
    volume_type = var.root_volume_type
    kms_key_id  = var.kms_key_id != "" ? var.kms_key_id : null
  }

  user_data_base64 = base64encode(local.user_data_final)

  tags = merge(local.common_tags, {
    Hostname = var.name
  })
}

#############################
# Elastic IP (optional)
#############################

resource "aws_eip" "this" {
  count  = var.create && var.assign_eip ? 1 : 0
  domain = "vpc"

  instance = aws_instance.this[0].id
  tags     = local.common_tags
}
