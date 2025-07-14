# terraform-aws-jumphost

Reusable Terraform module to deploy a secure, SSM-enabled EC2 jumphost in AWS

## Features

- **Multi-OS Support**: Amazon Linux 2/2023, Ubuntu 20.04, RHEL 8/9
- **SSM Integration**: Automatic SSM Agent installation and IAM permissions
- **EC2 Instance Connect**: Optional EC2 Instance Connect support for SSH access
- **Security**: Configurable security groups, encrypted volumes, IMDSv2
- **Flexible Deployment**: Public or private subnets with optional EIP
- **Red Hat Support**: Enhanced RHEL 8/9 support with repository management

## Red Hat Enterprise Linux Support

For RHEL instances, the module includes enhanced support:

- **Automatic SSM Agent**: Installs and configures AWS Systems Manager Agent using multiple fallback methods
- **Repository Management**: Optional Red Hat repository activation via `enable_redhat_repos`
- **Robust Installation**: Multiple installation methods ensure packages are installed regardless of Red Hat registration status
- **Better Error Handling**: Improved logging and error recovery

### Installation Strategy for RHEL Instances

The module uses a multi-method approach to ensure packages are installed:

1. **Default Repositories**: First tries to install from the repositories available in the RHEL AMI
2. **EPEL Repository**: Falls back to EPEL if packages aren't in default repositories
3. **AWS S3 Download**: Downloads packages directly from AWS S3 if repository installation fails
4. **Alternative Package Names**: Tries alternative package names as a last resort

This approach ensures that SSM Agent and EC2 Instance Connect are installed regardless of whether the instance is registered with Red Hat or not.

### Red Hat Repository Support

The `enable_redhat_repos` variable provides optional Red Hat repository support:

- **When enabled**: Attempts to enable Red Hat repositories if the instance is registered
- **When disabled or unregistered**: Uses default repositories that come with RHEL AMIs
- **Graceful fallback**: Continues with available repositories if Red Hat repositories are not accessible

