# SSM Session Manager Example

This example demonstrates how to deploy a jumphost using **AWS Systems Manager Session Manager** for secure access.

## Overview

- **Access Method**: SSM Session Manager (no inbound ports)
- **Network**: Private subnet (no direct internet access)
- **OS**: Amazon Linux 2, RHEL 8, RHEL 9
- **Security**: No inbound SSH required

## Features

- ✅ **Private subnet deployment** - Instance is isolated from internet
- ✅ **SSM Session Manager** - Secure access without SSH keys
- ✅ **No Elastic IP** - Instance stays private
- ✅ **Security group** - Only allows SSH from your IP (for backup)
- ✅ **SSM Agent** - Automatically installed and configured
- ✅ **Additional tools** - Installs `mtr` and `nc` for diagnostics

## Usage

```bash
cd examples/ssm
terraform init
terraform apply
```

## Connecting

After deployment, connect using:

```bash
# Get the instance ID from outputs
aws ssm start-session --target <instance-id> --region ap-southeast-2
```

## Architecture

```plaintext
Your IP → SSM Service → Private Subnet → Jumphost
                                    ↓
                              Security Group (SSH backup)
```

## Requirements

- **VPC with private subnets** - Created by the VPC module
- **Outbound internet access** - Instance needs internet access for SSM agent connectivity
- **SSM Agent** - Automatically installed by the module
- **IAM Role** - Created with SSM permissions

## ⚠️ Important Notes

### Supported Operating Systems

#### Amazon Linux 2 Support

- **Package management** - Uses `yum` for package installation
- **SSM Agent** - Pre-installed but reinstalled for reliability
- **System updates** - Handled by the user_data script

#### RHEL 8 & 9 Support

- **Package management** - Uses `dnf` for package installation
- **SSM Agent** - Downloaded from AWS S3 and installed manually
- **System updates** - **Not available** due to Red Hat subscription requirements
- **Package installation** - Limited to packages available in default repositories or manually downloaded from S3

### Red Hat Limitations

⚠️ **Important**: RHEL instances have significant limitations:

- **No system updates** - `dnf update` requires Red Hat subscription
- **Limited package installation** - Can only install packages from default repositories or manually downloaded RPMs
- **SSM Agent** - Must be downloaded from AWS S3 (not available in default repositories)
- **Additional packages** - May need to be downloaded manually from S3 or alternative sources

### Network Requirements

- **Outbound internet access** - Instance needs internet access for SSM connectivity

## Cleanup

```bash
terraform destroy
```

## Key Differences from Other Examples

- **Private subnet** - Instance has no direct inbound internet access
- **SSM Session Manager** - No SSH keys or inbound ports required
- **SSM Agent** - Automatically installed and configured
- **IAM Role** - Required for SSM permissions
- **Most secure** - No inbound SSH access by default

## OS-Specific Considerations

### Amazon Linux 2 Considerations

- **Full functionality** - All features work as expected
- **Package management** - Standard `yum` package installation
- **System updates** - Available and handled automatically

### RHEL 8 & 9 Considerations

- **Limited functionality** - Due to Red Hat subscription requirements
- **Manual package installation** - SSM Agent downloaded from S3
- **No system updates** - `dnf update` not available without subscription
- **Additional packages** - May need manual download from S3 or alternative sources
