terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = "ap-southeast-2"
}

locals {
  name = "jumphost-demo"
  tags = {
    Environment = "dev"
  }
}

############################################################
# VPC
############################################################

module "vpc" {
  source = "cloudbuildlab/vpc/aws"

  vpc_name = local.name
  vpc_cidr = "10.0.0.0/16"

  availability_zones   = ["ap-southeast-2a", "ap-southeast-2b"]
  public_subnet_cidrs  = ["10.0.10.0/24", "10.0.11.0/24"]
  private_subnet_cidrs = ["10.0.20.0/24", "10.0.21.0/24"]

  tags = local.tags
}

data "http" "my_public_ip" {
  url = "http://ifconfig.me/ip"
}

############################################################
# Jumphost
############################################################

module "jumphost-ssm-amazonlinux2" {
  source = "../../"

  name      = "${local.name}-ssm-amazonlinux2"
  ami_type  = "amazonlinux2"
  subnet_id = module.vpc.private_subnet_ids[0]
  vpc_id    = module.vpc.vpc_id

  create_security_group = true
  allowed_cidr_blocks   = ["${data.http.my_public_ip.response_body}/32"]
  assign_eip            = false

  user_data_extra = <<-EOT
    yum install -y mtr nc
  EOT

  tags = local.tags
}

output "jumphost-ssm-amazonlinux2" {
  value = module.jumphost-ssm-amazonlinux2
}

module "jumphost-ssm-rhel8" {
  source = "../../"

  name      = "${local.name}-ssm-rhel8"
  ami_type  = "rhel8"
  subnet_id = module.vpc.private_subnet_ids[0]
  vpc_id    = module.vpc.vpc_id

  create_security_group = true
  allowed_cidr_blocks   = ["${data.http.my_public_ip.response_body}/32"]
  assign_eip            = false

  user_data_extra = <<-EOT
    dnf install -y mtr nc
  EOT

  tags = local.tags
}

output "jumphost-ssm-rhel8" {
  value = module.jumphost-ssm-rhel8
}

module "jumphost-ssm-rhel9" {
  source = "../../"

  name      = "${local.name}-ssm-rhel9"
  ami_type  = "rhel9"
  subnet_id = module.vpc.private_subnet_ids[0]
  vpc_id    = module.vpc.vpc_id

  create_security_group = true
  allowed_cidr_blocks   = ["${data.http.my_public_ip.response_body}/32"]
  assign_eip            = false

  user_data_extra = <<-EOT
    dnf install -y mtr nc
  EOT

  tags = local.tags
}

output "jumphost-ssm-rhel9" {
  value = module.jumphost-ssm-rhel9
}