```hcl
module "jumphost" {
  source = "path/to/module"

  ami_type = "rhel9"
  enable_redhat_repos = true  # Optional: enables Red Hat repos if registered

  # ... other configuration
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.3.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_ec2_instance_connect_endpoint.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_instance_connect_endpoint) | resource |
| [aws_eip.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip) | resource |
| [aws_iam_instance_profile.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile) | resource |
| [aws_iam_role.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.cw_agent](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.ssm_core](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_instance.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance) | resource |
| [aws_security_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_ami.selected](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) | data source |
| [aws_iam_policy_document.ec2_assume](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_allowed_cidr_blocks"></a> [allowed\_cidr\_blocks](#input\_allowed\_cidr\_blocks) | List of CIDR ranges allowed to connect via SSH when create\_security\_group = true. | `list(string)` | <pre>[<br/>  "0.0.0.0/0"<br/>]</pre> | no |
| <a name="input_ami_id_override"></a> [ami\_id\_override](#input\_ami\_id\_override) | Optional explicit AMI ID to use instead of automatic lookup. | `string` | `""` | no |
| <a name="input_ami_type"></a> [ami\_type](#input\_ami\_type) | Logical AMI type to use. Allowed: amazonlinux2, amazonlinux2023, ubuntu, rhel8, rhel9. | `string` | `"amazonlinux2"` | no |
| <a name="input_assign_eip"></a> [assign\_eip](#input\_assign\_eip) | Whether to allocate and associate an Elastic IP (valid only when subnet is public). | `bool` | `true` | no |
| <a name="input_create"></a> [create](#input\_create) | Whether to create resources. Set to false to disable the module entirely. | `bool` | `true` | no |
| <a name="input_create_security_group"></a> [create\_security\_group](#input\_create\_security\_group) | Create a dedicated security group allowing SSH/ICMP from allowed CIDRs if no security group IDs are supplied. If true, vpc\_security\_group\_ids can be empty. | `bool` | `false` | no |
| <a name="input_enable_cloudwatch_agent"></a> [enable\_cloudwatch\_agent](#input\_enable\_cloudwatch\_agent) | Install CloudWatch agent and push system logs/metrics. | `bool` | `false` | no |
| <a name="input_enable_instance_connect"></a> [enable\_instance\_connect](#input\_enable\_instance\_connect) | Install and enable EC2 Instance Connect for SSH (Amazon Linux & Ubuntu only). | `bool` | `false` | no |
| <a name="input_enable_instance_connect_endpoint"></a> [enable\_instance\_connect\_endpoint](#input\_enable\_instance\_connect\_endpoint) | Create an EC2 Instance Connect Endpoint for private subnet access (requires VPC endpoints or NAT). | `bool` | `false` | no |
| <a name="input_enable_redhat_repos"></a> [enable\_redhat\_repos](#input\_enable\_redhat\_repos) | Enable Red Hat repositories for RHEL instances (requires manual registration after deployment). If false, uses default repositories that come with RHEL AMIs. | `bool` | `false` | no |
| <a name="input_enable_ssm"></a> [enable\_ssm](#input\_enable\_ssm) | Enable SSM Agent and permissions via instance profile. | `bool` | `true` | no |
| <a name="input_iam_instance_profile_name"></a> [iam\_instance\_profile\_name](#input\_iam\_instance\_profile\_name) | Existing IAM instance profile to attach instead of creating one. | `string` | `""` | no |
| <a name="input_instance_connect_endpoint_subnet_id"></a> [instance\_connect\_endpoint\_subnet\_id](#input\_instance\_connect\_endpoint\_subnet\_id) | Subnet ID for the EC2 Instance Connect Endpoint (should be private with NAT or VPC endpoints). | `string` | `""` | no |
| <a name="input_instance_type"></a> [instance\_type](#input\_instance\_type) | EC2 instance type. | `string` | `"t3.micro"` | no |
| <a name="input_kms_key_id"></a> [kms\_key\_id](#input\_kms\_key\_id) | KMS key ID for EBS encryption (optional). | `string` | `""` | no |
| <a name="input_name"></a> [name](#input\_name) | Base name used for resource naming and tagging. | `string` | `"jumphost"` | no |
| <a name="input_patch_and_reboot"></a> [patch\_and\_reboot](#input\_patch\_and\_reboot) | If true, the instance will perform OS update and automatically reboot once during user\_data. | `bool` | `false` | no |
| <a name="input_root_volume_encrypted"></a> [root\_volume\_encrypted](#input\_root\_volume\_encrypted) | Whether the root EBS volume should be encrypted. | `bool` | `true` | no |
| <a name="input_root_volume_size"></a> [root\_volume\_size](#input\_root\_volume\_size) | Root EBS volume size in GiB. | `number` | `20` | no |
| <a name="input_root_volume_type"></a> [root\_volume\_type](#input\_root\_volume\_type) | Root EBS volume type. | `string` | `"gp3"` | no |
| <a name="input_subnet_id"></a> [subnet\_id](#input\_subnet\_id) | Subnet ID in which to launch the instance (public or private with outbound internet/SSM access). | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Additional tags to apply to all resources. | `map(string)` | `{}` | no |
| <a name="input_user_data_extra"></a> [user\_data\_extra](#input\_user\_data\_extra) | Additional user\_data shell commands appended to the module's base user\_data. | `string` | `""` | no |
| <a name="input_user_data_override"></a> [user\_data\_override](#input\_user\_data\_override) | Completely override the generated user\_data with your own script (cloud-init or shell). | `string` | `""` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | Optional VPC ID – used only for tagging or looking up endpoints. | `string` | `""` | no |
| <a name="input_vpc_security_group_ids"></a> [vpc\_security\_group\_ids](#input\_vpc\_security\_group\_ids) | List of security group IDs to attach to the instance. | `list(string)` | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_instance_connect_command"></a> [instance\_connect\_command](#output\_instance\_connect\_command) | Convenience AWS CLI command to connect via EC2 Instance Connect (when enabled). |
| <a name="output_instance_connect_endpoint_dns_name"></a> [instance\_connect\_endpoint\_dns\_name](#output\_instance\_connect\_endpoint\_dns\_name) | DNS name of the EC2 Instance Connect Endpoint (if created). |
| <a name="output_instance_connect_endpoint_id"></a> [instance\_connect\_endpoint\_id](#output\_instance\_connect\_endpoint\_id) | ID of the EC2 Instance Connect Endpoint (if created). |
| <a name="output_instance_id"></a> [instance\_id](#output\_instance\_id) | ID of the jumphost instance. |
| <a name="output_private_ip"></a> [private\_ip](#output\_private\_ip) | Private IP address of the instance. |
| <a name="output_public_dns"></a> [public\_dns](#output\_public\_dns) | Public DNS name of the instance, if available. |
| <a name="output_public_ip"></a> [public\_ip](#output\_public\_ip) | Public IP address (or EIP) of the instance, if assigned. |
| <a name="output_security_group_id"></a> [security\_group\_id](#output\_security\_group\_id) | ID of the created security group (if any). |
| <a name="output_ssm_session_command"></a> [ssm\_session\_command](#output\_ssm\_session\_command) | Convenience AWS CLI command to open an SSM session to the instance. |
<!-- END_TF_DOCS -->
