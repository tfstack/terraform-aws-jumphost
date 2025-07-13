#############################
# Core configuration
#############################

variable "create" {
  description = "Whether to create resources. Set to false to disable the module entirely."
  type        = bool
  default     = true
}

variable "name" {
  description = "Base name used for resource naming and tagging."
  type        = string
  default     = "jumphost"
}

variable "ami_type" {
  description = "Logical AMI type to use. Allowed: amazonlinux2, amazonlinux2023, ubuntu, rhel8, rhel9."
  type        = string
  default     = "amazonlinux2"
  validation {
    condition     = contains(["amazonlinux2", "amazonlinux2023", "ubuntu", "rhel8", "rhel9"], lower(var.ami_type))
    error_message = "ami_type must be one of: amazonlinux2, amazonlinux2023, ubuntu, rhel8, rhel9."
  }
}

variable "ami_id_override" {
  description = "Optional explicit AMI ID to use instead of automatic lookup."
  type        = string
  default     = ""
}

variable "instance_type" {
  description = "EC2 instance type."
  type        = string
  default     = "t3.micro"
}

variable "subnet_id" {
  description = "Subnet ID in which to launch the instance (public or private with outbound internet/SSM access)."
  type        = string
}

variable "vpc_security_group_ids" {
  description = "List of security group IDs to attach to the instance."
  type        = list(string)
  default     = []
}

variable "vpc_id" {
  description = "Optional VPC ID – used only for tagging or looking up endpoints."
  type        = string
  default     = ""
}

variable "assign_eip" {
  description = "Whether to allocate and associate an Elastic IP (valid only when subnet is public)."
  type        = bool
  default     = true
}

variable "root_volume_size" {
  description = "Root EBS volume size in GiB."
  type        = number
  default     = 20
}

variable "root_volume_type" {
  description = "Root EBS volume type."
  type        = string
  default     = "gp3"
}

variable "root_volume_encrypted" {
  description = "Whether the root EBS volume should be encrypted."
  type        = bool
  default     = true
}

variable "kms_key_id" {
  description = "KMS key ID for EBS encryption (optional)."
  type        = string
  default     = ""
}

variable "enable_ssm" {
  description = "Enable SSM Agent and permissions via instance profile."
  type        = bool
  default     = true
}

variable "enable_instance_connect" {
  description = "Install and enable EC2 Instance Connect for SSH (Amazon Linux & Ubuntu only)."
  type        = bool
  default     = false
}

variable "iam_instance_profile_name" {
  description = "Existing IAM instance profile to attach instead of creating one."
  type        = string
  default     = ""
}

variable "enable_cloudwatch_agent" {
  description = "Install CloudWatch agent and push system logs/metrics."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Additional tags to apply to all resources."
  type        = map(string)
  default     = {}
}

variable "create_security_group" {
  description = "Create a dedicated security group allowing SSH/ICMP from allowed CIDRs if no security group IDs are supplied. If true, vpc_security_group_ids can be empty."
  type        = bool
  default     = false
}

variable "allowed_cidr_blocks" {
  description = "List of CIDR ranges allowed to connect via SSH when create_security_group = true."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "user_data_override" {
  description = "Completely override the generated user_data with your own script (cloud-init or shell)."
  type        = string
  default     = ""
}

variable "user_data_extra" {
  description = "Additional user_data shell commands appended to the module's base user_data."
  type        = string
  default     = ""
}

variable "patch_and_reboot" {
  description = "If true, the instance will perform OS update and automatically reboot once during user_data."
  type        = bool
  default     = false
}

variable "enable_instance_connect_endpoint" {
  description = "Create an EC2 Instance Connect Endpoint for private subnet access (requires VPC endpoints or NAT)."
  type        = bool
  default     = false
}

variable "instance_connect_endpoint_subnet_id" {
  description = "Subnet ID for the EC2 Instance Connect Endpoint (should be private with NAT or VPC endpoints)."
  type        = string
  default     = ""
}
