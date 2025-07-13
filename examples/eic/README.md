# EC2 Instance Connect Example

This example demonstrates how to deploy a jumphost using **EC2 Instance Connect** for SSH access.

## Overview

- **Access Method**: EC2 Instance Connect (SSH key injection)
- **Network**: Public subnet with Elastic IP
- **OS**: Amazon Linux 2023
- **Security**: SSH access from your current IP only

## Features

- ✅ **Public subnet deployment** - Instance is reachable from internet
- ✅ **Elastic IP** - Static public IP address
- ✅ **EC2 Instance Connect** - SSH access without managing keys
- ✅ **Security group** - Only allows SSH from your IP
- ✅ **Additional tools** - Installs `mtr` and `nc` for network diagnostics

## Usage

```bash
cd examples/eic
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
Internet → Elastic IP → Public Subnet → Jumphost
                                    ↓
                              Security Group (SSH from your IP)
```

## ⚠️ Important Notes

### Network Requirements

- **Public IP required** - EC2 Instance Connect requires the instance to have a public IP address
- **Direct internet access** - Instance has full inbound and outbound internet connectivity
- **Elastic IP** - Provides static public IP for consistent access

### Amazon Linux 2023

- **Package management** - Uses `dnf` instead of `yum`
- **SSM Agent** - Automatically installed and configured
- **System updates** - Handled by the user_data script

## Cleanup

```bash
terraform destroy
```

## Key Differences from Other Examples

- **Public subnet** - Instance has direct internet access
- **Elastic IP** - Static public IP address
- **EC2 Instance Connect** - No SSM agent required
- **SSH-based access** - Traditional SSH with key injection
