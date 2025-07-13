#############################
# Locals
#############################

locals {
  # Map of owners for AMI lookup
  ami_owners = {
    amazonlinux2    = "amazon"
    amazonlinux2023 = "amazon"
    ubuntu          = "099720109477" # Canonical
  }

  # Name patterns used for AMI lookup
  ami_name_patterns = {
    amazonlinux2    = "amzn2-ami-hvm-*x86_64-gp2"
    amazonlinux2023 = "al2023-ami-*-x86_64*"
    ubuntu          = "ubuntu/images/hvm-ssd/ubuntu-*-20.04-amd64-server-*"
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
    set -o errexit -o nounset -o pipefail

    # Determine distro ID
    DISTRO_ID=$(awk -F= '$1=="ID"{print $2}' /etc/os-release | tr -d '"')

    # Basic system update
    if command -v dnf >/dev/null 2>&1; then
      dnf update -y
    elif command -v yum >/dev/null 2>&1; then
      yum update -y
    elif command -v apt-get >/dev/null 2>&1; then
      apt-get update -y && apt-get upgrade -y
    fi

    # Install & enable SSM Agent
    case "$DISTRO_ID" in
      amzn)
        # Handle Amazon Linux 2 and 2023
        if grep -q '2023' /etc/os-release; then
          dnf install -y amazon-ssm-agent
        else
          yum install -y amazon-ssm-agent
        fi
        systemctl enable --now amazon-ssm-agent
        ;;
      ubuntu|debian)
        apt-get update -y
        apt-get install -y snapd
        snap install amazon-ssm-agent --classic
        systemctl enable --now snap.amazon-ssm-agent.amazon-ssm-agent.service
        ;;
      *)
        echo "Unsupported distro ID: $DISTRO_ID"
        ;;
    esac

    # Wait for SSM agent to be active
    for i in {1..30}; do
      if systemctl is-active --quiet amazon-ssm-agent || \
         systemctl is-active --quiet snap.amazon-ssm-agent.amazon-ssm-agent.service; then
        echo "SSM Agent is active"
        break
      fi
      sleep 2
    done

    # Optionally install EC2 Instance Connect
    if [ "${var.enable_instance_connect}" = "true" ]; then
      if command -v yum >/dev/null 2>&1 || command -v dnf >/dev/null 2>&1; then
        (yum install -y ec2-instance-connect || dnf install -y ec2-instance-connect) || true
      elif command -v apt-get >/dev/null 2>&1; then
        apt-get install -y ec2-instance-connect || true
      fi
    fi

    # Optionally install CloudWatch Agent
    if [ "${var.enable_cloudwatch_agent}" = "true" ]; then
      mkdir -p /opt/aws/amazon-cloudwatch-agent/etc
      if command -v yum >/dev/null 2>&1 || command -v dnf >/dev/null 2>&1; then
        (yum install -y amazon-cloudwatch-agent || dnf install -y amazon-cloudwatch-agent) || true
      elif command -v apt-get >/dev/null 2>&1; then
        apt-get install -y amazon-cloudwatch-agent || true
      fi
      systemctl enable amazon-cloudwatch-agent || true
    fi

    # Optional reboot after patching
    if [ "${var.patch_and_reboot}" = "true" ]; then
      (sleep 10 && reboot -f) &
    fi
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
