# Scripts Directory

This directory contains various scripts used by the EKS Terraform infrastructure.

## Directory Structure

```
scripts/
├── user-data/          # Bootstrap scripts for EKS nodes
├── utils/              # Utility scripts for deployment and management
└── README.md           # This file
```

## User Data Scripts (`user-data/`)

Bootstrap scripts for EKS worker nodes:

- **`user_data_universal.sh`** - *(Recommended)* Universal bootstrap script that works with both AL2 and AL2023 AMIs
- **`user_data_simple.sh`** - Simple bootstrap using legacy EKS bootstrap script
- **`user_data_fixed.sh`** - Enhanced bootstrap with multiple fallback methods
- **`user_data.sh`** - Original bootstrap script (legacy)

### Usage

The bootstrap scripts are automatically used by Terraform when creating self-managed node groups. The default script is `user_data_universal.sh`.

To use a different script, modify the `templatefile` reference in `self-managed-nodes.tf`:

```hcl
templatefile("${path.module}/scripts/user-data/user_data_simple.sh", {
  cluster_name        = local.cluster_name
  cluster_endpoint    = module.eks.cluster_endpoint
  cluster_ca_data     = module.eks.cluster_certificate_authority_data
  bootstrap_arguments = v.bootstrap_arguments
})
```

### Features

All scripts support:
- **IMDSv2** - Secure instance metadata access
- **AL2 and AL2023** - Compatible with both Amazon Linux versions
- **ARM64 and x86_64** - Multi-architecture support
- **Error handling** - Comprehensive logging and fallback mechanisms

## Utility Scripts (`utils/`)

Management and deployment utilities:

- **`monitor_and_destroy.sh`** - Monitors Terraform apply and auto-destroys on failure
- **`force-cleanup.sh`** - Force cleanup of stuck EKS resources
- **`test-imdsv2.sh`** - Test script to verify IMDSv2 functionality

### Usage Examples

```bash
# Monitor deployment with auto-cleanup on failure
./scripts/utils/monitor_and_destroy.sh

# Force cleanup stuck resources
./scripts/utils/force-cleanup.sh

# Test IMDSv2 (run on EC2 instance)
./scripts/utils/test-imdsv2.sh
```

## Best Practices

1. **Always test scripts** in a development environment first
2. **Review logs** in `/var/log/eks-bootstrap.log` on instances
3. **Use IMDSv2** for security compliance
4. **Keep scripts updated** with latest EKS best practices