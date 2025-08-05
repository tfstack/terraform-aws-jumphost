output "instance_id" {
  description = "ID of the jumphost instance."
  value       = try(aws_instance.this[0].id, null)
}

output "public_ip" {
  description = "Public IP address (or EIP) of the instance, if assigned."
  value       = var.assign_eip ? (try(aws_eip.this[0].public_ip, null)) : try(aws_instance.this[0].public_ip, null)
}

output "public_dns" {
  description = "Public DNS name of the instance, if available."
  value       = try(aws_instance.this[0].public_dns, null)
}

output "ssm_session_command" {
  description = "Convenience AWS CLI command to open an SSM session to the instance."
  value       = "aws ssm start-session --target=${try(aws_instance.this[0].id, "")} --region=${data.aws_region.current.region}"
}

output "private_ip" {
  description = "Private IP address of the instance."
  value       = try(aws_instance.this[0].private_ip, null)
}

output "security_group_id" {
  description = "ID of the created security group (if any)."
  value       = try(aws_security_group.this[0].id, null)
}

output "instance_connect_endpoint_id" {
  description = "ID of the EC2 Instance Connect Endpoint (if created)."
  value       = try(aws_ec2_instance_connect_endpoint.this[0].id, null)
}

output "instance_connect_endpoint_dns_name" {
  description = "DNS name of the EC2 Instance Connect Endpoint (if created)."
  value       = try(aws_ec2_instance_connect_endpoint.this[0].dns_name, null)
}

output "instance_connect_command" {
  description = "Convenience AWS CLI command to connect via EC2 Instance Connect (when enabled)."
  value       = var.enable_instance_connect ? "aws ec2-instance-connect ssh --instance-id ${try(aws_instance.this[0].id, "")} --region ${data.aws_region.current.region}" : null
}

output "iam_role_arn" {
  description = "ARN of the IAM role created for the jumphost (if created)."
  value       = try(aws_iam_role.this[0].arn, null)
}

output "iam_role_name" {
  description = "Name of the IAM role created for the jumphost (if created)."
  value       = try(aws_iam_role.this[0].name, null)
}

output "iam_instance_profile_arn" {
  description = "ARN of the IAM instance profile created for the jumphost (if created)."
  value       = try(aws_iam_instance_profile.this[0].arn, null)
}

output "iam_instance_profile_name" {
  description = "Name of the IAM instance profile created for the jumphost (if created)."
  value       = try(aws_iam_instance_profile.this[0].name, null)
}
