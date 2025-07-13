# EC2 Instance Connect Endpoint Example

This example demonstrates how to deploy a jumphost using **EC2 Instance Connect Endpoint** for private subnet access.

## Overview

- **Access Method**: EC2 Instance Connect Endpoint + SSH
- **Network**: Private subnet (no direct internet access)
- **OS**: Ubuntu 20.04
- **Security**: SSH access via VPC endpoint

## Features

✅ **Private subnet deployment** - Instance is isolated from internet
✅ **EC2 Instance Connect Endpoint** - VPC endpoint for SSH access
✅ **No Elastic IP** - Instance stays private
✅ **Security group** - Only allows SSH from your IP
✅ **Additional tools** - Installs `mtr` and `netcat` for diagnostics

## Usage

```bash
cd examples/eice
terraform init
terraform apply
```

## Connecting

After deployment, connect using:

```bash
# Get the instance ID from outputs
aws ec2-instance-connect ssh --instance-id <instance-id> --region ap-southeast-2
```

## Architecture

```plaintext
Your IP → EC2 Instance Connect Endpoint → Private Subnet → Jumphost
                                                      ↓
                                                Security Group (SSH)
```

## Requirements

- **VPC with private subnets** - Created by the VPC module
- **Outbound internet access** - Instance needs internet access for package updates
- **EC2 Instance Connect Endpoint** - Created by the module

## ⚠️ Important Notes

### EC2 Instance Connect Endpoint Limitations

- **One endpoint per VPC** - Only one EC2 Instance Connect Endpoint can exist per VPC
- **Shared resource** - Multiple jumphosts in the same VPC will share the same endpoint
- **Deployment order** - First deployment creates the endpoint, subsequent deployments will fail if endpoint already exists

### Network Requirements

- **Outbound internet access** - Instance needs internet access for package updates
- **Private subnet** - Instance has no direct inbound internet access (more secure)

## Cleanup

```bash
terraform destroy
```

## Key Differences from Other Examples

- **Private subnet** - Instance has no direct inbound internet access
- **EC2 Instance Connect Endpoint** - VPC endpoint for SSH access
- **No SSM agent** - Pure SSH-based access
- **Ubuntu OS** - Different package management
- **Network isolation** - More secure deployment pattern
